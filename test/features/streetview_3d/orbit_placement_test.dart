import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockareel/features/streetview_3d/data/orbit_buildings.dart';
import 'package:mockareel/features/streetview_3d/data/orbit_scene_loader.dart';
import 'package:mockareel/features/streetview_3d/model/building_appearance.dart';
import 'package:mockareel/features/streetview_3d/model/orbit_dolly.dart';
import 'package:mockareel/features/streetview_3d/model/orbit_media_pose.dart';
import 'package:mockareel/features/streetview_3d/model/orbit_scene.dart';
import 'package:mockareel/features/streetview_3d/model/orbit_wall_placement.dart';
import 'package:mockareel/model/project.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final grid = List.filled(625, 0.0);
  const ring = [
    Offset(-10, -10),
    Offset(10, -10),
    Offset(10, 10),
    Offset(-10, 10),
  ];
  final city = OrbitScene([OrbitFootprint(18, ring)], grid, 'city');
  final pin = OrbitLocation(
    place: PlaceDetails(latitude: 35, longitude: 139),
    mapPath: 'shared',
  );
  ReelClip clip(String id) {
    final clip = ReelClip(id: id, path: '$id.jpg', name: id, isVideo: false);
    pin.assign(clip);
    return clip;
  }

  test(
    'old clips spread across distinct walls and restored cycles do not repeat',
    () {
      final select = OrbitWallPlacement(Random(7));
      final project = ReelProject(
        template: 'streetview-3d',
        clips: [for (int i = 0; i < 5; i++) clip('$i')],
      );
      expect(city.walls.length, 4);
      for (final c in project.clips) {
        expect(select.choose(c, project.clips, city), true);
      }
      expect(
        project.clips.take(4).map((c) => c.streetview.wallId).toSet().length,
        4,
      );
      final saved = ReelProject.fromJson(project.toJson());
      final c = saved.clips[1];
      expect(select.choose(c, saved.clips, city), false);
      final used = {c.streetview.wallId};
      final others = [
        for (final other in saved.clips)
          if (other != c) other.streetview.wallId,
      ];
      for (int i = 1; i < 4; i++) {
        expect(select.choose(c, saved.clips, city, shuffle: true), true);
        expect(used.add(c.streetview.wallId), true);
      }
      final last = c.streetview.wallId;
      select.choose(c, saved.clips, city, shuffle: true);
      expect(c.streetview.wallId, isNot(last));
      expect([
        for (final other in saved.clips)
          if (other != c) other.streetview.wallId,
      ], others);
      final recaptured = OrbitScene(
        [OrbitFootprint(18, ring.reversed.toList())],
        grid,
        'new',
      );
      expect(select.choose(c, saved.clips, recaptured), false);
      final surveyed = OrbitScene(
        [OrbitFootprint(18, ring.map((p) => p + const Offset(1, 0)).toList())],
        grid,
        'survey',
      );
      final beforeSurvey = c.streetview.wallId;
      expect(select.choose(c, saved.clips, surveyed), true);
      expect(c.streetview.wallId, surveyed.matchingWall(beforeSurvey));
      final other = OrbitScene(
        [OrbitFootprint(18, ring.map((p) => p + const Offset(30, 0)).toList())],
        grid,
        'changed',
      );
      select.choose(c, saved.clips, other);
      expect(other.walls.containsKey(c.streetview.wallId), true);
      expect(
        select.choose(c, saved.clips, OrbitScene([], grid, 'empty')),
        true,
      );
      expect(c.streetview.wallId, isNull);
      final only = OrbitScene(
        [
          OrbitFootprint(18, const [
            Offset(-200, 90),
            Offset(200, 90),
            Offset(200, 220),
            Offset(-200, 220),
          ]),
        ],
        grid,
        'one',
      );
      expect(only.walls, hasLength(1));
      select.choose(c, saved.clips, only);
      expect(select.choose(c, saved.clips, only, shuffle: true), false);
    },
  );
  test(
    'repairs duplicate/adjacent same-pin walls and curates nearby distinct walls',
    () async {
      final select = OrbitWallPlacement(Random(3));
      final sameWall = city.walls.keys.first;
      final a = clip('a')..streetview.wallId = sameWall;
      final b = clip('b')..streetview.wallId = sameWall;
      expect(select.choose(b, [a, b], city), true);
      expect(b.streetview.wallId, isNot(sameWall));

      final broken = ReelProject(
        template: 'streetview-3d',
        clips: [
          clip('x')..streetview.wallId = sameWall,
          clip('y')..streetview.wallId = sameWall,
        ],
      );
      expect(select.ensureDistinct(broken.clips, {'shared': city}), true);
      expect(
        broken.clips.first.streetview.wallId,
        isNot(broken.clips.last.streetview.wallId),
      );

      final five = [for (int i = 0; i < 5; i++) clip('c$i')];
      for (final item in five) {
        select.choose(item, five, city);
      }
      for (int i = 0; i + 1 < five.length; i++) {
        expect(five[i].streetview.wallId, isNot(five[i + 1].streetview.wallId));
      }

      // Shuffling one clip of a 2-clip pair on a 4-wall building avoids sibling.
      final pair = [
        clip('p0')..streetview.wallId = city.walls.keys.first,
        clip('p1')..streetview.wallId = city.walls.keys.last,
      ];
      for (int i = 0; i < 10; i++) {
        expect(select.choose(pair[1], pair, city, shuffle: true), true);
        expect(pair[1].streetview.wallId, isNot(pair[0].streetview.wallId));
      }

      // Partner-wall curation picks adjacent/corner wall on single building.
      final firstWall = city.walls[city.walls.keys.first]!;
      final two = [clip('t0')..streetview.wallId = firstWall.id, clip('t1')];
      expect(select.choose(two[1], two, city), true);
      final secondWall = city.walls[two[1].streetview.wallId]!;
      final dot =
          firstWall.normal.dx * secondWall.normal.dx +
          firstWall.normal.dy * secondWall.normal.dy;
      expect(dot, greaterThan(-0.85));

      // On real Tokyo Station geometry, two same-pin clips get nearby distinct walls.
      final station = await OrbitSceneLoader.load(
        'assets/streetview3d/tokyo.json',
      );
      final tokyo = [clip('tk0'), clip('tk1')];
      select.choose(tokyo[0], tokyo, station);
      select.choose(tokyo[1], tokyo, station);
      expect(tokyo[0].streetview.wallId, isNot(tokyo[1].streetview.wallId));
      final m0 = station.walls[tokyo[0].streetview.wallId]!;
      final m1 = station.walls[tokyo[1].streetview.wallId]!;
      expect((m0.center - m1.center).distance, lessThanOrEqualTo(65));
    },
  );
  test(
    'a dolly shares one world while keeping the distinct mounted panels',
    () {
      final a = clip('a').streetview..wallId = city.walls.keys.first;
      final b = clip('b').streetview..wallId = city.walls.keys.last;
      final startEnd = OrbitMediaPose.at(
        'media',
        1,
        scene: city,
        wallId: a.wallId,
      );
      final endStart = OrbitMediaPose.at(
        'media',
        0,
        scene: city,
        wallId: b.wallId,
        closeApproach: true,
      );
      expect(
        OrbitMediaPose.at(
          'media',
          1,
          scene: city,
          wallId: b.wallId,
          closeApproach: true,
        ).native,
        OrbitMediaPose.at('media', 1, scene: city, wallId: b.wallId).native,
      );
      expect(endStart.zoom, greaterThan(1.0));
      for (final t in [0.0, .25, .5, .75, 1.0]) {
        final trip = OrbitDolly.between(a, b, city, city, t);
        expect(trip.sharedWorld, true);
        expect(trip.distinctWalls, true);
        expect(trip.departure.mount!.id, a.wallId);
        expect(trip.arrival.mount!.id, b.wallId);
        expect(
          (trip.arrival.pin(const Size(360, 640), .8 * trip.arrival.zoom) -
                  trip.departure.pin(
                    const Size(360, 640),
                    .8 * trip.departure.zoom,
                  ))
              .distance,
          lessThan(1e-7),
        );
        expect(
          trip.arrival.heading - trip.departure.heading,
          closeTo(0, 1e-8),
          reason: 'camera heading at $t',
        );
        if (t == 0) {
          expect(trip.departure.native, startEnd.native);
        }
        if (t == .5) {
          final nominal = sqrt(startEnd.zoom * endStart.zoom);
          expect(trip.departure.zoom, greaterThan(1.0));
          expect(trip.departure.zoom, lessThan(nominal));
          final delta =
              city.walls[b.wallId]!.center - city.walls[a.wallId]!.center;
          final deviation = trip.departure.focus - delta * 0.5;
          expect(deviation.distance, greaterThan(5.0));
          final towardCamera = Offset(
            sin(trip.departure.heading),
            cos(trip.departure.heading),
          );
          expect(
            deviation.dx * towardCamera.dx + deviation.dy * towardCamera.dy,
            greaterThan(0),
          );
        }
        if (t == 1) {
          expect(trip.arrival.native, endStart.native);
        }
      }
    },
  );
  test(
    'matching providers fill independent wall/roof fields and receive credit',
    () {
      const pts = [0, 0, 20, 0, 20, 20, 0, 20];
      final merged = OrbitGeometrySet()
        ..add('outline', [
          OrbitGeometry.fromRing(
            25,
            pts,
            appearance: BuildingAppearance.read(
              wallMaterial: 'brick',
              roof: '#abc',
            ),
          )!,
        ])
        ..add('colour survey', [
          OrbitGeometry.fromRing(
            8,
            pts,
            appearance: BuildingAppearance.read(wall: 'blue', roof: 'red'),
          )!,
        ])
        ..add('unrelated triangle', [
          OrbitGeometry.fromRing(8, [
            0,
            0,
            20,
            0,
            0,
            20,
          ], appearance: BuildingAppearance.read(roofMaterial: 'slate'))!,
        ]);
      expect(merged.credits, {'outline', 'colour survey'});
      final data = jsonEncode({
        'credit': 'sample',
        'shapes': [
          merged.shapes.single.toJson(),
          [12, pts],
        ],
        'grid': grid,
      });
      final saved = OrbitScene.decode(data);
      final building = saved.shapes.first;
      expect(building.height, 25);
      expect(building.color(roof: false, dark: false).toARGB32(), 0xff0000ff);
      expect(building.color(roof: true, dark: false).toARGB32(), 0xffaabbcc);
      expect(
        building.color(roof: true, dark: true),
        isNot(building.color(roof: true, dark: false)),
      );
      final material = BuildingAppearance.read(
        wall: '#badhex',
        wallMaterial: 'BRICK',
      );
      expect(
        material.base(top: false, seed: 2, dark: false).toARGB32(),
        0xffae7764,
      );
      expect(
        saved.shapes.last.color(roof: true, dark: true),
        OrbitScene.decode(data).shapes.last.color(roof: true, dark: true),
      );
    },
  );
}
