import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mockareel/features/streetview_3d/data/orbit_scene_loader.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockareel/features/streetview_3d/data/open_orbit_map.dart';
import 'package:mockareel/features/streetview_3d/data/orbit_location_defaults.dart';
import 'package:mockareel/features/streetview_3d/model/orbit_scene.dart';
import 'package:mockareel/features/streetview_3d/presentation/orbit_map.dart';
import 'package:mockareel/features/streetview_3d/presentation/photo_walk_frame.dart';
import 'package:mockareel/model/project.dart';
import 'package:mockareel/services/project_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'embedded GPS wins, untagged clips inherit independent pins, and old selections survive',
    () async {
      final clips = [
        for (final id in [
          'first',
          'gps',
          'untagged',
          'invalid',
          'manual',
          'next',
        ])
          ReelClip(id: id, path: id, name: id, isVideo: id == 'gps'),
      ];
      clips[4].streetview
        ..locationSelected = true
        ..place = PlaceDetails(name: 'Selected', latitude: 15, longitude: 120)
        ..mapPath = 'existing.json';
      final seen = <String>{};
      await OrbitLocationDefaults.read(clips, (c) async {
        seen.add(c.id);
        return switch (c.id) {
          'gps' => [-33.85, 151.21],
          'invalid' => [91.0, 500.0],
          _ => null,
        };
      });
      OrbitLocationDefaults.inherit(clips);
      expect(seen, isNot(contains('manual')));
      expect(clips.first.streetview.canCaptureMap, false);
      expect(clips[1].streetview.locationOrigin, 'media');
      expect(clips[2].streetview.place.latitude, -33.85);
      expect(clips[3].streetview.place.longitude, 151.21);
      expect(clips.last.streetview.mapPath, 'existing.json');
      clips[1].streetview.mapPath = 'new.json';
      OrbitLocationDefaults.inherit(clips);
      expect(clips[2].streetview.mapPath, 'new.json');
      clips[2].streetview.place.name = 'Edited independently';
      expect(clips[1].streetview.place.name, '');
      expect(clips[3].streetview.place.name, '');
      final restored = ReelClip.fromJson(clips[2].toJson());
      expect(restored.streetview.locationOrigin, 'previous');
      expect(restored.streetview.place.latitude, -33.85);
    },
  );
  test(
    'open fallback renders a station tagged on a multipolygon relation',
    () async {
      const lat = 48.1402, lon = 11.5583;
      final a = {'lat': lat, 'lon': lon},
          b = {'lat': lat + .001, 'lon': lon},
          c = {'lat': lat, 'lon': lon + .001};
      final client = MockClient((request) async {
        if (request.url.host != 'overpass-api.de') {
          return http.Response('', 404);
        }
        expect(
          request.url.queryParameters['data'],
          contains('["building:part"]'),
        );
        return http.Response(
          jsonEncode({
            'elements': [
              {
                'type': 'relation',
                'tags': {'building': 'train_station', 'height': '18 m'},
                'members': [
                  {
                    'role': 'outer',
                    'geometry': [a, b],
                  },
                  {
                    'role': 'outer',
                    'geometry': [a, c, b],
                  },
                ],
              },
            ],
          }),
          200,
        );
      });
      final scene = OrbitScene.decode(
        await http.runWithClient(
          () => OpenOrbitMap.fetch(lat, lon),
          () => client,
        ),
      );
      expect(scene.shapes.single.height, 18);
      expect(scene.shapes.single.points.first, scene.shapes.single.points.last);
      expect(scene.coverage, contains('1 building'));
    },
  );
  test(
    'Tokyo Station has offline geometry and a fixed pin during the orbit',
    () async {
      final scene = OrbitScene.decode(
        await OpenOrbitMap.fetch(OpenOrbitMap.tokyoLat, OpenOrbitMap.tokyoLon),
      );
      expect(scene.shapes.where((s) => s.height > 5).length, greaterThan(100));
      expect(scene.grid.toSet().length, greaterThan(5));
      expect(scene.credit, contains('PLATEAU'));
      Future<List<int>> frame(double t) async {
        const size = ui.Size(360, 552);
        final recorder = ui.PictureRecorder();
        OrbitPainter(scene, t, true).paint(ui.Canvas(recorder), size);
        final picture = recorder.endRecording();
        final image = await picture.toImage(360, 552);
        final pixels = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List();
        final output = Platform.environment['ORBIT_TEST_IMAGES'];
        if (output != null) {
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '$output/tokyo-$t.png',
          ).writeAsBytes(png!.buffer.asUint8List());
        }
        image.dispose();
        picture.dispose();
        return pixels;
      }

      final a = await frame(0), b = await frame(1);
      const pin = (298 * 360 + 180) * 4;
      expect(a.sublist(pin, pin + 3), b.sublist(pin, pin + 3));
      expect(a[pin], greaterThan(a[pin + 1] + 100));
      var changed = 0;
      for (var i = 0; i < a.length; i += 4) {
        if ((a[i] - b[i]).abs() > 20) changed++;
      }
      expect(changed, greaterThan(15000));
    },
  );

  test(
    'restoring a 3D project preserves depth order, direction and orbit assets',
    () async {
      SharedPreferences.setMockInitialValues({});
      final dir = await Directory.systemTemp.createTemp();
      addTearDown(() => dir.delete(recursive: true));
      final store = ProjectStore(root: Directory('${dir.path}/projects'));
      await store.initialize();
      final source = await File('${dir.path}/photo.jpg').writeAsBytes([1]);
      final map = await File('${dir.path}/map.json').writeAsString(
        await OpenOrbitMap.fetch(OpenOrbitMap.tokyoLat, OpenOrbitMap.tokyoLon),
      );
      final layers = <String>[];
      for (var i = 0; i < 3; i++) {
        layers.add(
          (await File('${dir.path}/layer-$i.png').writeAsBytes([i])).path,
        );
      }
      final p = ReelProject(
        template: 'streetview-3d',
        clips: [
          ReelClip(
            id: 'a',
            path: source.path,
            name: 'Photo',
            isVideo: false,
            streetview: StreetviewMedia(
              mapPath: map.path,
              walkLayers: layers,
              walkDepth: List.generate(1024, (n) => n % 256),
              walkMove: 'left',
            ),
          ),
        ],
      );
      final restored = await store.importBackup(await store.backup(p));
      await store.save(restored);
      final project = (await store.projects()).first;
      expect(project.isStreetview3d, true);
      final clip = project.clips.single, settings = clip.streetview;
      expect(settings.walking, true);
      expect(settings.walkDepth, List.generate(1024, (n) => n % 256));
      final start = PhotoWalkFrame.pose(clip, 0, 2);
      final near = PhotoWalkFrame.pose(clip, clip.duration, 2);
      final far = PhotoWalkFrame.pose(clip, clip.duration, 0);
      expect(start.offsetX, 0);
      expect(near.offsetX, greaterThan(far.offsetX));
      settings.walkMove = 'right';
      expect(
        PhotoWalkFrame.pose(clip, clip.duration, 2).offsetX,
        -near.offsetX,
      );
      settings.walkMove = 'forward';
      expect(
        PhotoWalkFrame.pose(clip, clip.duration, 2).scale,
        greaterThan(PhotoWalkFrame.pose(clip, clip.duration, 0).scale),
      );
      for (var i = 0; i < 3; i++) {
        expect(settings.walkLayers[i], isNot(layers[i]));
        expect(await File(settings.walkLayers[i]).readAsBytes(), [i]);
      }
      expect(
        (await OrbitSceneLoader.load(settings.mapPath!)).shapes,
        isNotEmpty,
      );
    },
  );
}
