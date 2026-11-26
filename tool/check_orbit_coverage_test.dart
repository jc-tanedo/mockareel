// Live, opt-in probe. Run with flutter test tool/check_orbit_coverage_test.dart.
import 'package:flutter_test/flutter_test.dart';
import 'package:mockareel/model/place_details.dart';
import 'package:mockareel/services/landmark_coordinates.dart';
import 'package:mockareel/features/streetview_3d/data/open_orbit_map.dart';
import 'package:mockareel/features/streetview_3d/model/orbit_scene.dart';

void main() {
  test('Yomiuri Land listing without a Maps pin or Android geocoder', () async {
    final pin = await LandmarkCoordinates.lookup(
      PlaceDetails(
        name: 'Yomiuri Land',
        address: '4015-1 Yanokuchi, Inagi, Tokyo 206-8725',
        website: 'https://www.yomiuriland.com/',
      ),
    );
    expect(pin, isNotNull);
    expect(pin!.$1, closeTo(35.62583, .003));
    expect(pin.$2, closeTo(139.51861, .003));
    // ignore: avoid_print
    print('Yomiuri Land | verified landmark pin ${pin.$1}, ${pin.$2}');
  });
  for (final (name, lat, lon) in [
    ('Kyoto Station', 34.9858, 135.7588),
    ('Gare de Lyon', 48.8443, 2.3730),
    ('San Fernando, Pampanga', 15.0286, 120.6898),
  ]) {
    test(name, () async {
      final scene = OrbitScene.decode(await OpenOrbitMap.fetch(lat, lon));
      final buildings = scene.shapes.where((f) => f.height > 0);
      final colors = buildings
          .where((f) => f.appearance.wall != null || f.appearance.roof != null)
          .length;
      final materials = buildings
          .where(
            (f) =>
                f.appearance.wallMaterial != null ||
                f.appearance.roofMaterial != null,
          )
          .length;
      // ignore: avoid_print
      print(
        '$name | ${scene.coverage} | ${scene.walls.length} suitable walls | $colors with color, $materials with material | ${scene.credit}',
      );
      expect(scene.shapes.any((s) => s.height > 0), isTrue);
    }, timeout: const Timeout(Duration(seconds: 60)));
  }
}
