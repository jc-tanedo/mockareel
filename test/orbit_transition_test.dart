import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockareel/model/orbit_media_pose.dart';
import 'package:mockareel/model/orbit_dolly.dart';
import 'package:mockareel/widgets/streetview_arrows.dart';
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

  StreetviewMedia pin(double lat, double lon) => StreetviewMedia(
    place: PlaceDetails(latitude: lat, longitude: lon),
  );
  final source = pin(35, 139), destination = pin(35.001, 139.002);
  OrbitDolly trip(OrbitScene world, double t) =>
      OrbitDolly.between(source, destination, world, world, t);
  test(
    'saved Tokyo Station geometry yields a visible wall on reopen',
    () async {
      final saved = await OrbitScene.load('assets/streetview3d/tokyo.json');
      expect(saved.wallMount, isNotNull);
      expect(saved.placementDescription, contains('Media on building wall'));
    },
  );
  test('map flight meets the overhead map and the exact media pose', () {
    for (final scene in [flat, city]) {
      for (final returning in [true, false]) {
        final start = OrbitMediaPose.mapFlight(scene, 0, returning: returning);
        expect(start.heightScale, closeTo(0, 1e-8));
        expect(
          start.pin(const Size(360, 640), .8 * start.zoom).dy,
          closeTo(276, 1e-8),
        );
        final mid = OrbitMediaPose.mapFlight(scene, .5, returning: returning);
        expect(mid.heightScale, greaterThan(0));
        expect(mid.heightScale, lessThan(.77));
        expect(
          OrbitMediaPose.mapFlight(scene, 1, returning: returning).native,
          OrbitMediaPose.at('media', returning ? 1 : 0, scene: scene).native,
        );
      }
    }
  });
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
          trip(scene, .6).arrival,
          trip(scene, .6).departure,
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
        Offset(-200, -200),
        Offset(200, -200),
        Offset(200, 200),
        Offset(-200, 200),
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
    'the camera travels monotonically toward the next pin and both views agree in world space',
    () {
      for (final scene in [flat, city]) {
        final beginning = trip(scene, 0), ending = trip(scene, 1);
        expect(
          beginning.departure.matrix.storage,
          OrbitMediaPose.at('media', 1, scene: scene).matrix.storage,
        );
        expect(
          ending.arrival.matrix.storage,
          OrbitMediaPose.at('media', 0, scene: scene).matrix.storage,
        );
        var last = -1.0;
        for (final t in [.1, .3, .5, .7, .9]) {
          final route = trip(scene, t), a = route.departure, b = route.arrival;
          expect(a.focus.dx, greaterThan(last));
          last = a.focus.dx;
          expect(a.focus.dy, lessThan(0));
          expect(
            a.focus.dx - b.focus.dx,
            closeTo(.002 * 111320 * cos(35.0005 * pi / 180), 1e-6),
          );
          expect(a.focus.dy - b.focus.dy, closeTo(-111.132, 1e-6));
          expect(a.heading, closeTo(b.heading, 1e-10));
          expect(a.zoom, closeTo(b.zoom, 1e-10));
        }
      }
      final wrapped = OrbitDolly.between(
        pin(0, 179.999),
        pin(0, -179.999),
        flat,
        flat,
        .5,
      );
      expect(wrapped.departure.focus.dx, closeTo(111.32, .001));
      final distant = OrbitDolly.between(
        pin(40, -80),
        pin(0, 50),
        null,
        null,
        .5,
      );
      expect(distant.departure.focus.distance, closeTo(225, .001));
      final atlas = OrbitScene(
        [],
        [],
        'Atlas',
        atlas: MemoryImage(Uint8List(1)),
      );
      expect(
        OrbitDolly.between(
          source,
          destination,
          atlas,
          city,
          .5,
        ).arrival.zoom.isFinite,
        true,
      );
    },
  );

  test(
    'buildings on the camera side can cover pixels inside the media plane',
    () async {
      final pose = OrbitMediaPose.at('media', .5);
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
        closeTo(0, 1e-8),
      );
      p.clips.first.streetview.place = source.place;
      p.clips.last.streetview.place = destination.place;
      p.clips.last.streetview.mapPath = other;
      await seek(.6);
      final views = tester
          .widgetList<OrbitMapView>(find.byType(OrbitMapView))
          .toList();
      expect(views, hasLength(2));
      expect(views.first.camera.focus.dx, greaterThan(0));
      expect(views.last.camera.focus.dx, lessThan(0));
      // The chevron center is the ground-projected layout center in the clip's 360x640 canvas.
      final clipNode = find.byKey(const ValueKey('orbit-clip-a'));
      final leftArrow = find
          .descendant(of: clipNode, matching: find.byType(StreetviewArrow))
          .first;
      final box = tester.renderObject<RenderBox>(clipNode);
      final actual = box.globalToLocal(tester.getCenter(leftArrow));
      final expected = MatrixUtils.transformPoint(
        views.first.camera.groundFrom(
          OrbitMediaPose.at('media', 1, scene: views.first.scene),
        ),
        const Offset(63, 476),
      );
      expect((actual - expected).distance, lessThan(1e-6));
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
