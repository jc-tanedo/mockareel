import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data' show BytesBuilder;
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

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
      final terrain = _terrain(client, lat, lon)
          .timeout(const Duration(seconds: 30))
          .then<List<double>?>((v) => v, onError: (_) => null);
      final shapes = <List<dynamic>>[];
      final lonScale = 111320 * cos(lat * pi / 180);
      try {
        final query =
            '[out:json][timeout:20];(way(around:550,$lat,$lon)["building"];way(around:550,$lat,$lon)["leisure"="park"];way(around:550,$lat,$lon)["natural"="water"];);out geom 1000;';
        final bytes = await _get(
          client,
          Uri.https('overpass-api.de', '/api/interpreter', {'data': query}),
        );
        for (final way in jsonDecode(utf8.decode(bytes))['elements']) {
          final coords = <int>[];
          for (final p in way['geometry'] ?? []) {
            coords.add(((p['lon'] - lon) * lonScale).round());
            coords.add(((lat - p['lat']) * 111132).round());
          }
          if (coords.length < 6 || coords.length > 16000) continue;
          final tags = way['tags'];
          final height = tags['building'] != null
              ? (double.tryParse(
                          '${tags['height']}'.replaceAll(RegExp(r'\s*m$'), ''),
                        ) ??
                        (double.tryParse('${tags['building:levels']}') ?? 3) *
                            3)
                    .clamp(2, 900)
              : tags['natural'] == 'water'
              ? -3
              : -2;
          shapes.add([height, coords]);
        }
      } on Exception {
        /* Terrain alone can still represent the selected place. */
      }
      final grid = await terrain;
      if (grid == null && shapes.isEmpty) {
        throw const FormatException(
          'No map data loaded for this pin. Retry or choose another location.',
        );
      }
      return jsonEncode({
        'grid': grid ?? List.filled(625, 0),
        'shapes': shapes,
        'credit': [
          if (shapes.isNotEmpty) '© OpenStreetMap contributors',
          if (grid != null) 'Terrain: Mapzen / source agencies',
        ].join(' · '),
      });
    } finally {
      client.close();
    }
  }

  static Future<Uint8List> _get(http.Client client, Uri uri) async {
    final response = await client
        .send(http.Request('GET', uri))
        .timeout(const Duration(seconds: 25));
    const limit = 8000000;
    if (response.statusCode != 200 || (response.contentLength ?? 0) > limit) {
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

  static Future<List<double>> _terrain(
    http.Client client,
    double lat,
    double lon,
  ) async {
    const n = 4096;
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
              'https://s3.amazonaws.com/elevation-tiles-prod/terrarium/12/$key.png',
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
