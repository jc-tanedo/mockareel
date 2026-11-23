import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockareel/model/orbit_media_pose.dart';
import 'package:mockareel/model/orbit_scene.dart';
import 'package:mockareel/model/project.dart';
import 'package:mockareel/model/streetview_timeline.dart';
import 'package:mockareel/widgets/orbit_journey_canvas.dart';
import 'package:mockareel/widgets/orbit_map.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final flat = OrbitScene([], List.filled(625, 0), 'Flat');
  final roof = OrbitFootprint(100, const [
    Offset(-22, 0),
    Offset(-2, 0),
    Offset(-2, 20),
    Offset(-22, 20),
  ]);
  final city = OrbitScene([roof], List.filled(625, 0), 'City');

  test(
    'mounted panel corners project onto the same exterior wall throughout the shot',
    () {
      final terrain = List.generate(625, (i) => (i % 25) * .5);
      for (final edge in [roof.points, roof.points.reversed.toList()]) {
        final scene = OrbitScene(
          [
            OrbitFootprint(100, [...edge, edge.first]),
          ],
          terrain,
          'Station',
        );
        final mount = scene.wallMount!;
        expect(mount.center.dx, closeTo(-22.05, .00001));
        expect(mount.normal, const Offset(-1, 0));
        expect(mount.sizeFactor, lessThan(1));
        final halfWidth = OrbitWallMount.defaultWidth * mount.sizeFactor / 2;
        expect(mount.center.dy - halfWidth, greaterThan(0));
        expect(mount.center.dy + halfWidth, lessThan(20));
        for (final pose in [
          OrbitMediaPose.at('map', .4, scene: scene),
          OrbitMediaPose.at('media', .5, scene: scene),
          OrbitMediaPose.travel(scene, .6, -1),
          OrbitMediaPose.travel(scene, .6, 1),
          OrbitMediaPose.at('back', .8, scene: scene),
        ]) {
          final c = cos(pose.heading),
              s = sin(pose.heading),
              scale = .8 * pose.zoom;
          for (final x in [0.0, 360.0]) {
            final point =
                mount.center + mount.tangent * ((x / 180 - 1) * halfWidth);
            for (final y in [0.0, 640.0]) {
              final height =
                  mount.baseAbovePin +
                  (1 - y / 640) *
                      OrbitWallMount.defaultHeight *
                      mount.sizeFactor;
              final screen =
                  pose.pin(const Size(360, 640), scale) +
                  Offset(
                        point.dx * c - point.dy * s,
                        (point.dx * s + point.dy * c) * pose.depthScale -
                            height * pose.heightScale,
                      ) *
                      scale;
              final panel = MatrixUtils.transformPoint(
                pose.matrix,
                Offset(x, y),
              );
              expect((panel - screen).distance, lessThan(1e-8));
              final gl = pose.native, nx = x / 180 - 1, ny = 1 - y / 320;
              expect((gl[0] * nx + gl[2] + 1) * 180, closeTo(screen.dx, 1e-8));
              expect(
                (1 - gl[3] * nx - gl[4] * ny - gl[5]) * 320,
                closeTo(screen.dy, 1e-8),
              );
            }
          }
        }
      }
    },
  );

  test(
    'unsuitable or obstructed walls retain the original free-standing pose',
    () {
      final occluder = OrbitFootprint(150, const [
        Offset(-90, -90),
        Offset(90, -90),
        Offset(90, 90),
        Offset(-90, 90),
      ]);
      for (final scene in [
        flat,
        OrbitScene([OrbitFootprint(4, roof.points)], flat.grid, 'Low'),
        OrbitScene(
          [
            OrbitFootprint(
              100,
              roof.points.map((p) => p + const Offset(200, 0)).toList(),
            ),
          ],
          flat.grid,
          'Distant',
        ),
        OrbitScene([roof, occluder], flat.grid, 'Enclosed'),
      ]) {
        expect(scene.wallMount, isNull);
        expect(
          OrbitMediaPose.at('media', .5, scene: scene).native,
          OrbitMediaPose.at('media', .5).native,
        );
      }
    },
  );
  test(
    'flight matches both media poses and responds to direction, roofs and terrain',
    () {
      final hills = OrbitScene(
        [],
        List.generate(625, (i) => (i % 25) * 5.0),
        'Hills',
      );
      for (final scene in [flat, hills, city]) {
        for (final direction in [-1, 1]) {
          for (final t in [0.0, 1.0]) {
            final expected = OrbitMediaPose.at('media', 1 - t, scene: scene);
            final pose = OrbitMediaPose.travel(scene, t, direction);
            expect(pose.matrix.storage, expected.matrix.storage);
            expect(pose.heading, expected.heading);
          }
        }
      }
      final left = OrbitMediaPose.travel(city, .5, -1);
      final right = OrbitMediaPose.travel(city, .5, 1);
      expect(left.anchor.dx, greaterThan(180));
      expect(right.anchor.dx, lessThan(180));
      expect(left.turn, -right.turn);
      final overFlat = OrbitMediaPose.travel(flat, .5, 1);
      final overHills = OrbitMediaPose.travel(hills, .5, 1);
      expect(right.distanceScale, lessThan(overFlat.distanceScale));
      expect(right.lift, greaterThan(overFlat.lift));
      expect(overHills.lift, isNot(overFlat.lift));
    },
  );

  test(
    'buildings on the camera side can cover pixels inside the media plane',
    () async {
      final pose = OrbitMediaPose.travel(flat, .5, 1);
      Future<int> painted(OrbitScene map) async {
        final recorder = ui.PictureRecorder();
        OrbitPainter(
          map,
          pose.progress,
          false,
          zoom: pose.zoom,
          camera: pose,
          foregroundOnly: true,
        ).paint(Canvas(recorder), const Size(360, 640));
        final picture = recorder.endRecording();
        final image = await picture.toImage(360, 640);
        final data = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        final pixels = [
          for (int i = 3; i < data.lengthInBytes; i += 4)
            if (data.getUint8(i) > 0) i,
        ];
        image.dispose();
        picture.dispose();
        return pixels.length;
      }

      final behind = OrbitScene(
        [OrbitFootprint(100, roof.points.map((p) => -p).toList())],
        city.grid,
        'Behind',
      );
      expect(await painted(city), greaterThan(10));
      expect(await painted(behind), 0);
    },
  );

  testWidgets(
    'shared captures keep a single world and different captures approach the next pin',
    (tester) async {
      final dir = Directory.systemTemp.createTempSync('orbit-transition-');
      addTearDown(() => dir.deleteSync(recursive: true));
      const path = 'assets/streetview3d/tokyo.json';
      final other = File(path).copySync('${dir.path}/other.json').path;
      await tester.runAsync(() async {
        await OrbitScene.load(path);
        await OrbitScene.load(other);
      });
      final p = ReelProject(
        template: 'streetview-3d',
        clips: [
          for (final id in ['a', 'b'])
            ReelClip(
              id: id,
              path: 'assets/brand/mockareel-mark.png',
              name: id,
              isVideo: false,
              streetview: StreetviewMedia(mapPath: path, transitionSeconds: 1),
            ),
        ],
      );
      final arrow = StreetviewTimeline.scenes(
        p,
      ).singleWhere((s) => s.kind == 'arrow');
      Future<void> seek(double elapsed) => tester.pumpWidget(
        MaterialApp(
          home: OrbitJourneyCanvas(
            project: p,
            position: arrow.start + elapsed,
            playing: false,
            posterOnly: true,
            overlayOnly: true,
            posters: const {},
          ),
        ),
      );
      await seek(.1);
      expect(
        tester.widget<OrbitMapView>(find.byType(OrbitMapView)).camera.turn,
        0,
      );
      await seek(.6);
      expect(find.byType(OrbitMapView), findsOneWidget);
      expect(
        tester.widget<OrbitMapView>(find.byType(OrbitMapView)).camera.turn,
        greaterThan(0),
      );
      p.clips.last.streetview.mapPath = other;
      await seek(.6);
      final views = tester
          .widgetList<OrbitMapView>(find.byType(OrbitMapView))
          .toList();
      expect(views, hasLength(2));
      expect(views.first.camera.turn, -views.last.camera.turn);
      await seek(29 / 30);
      expect(
        tester
            .widgetList<OrbitMapView>(find.byType(OrbitMapView))
            .last
            .camera
            .progress,
        closeTo(.35, 1e-9),
      );
    },
  );
}
