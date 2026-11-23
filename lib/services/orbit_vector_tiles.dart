import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pmtiles/pmtiles.dart';
import 'package:vector_tile/vector_tile.dart';
import 'orbit_buildings.dart';

typedef MapDownload = Future<Uint8List> Function(http.Client, Uri);

class OrbitVectorTiles {
  final http.Client client;
  final MapDownload get;
  final double lat, lon;
  OrbitVectorTiles(this.client, this.get, this.lat, this.lon);

  Future<List<OrbitGeometry>> plateau() => _archive(
    Uri.https('shi-works.com', '/pmtiles/plateau/PLATEAU_2023_LOD0.pmtiles'),
    plateauLayer: true,
  );

  Future<List<OrbitGeometry>> overture() async {
    const custom = String.fromEnvironment('OVERTURE_BUILDINGS_PMTILES');
    if (custom.isNotEmpty) return _archive(Uri.parse(custom));
    final catalog = jsonDecode(
      utf8.decode(
        await get(client, Uri.https('stac.overturemaps.org', '/catalog.json')),
      ),
    );
    final release = catalog['latest'];
    if (release is! String ||
        !RegExp(r'^\d{4}-\d\d-\d\d\.\d+$').hasMatch(release)) {
      throw const FormatException('Unknown Overture release.');
    }
    return _archive(
      Uri.https(
        'overturemaps-extras-us-west-2.s3.us-west-2.amazonaws.com',
        '/tiles/$release/buildings.pmtiles',
      ),
    );
  }

  Future<List<OrbitGeometry>> _archive(
    Uri uri, {
    bool plateauLayer = false,
  }) async {
    final archive = await PmTilesArchive.fromUri(
      uri,
      client: _RangeClient(client),
    );
    try {
      if (archive.minZoom > 18 || archive.maxZoom < archive.minZoom) {
        throw const FormatException('Unsupported building archive zoom.');
      }
      final zoom = (plateauLayer ? 16 : 14).clamp(
        archive.minZoom,
        archive.maxZoom,
      );
      return await _tiles(zoom, plateauLayer, (x, y) async {
        final id = ZXY(zoom, x, y).toTileId();
        final entry = await archive.lookup(id);
        if (entry == null || entry.length > 2000000) return null;
        final tile = await archive.tile(id);
        final bytes = tile.bytes();
        return bytes.length <= 8000000 ? Uint8List.fromList(bytes) : null;
      });
    } finally {
      await archive.close();
    }
  }

  Future<List<OrbitGeometry>> openFreeMap() async {
    final metadata = jsonDecode(
      utf8.decode(
        await get(client, Uri.https('tiles.openfreemap.org', '/planet')),
      ),
    );
    final template = (metadata['tiles'] as List).first as String;
    final zoom = min(14, (metadata['maxzoom'] as int?) ?? 14);
    return _tiles(zoom, false, (x, y) {
      final uri = Uri.parse(
        template
            .replaceAll('{z}', '$zoom')
            .replaceAll('{x}', '$x')
            .replaceAll('{y}', '$y'),
      );
      if (uri.scheme != 'https') {
        throw const FormatException('Invalid tile URL');
      }
      return get(client, uri);
    });
  }

  Future<List<OrbitGeometry>> _tiles(
    int zoom,
    bool plateauLayer,
    Future<Uint8List?> Function(int, int) read,
  ) async {
    final n = 1 << zoom;
    final phi = lat * pi / 180;
    final cx = (lon + 180) / 360 * n;
    final cy = (1 - log(tan(phi) + 1 / cos(phi)) / pi) * .5 * n;
    final metresPerTile = 40075016.686 * cos(phi) / n;
    final radius = 600 / metresPerTile;
    final tiles =
        [
          for (int x = (cx - radius).floor(); x <= (cx + radius).floor(); x++)
            for (
              int y = max(0, (cy - radius).floor());
              y <= min(n - 1, (cy + radius).floor());
              y++
            )
              (x, y),
        ]..sort(
          (a, b) => (pow(a.$1 + .5 - cx, 2) + pow(a.$2 + .5 - cy, 2)).compareTo(
            pow(b.$1 + .5 - cx, 2) + pow(b.$2 + .5 - cy, 2),
          ),
        );
    final result = <OrbitGeometry>[];
    // Keep neighbouring tile requests bounded on mobile networks.
    final count = min(25, tiles.length);
    for (int start = 0; start < count; start += 4) {
      final batch = await Future.wait(
        tiles.sublist(start, min(start + 4, count)).map((tile) async {
          try {
            final bytes = await read(tile.$1 % n, tile.$2);
            if (bytes == null) return <OrbitGeometry>[];
            final input = (
              bytes,
              tile.$1 - cx,
              tile.$2 - cy,
              metresPerTile,
              plateauLayer,
            );
            return await compute(_decode, input);
          } on Exception {
            return <OrbitGeometry>[];
          }
        }),
      );
      for (final features in batch) {
        result.addAll(features);
      }
      if (result.length >= 3000) break;
    }
    return result;
  }

  static List<OrbitGeometry> _decode(
    (Uint8List, double, double, double, bool) input,
  ) {
    final (bytes, dx, dy, metres, plateauLayer) = input;
    final features = <OrbitGeometry>[];
    for (final layer in VectorTile.fromBytes(bytes: bytes).layers) {
      if (!plateauLayer && layer.name != 'building') continue;
      final scale = metres / layer.extent;
      for (final f in layer.features) {
        if (f.type != VectorTileGeomType.POLYGON) continue;
        final props = f.decodeProperties();
        final height = orbitBuildingHeight(
          props['measuredHeight']?.value ??
              props['measured_height']?.value ??
              props['bldg:measuredHeight']?.value ??
              props['height']?.value ??
              props['render_height']?.value,
          props['num_floors']?.value ?? props['storeysAboveGround']?.value,
        );
        for (final polygon in f.decodePolygon()) {
          if (polygon.isEmpty || polygon.first.length > 8000) continue;
          final points = <int>[
            for (final p in polygon.first) ...[
              (dx * metres + p[0] * scale).round(),
              (dy * metres + p[1] * scale).round(),
            ],
          ];
          final feature = OrbitGeometry.fromRing(
            height,
            points,
            contributors: {
              for (final k in ['@geometry_source', '@height_source'])
                if (props[k]?.value case final String name
                    when name.isNotEmpty && name.length <= 160)
                  name,
            },
          );
          if (feature != null) features.add(feature);
        }
      }
    }
    return features;
  }
}

/// PMTiles readers use byte ranges even for their index. Reject a server
/// streaming the whole archive and release its connection immediately.
class _RangeClient extends http.BaseClient {
  final http.Client inner;
  _RangeClient(this.inner);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final range = RegExp(
      r'^bytes=(\d+)-(\d+)$',
    ).firstMatch(request.headers['range'] ?? '');
    if (range == null) throw const FormatException('Missing archive range.');
    final length = int.parse(range[2]!) - int.parse(range[1]!) + 1;
    if (length <= 0 || length > 2000000) {
      throw const FormatException('Archive range exceeds the download limit.');
    }
    final response = await inner
        .send(request)
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 206 ||
        (response.contentLength ?? length) != length) {
      await response.stream.listen((_) {}).cancel();
      throw const FormatException('Map archive does not support this range.');
    }
    Stream<List<int>> checked() async* {
      var received = 0;
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 10),
      )) {
        received += chunk.length;
        if (received > length) {
          throw const FormatException('Oversized map archive range.');
        }
        yield chunk;
      }
      if (received != length) {
        throw const FormatException('Incomplete map archive range.');
      }
    }

    return http.StreamedResponse(
      checked(),
      206,
      contentLength: length,
      headers: response.headers,
    );
  }
}
