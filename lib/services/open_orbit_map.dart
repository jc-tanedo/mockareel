import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data' show BytesBuilder;
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'orbit_buildings.dart';
import 'orbit_vector_tiles.dart';

class OpenOrbitMap {
  static const tokyoLat = 35.68124, tokyoLon = 139.76712;
  static Future<String> fetch(double lat, double lon) async {
    if (!lat.isFinite || !lon.isFinite || lat.abs() > 85 || lon.abs() > 180) {
      throw const FormatException(
        'Select a pin between 85° south and 85° north.',
      );
    }
    if ((lat - tokyoLat).abs() < .0003 && (lon - tokyoLon).abs() < .0003) {
      return rootBundle.loadString('assets/streetview3d/tokyo.json');
    }
    final client = http.Client();
    try {
      final vectors = OrbitVectorTiles(client, _get, lat, lon);
      final japan = lat >= 24 && lat <= 46 && lon >= 122 && lon <= 154;
      final france = lat >= 41 && lat <= 51.2 && lon >= -5.3 && lon <= 9.7;
      final terrain = _loadTerrain(client, lat, lon, japan);
      final layers = await Future.wait([
        if (japan)
          _layer('PLATEAU (MLIT) / FLatEAU / shiwaku', vectors.plateau),
        if (france) _layer('IGN BD TOPO', () => _ign(client, lat, lon)),
        _layer('© OpenStreetMap contributors', () => _osm(client, lat, lon)),
        _layer('Overture Maps Foundation and contributors', vectors.overture),
      ]);
      final merged = OrbitGeometrySet();
      for (final (credit, features) in layers) {
        merged.add(credit, features);
      }
      if (merged.shapes.where((f) => f.height > 0).length < 8) {
        final (credit, features) = await _layer(
          'OpenFreeMap / OpenMapTiles / © OpenStreetMap contributors',
          vectors.openFreeMap,
          seconds: 10,
        );
        merged.add(credit, features);
      }
      final (grid, terrainCredit) = await terrain;
      if (grid == null && merged.shapes.isEmpty) {
        throw const FormatException(
          'No map data loaded for this pin. Retry or choose another location.',
        );
      }
      return jsonEncode({
        'grid': grid ?? List.filled(625, 0),
        'shapes': merged.shapes.map((f) => f.toJson()).toList(),
        'credit': [
          ...merged.credits,
          ...merged.contributors,
          ?terrainCredit,
        ].join(' · '),
      });
    } finally {
      client.close();
    }
  }

  static Future<T?> _available<T>(
    Future<T> Function() load,
    int seconds,
  ) async {
    try {
      return await load().timeout(Duration(seconds: seconds));
    } catch (_) {
      // Independent public feeds can time out or return malformed tiles.
      return null;
    }
  }

  static Future<(String, List<OrbitGeometry>)> _layer(
    String credit,
    Future<List<OrbitGeometry>> Function() load, {
    int seconds = 25,
  }) async => (credit, await _available(load, seconds) ?? <OrbitGeometry>[]);

  static Future<List<OrbitGeometry>> _ign(
    http.Client client,
    double lat,
    double lon,
  ) async {
    final dx = 600 / (111320 * cos(lat * pi / 180)), dy = 600 / 111132;
    const crs = 'urn:ogc:def:crs:OGC::CRS84';
    final uri = Uri.https('data.geopf.fr', '/wfs', {
      'SERVICE': 'WFS',
      'VERSION': '2.0.0',
      'REQUEST': 'GetFeature',
      'TYPENAMES': 'BDTOPO_V3:batiment',
      'OUTPUTFORMAT': 'application/json',
      'SRSNAME': crs,
      'BBOX': '${lon - dx},${lat - dy},${lon + dx},${lat + dy},$crs',
      'COUNT': '1500',
    });
    final data = jsonDecode(utf8.decode(await _get(client, uri)));
    final shapes = <OrbitGeometry>[];
    for (final f in data['features']) {
      final geom = f['geometry'], props = f['properties'];
      if (geom == null) continue;
      final polygons = switch (geom['type']) {
        'Polygon' => [geom['coordinates']],
        'MultiPolygon' => geom['coordinates'] as List,
        _ => [],
      };
      for (final polygon in polygons) {
        if ((polygon as List).isEmpty) continue;
        final ring = polygon.first as List;
        if (ring.length > 8000) continue;
        final points = <int>[
          for (final p in ring) ...[
            ((p[0] - lon) * 111320 * cos(lat * pi / 180)).round(),
            ((lat - p[1]) * 111132).round(),
          ],
        ];
        final shape = OrbitGeometry.fromRing(
          orbitBuildingHeight(props?['hauteur'], props?['nombre_d_etages']),
          points,
        );
        if (shape != null) shapes.add(shape);
      }
    }
    return shapes;
  }

  static Future<List<OrbitGeometry>> _osm(
    http.Client client,
    double lat,
    double lon,
  ) async {
    final shapes = <OrbitGeometry>[];
    final lonScale = 111320 * cos(lat * pi / 180);
    final query =
        '[out:json][timeout:20];(nwr(around:550,$lat,$lon)["building"];way(around:550,$lat,$lon)["building:part"];way(around:550,$lat,$lon)["leisure"="park"];way(around:550,$lat,$lon)["natural"="water"];);out geom 1000;';
    final bytes = await _get(
      client,
      Uri.https('overpass-api.de', '/api/interpreter', {'data': query}),
    );
    for (final way in jsonDecode(utf8.decode(bytes))['elements']) {
      for (final ring in _rings(way)) {
        final coords = <int>[];
        for (final p in ring) {
          coords.add(((p['lon'] - lon) * lonScale).round());
          coords.add(((lat - p['lat']) * 111132).round());
        }
        if (coords.length < 6 || coords.length > 16000) continue;
        final tags = way['tags'];
        final height = tags['building'] != null || tags['building:part'] != null
            ? orbitBuildingHeight(tags['height'], tags['building:levels'])
            : tags['natural'] == 'water'
            ? -3
            : -2;
        final feature = OrbitGeometry.fromRing(height.toDouble(), coords);
        if (feature != null) shapes.add(feature);
      }
    }
    return shapes;
  }

  // Multipolygon stations often keep building tags on the relation, with
  // their footprint split across several otherwise untagged outer ways.
  static Iterable<List> _rings(Map way) sync* {
    if (way['geometry'] case final List points) {
      yield points;
      return;
    }
    final parts = <List>[
      for (final m in way['members'] ?? [])
        if (m['role'] == 'outer' &&
            m['geometry'] is List &&
            m['geometry'].length >= 2)
          List.of(m['geometry']),
    ];
    bool same(Map a, Map b) => a['lat'] == b['lat'] && a['lon'] == b['lon'];
    while (parts.isNotEmpty) {
      final ring = parts.removeLast();
      while (!same(ring.first, ring.last)) {
        final next = parts.indexWhere(
          (p) => same(p.first, ring.last) || same(p.last, ring.last),
        );
        if (next < 0) break;
        final p = parts.removeAt(next);
        ring.addAll((same(p.first, ring.last) ? p : p.reversed).skip(1));
      }
      if (same(ring.first, ring.last)) yield ring;
    }
  }

  static Future<Uint8List> _get(http.Client client, Uri uri) async {
    final response = await client
        .send(http.Request('GET', uri))
        .timeout(const Duration(seconds: 25));
    const limit = 8000000;
    if (response.statusCode != 200 || (response.contentLength ?? 0) > limit) {
      await response.stream.listen((_) {}).cancel();
      throw const FormatException('Map server unavailable.');
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in response.stream.timeout(
      const Duration(seconds: 25),
    )) {
      if (bytes.length + chunk.length > limit) {
        throw const FormatException('Map data exceeds the download limit.');
      }
      bytes.add(chunk);
    }
    return bytes.takeBytes();
  }

  static Future<(List<double>?, String?)> _loadTerrain(
    http.Client client,
    double lat,
    double lon,
    bool japan,
  ) async {
    if (japan) {
      for (final layer in ['dem5a_png', 'dem_png']) {
        final grid = await _available(
          () => _terrain(client, lat, lon, layer),
          6,
        );
        if (grid != null) return (grid, 'Terrain: GSI Japan');
      }
    }
    final grid = await _available(() => _terrain(client, lat, lon, null), 18);
    return (grid, grid == null ? null : 'Terrain: Mapzen / source agencies');
  }

  static Future<List<double>> _terrain(
    http.Client client,
    double lat,
    double lon,
    String? gsi,
  ) async {
    final zoom = gsi == null ? 12 : 14;
    final n = 1 << zoom;
    final tiles = <String, ByteData>{};
    final grid = <double>[];
    for (int z = -600; z <= 600; z += 50) {
      for (int x = -600; x <= 600; x += 50) {
        final phi = (lat - z / 111132) * pi / 180;
        final px =
            (lon + x / (111320 * cos(lat * pi / 180)) + 180) / 360 * n * 256;
        final py = (1 - log(tan(phi) + 1 / cos(phi)) / pi) * .5 * n * 256;
        final key = '${(px.floor() ~/ 256) % n}/${py.floor() ~/ 256}';
        if (!tiles.containsKey(key)) {
          final bytes = await _get(
            client,
            Uri.parse(
              gsi == null
                  ? 'https://s3.amazonaws.com/elevation-tiles-prod/terrarium/$zoom/$key.png'
                  : 'https://cyberjapandata.gsi.go.jp/xyz/$gsi/$zoom/$key.png',
            ),
          );
          final codec = await ui.instantiateImageCodec(bytes);
          try {
            final image = (await codec.getNextFrame()).image;
            try {
              if (image.width != 256 || image.height != 256) {
                throw const FormatException('Invalid terrain tile.');
              }
              tiles[key] = (await image.toByteData(
                format: ui.ImageByteFormat.rawRgba,
              ))!;
            } finally {
              image.dispose();
            }
          } finally {
            codec.dispose();
          }
        }
        final tile = tiles[key]!,
            offset = ((py.floor() % 256) * 256 + px.floor() % 256) * 4;
        if (gsi != null) {
          final rgb = tile.getUint32(offset) >>> 8;
          if (rgb == 0x800000 || tile.getUint8(offset + 3) == 0) {
            throw const FormatException('No GSI elevation sample.');
          }
          grid.add((rgb >= 0x800000 ? rgb - 0x1000000 : rgb) * .01);
          continue;
        }
        grid.add(
          tile.getUint8(offset) * 256 +
              tile.getUint8(offset + 1) +
              tile.getUint8(offset + 2) / 256 -
              32768,
        );
      }
    }
    return grid;
  }
}
