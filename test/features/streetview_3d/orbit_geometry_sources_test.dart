import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mockareel/features/streetview_3d/data/open_orbit_map.dart';
import 'package:mockareel/features/streetview_3d/model/orbit_scene.dart';
import 'package:pmtiles/pmtiles.dart';
import 'package:vector_tile/raw/raw_vector_tile.dart' as mvt;

Future<OrbitScene> capture(
  double lat,
  double lon,
  Future<http.Response> Function(http.Request) handler,
) async => OrbitScene.decode(
  await http.runWithClient(
    () => OpenOrbitMap.fetch(lat, lon),
    () => MockClient(handler),
  ),
);

List<int> varint(int n) {
  final bytes = <int>[];
  while (n >= 128) {
    bytes.add((n & 127) | 128);
    n >>= 7;
  }
  return [...bytes, n];
}

// A v3 archive with one actual protobuf building tile at the selected pin.
Uint8List archiveFor(
  double lat,
  double lon,
  int zoom,
  String layer,
  String heightKey,
) {
  final n = 1 << zoom, phi = lat * pi / 180;
  final x = (lon + 180) / 360 * n,
      y = (1 - log(tan(phi) + 1 / cos(phi)) / pi) * .5 * n;
  final feature = mvt.createVectorTileFeature(
    type: mvt.VectorTile_GeomType.POLYGON,
    tags: [0, 0, 1, 1],
    geometry: [
      9,
      ((x % 1) * 4096).round() * 2,
      ((y % 1) * 4096).round() * 2,
      26,
      120,
      0,
      0,
      120,
      119,
      0,
      15,
    ],
  );
  final tile = mvt
      .createVectorTile(
        layers: [
          mvt.createVectorTileLayer(
            name: layer,
            extent: 4096,
            version: 2,
            keys: [heightKey, 'facade_color'],
            values: [
              mvt.createVectorTileValue(doubleValue: 32),
              mvt.createVectorTileValue(stringValue: "#a53"),
            ],
            features: [feature],
          ),
        ],
      )
      .writeToBuffer();
  final id = ZXY(zoom, x.floor(), y.floor()).toTileId();
  final directory = [1, ...varint(id), 1, ...varint(tile.length), 1];
  final bytes = Uint8List(16384 + tile.length);
  bytes.setAll(0, [...ascii.encode('PMTiles'), 3]);
  final header = ByteData.sublistView(bytes);
  for (final (offset, value) in [
    (8, 127),
    (16, directory.length),
    (56, 16384),
    (64, tile.length),
  ]) {
    header.setUint64(offset, value, Endian.little);
  }
  bytes.setAll(96, [1, 1, 1, 1, zoom, zoom]);
  bytes.setAll(127, directory);
  bytes.setAll(16384, tile);
  return bytes;
}

void main() {
  for (final (city, lat, lon, japan) in [
    ('Kyoto', 34.9858, 135.7588, true),
    ('Manila', 14.5995, 120.9842, false),
  ]) {
    test('$city reads local PMTiles ranges when Overpass is offline', () async {
      final host = japan
          ? 'shi-works.com'
          : 'overturemaps-extras-us-west-2.s3.us-west-2.amazonaws.com';
      final bytes = archiveFor(
        lat,
        lon,
        japan ? 16 : 14,
        japan ? 'PLATEAU_2023_LOD0' : 'building',
        japan ? 'measuredHeight' : 'height',
      );
      var ranges = 0;
      final scene = await capture(lat, lon, (req) async {
        if (req.url.host == 'stac.overturemaps.org') {
          return http.Response('{"latest":"2026-11-18.0"}', 200);
        }
        if (req.url.host != host) return http.Response('', 503);
        if (!japan) {
          expect(req.url.path, '/tiles/2026-11-18.0/buildings.pmtiles');
        }
        final match = RegExp(
          r'^bytes=(\d+)-(\d+)$',
        ).firstMatch(req.headers['range']!)!;
        final start = int.parse(match[1]!), end = int.parse(match[2]!);
        ranges++;
        return http.Response.bytes(
          bytes.sublist(start, end + 1),
          206,
          headers: {'content-length': '${end - start + 1}'},
        );
      });
      expect(ranges, 2);
      expect(scene.shapes.single.height, 32);
      expect(scene.shapes.single.appearance.wall, 0xaa5533);
      expect(scene.shapes.single.points.any((p) => p.distance < 2), true);
      expect(scene.credit, contains(japan ? 'PLATEAU' : 'Overture'));
    });
  }

  test(
    'OpenFreeMap fills a missing global archive using the tile at the pin',
    () async {
      const lat = 15.02, lon = 120.68;
      final tile = archiveFor(
        lat,
        lon,
        14,
        'building',
        'render_height',
      ).sublist(16384);
      final scene = await capture(lat, lon, (req) async {
        if (req.url.host != 'tiles.openfreemap.org') {
          return http.Response('', 404);
        }
        if (req.url.path == '/planet') {
          return http.Response(
            jsonEncode({
              'tiles': ['https://tiles.openfreemap.org/xyz/{z}/{x}/{y}.pbf'],
            }),
            200,
          );
        }
        return http.Response.bytes(tile, 200);
      });
      expect(
        scene.shapes.any((s) => s.height == 32 && s.center.distance < 50),
        true,
      );
      expect(scene.credit, contains('OpenFreeMap'));
    },
  );

  test('IGN wins overlapping roofs and OSM fills remaining gaps', () async {
    const lat = 48.84, lon = 2.37;
    List<List<double>> square(double x) => [
      [x, lat],
      [x + .0001, lat],
      [x + .0001, lat + .0001],
      [x, lat + .0001],
      [x, lat],
    ];
    final scene = await capture(lat, lon, (req) async {
      if (req.url.host == 'data.geopf.fr') {
        expect(req.url.queryParameters['BBOX'], endsWith('CRS84'));
        return http.Response(
          jsonEncode({
            'features': [
              {
                'geometry': {
                  'type': 'MultiPolygon',
                  'coordinates': [
                    [square(lon)],
                  ],
                },
                'properties': {'hauteur': 24},
              },
            ],
          }),
          200,
        );
      }
      if (req.url.host == 'overpass-api.de') {
        return http.Response(
          jsonEncode({
            'elements': [
              for (final x in [lon, lon + .001])
                {
                  'tags': {
                    'building': 'yes',
                    'building:levels': 2,
                    'roof:colour': '#283951',
                  },
                  'geometry': [
                    for (final p in square(x)) {'lon': p[0], 'lat': p[1]},
                  ],
                },
            ],
          }),
          200,
        );
      }
      return http.Response('', 404);
    });
    expect(scene.shapes.map((f) => f.height), [24, 6]);
    expect(scene.shapes.map((f) => f.appearance.roof), [0x283951, 0x283951]);
    expect(scene.credit, contains('IGN'));
    expect(scene.credit, contains('OpenStreetMap'));
    expect(scene.credit, isNot(contains('Overture')));
  });
}
