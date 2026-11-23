import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockareel/model/project.dart';
import 'package:mockareel/model/orbit_scene.dart';
import 'package:mockareel/services/orbit_wall_placement.dart';
import 'package:mockareel/widgets/reel_preview.dart';
import 'package:mockareel/model/maps_web_result.dart';
import 'package:mockareel/pages/maps_editor_page.dart';
import 'package:mockareel/pages/maps_web_search_page.dart';
import 'package:mockareel/services/project_store.dart';
import 'package:mockareel/services/open_orbit_map.dart';
import 'package:mockareel/widgets/orbit_location_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/memory_project_store.dart';

class _PhotoStore extends MemoryProjectStore {
  @override
  Future<String> retainMedia(String source, String name) async => source;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'choose locations before media, reopen draft and import a batch at the selected pin',
    (tester) async {
      final store = _PhotoStore();
      var project = ReelProject(template: 'streetview-3d');
      final nav = GlobalKey<NavigatorState>();
      var kyotoAttempts = 0;
      Future<void> show() async {
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: nav,
            home: MapsEditorPage(
              store: store,
              initialProject: project,
              fetchGeometry: (lat, lon) async {
                if (lat == 35 && ++kyotoAttempts == 1) {
                  throw const FormatException('offline');
                }
                return OpenOrbitMap.fetch(
                  OpenOrbitMap.tokyoLat,
                  OpenOrbitMap.tokyoLon,
                );
              },
            ),
          ),
        );
        await tester.pump();
        for (
          int i = 0;
          i < 50 && find.text('Choose journey locations').evaluate().isEmpty;
          i++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump(const Duration(milliseconds: 20));
        }
        await tester.pump(const Duration(milliseconds: 400));
      }

      const picker = MethodChannel('plugins.flutter.io/image_picker');
      var picks = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(picker, (
        call,
      ) async {
        expect(call.method, 'pickMedia');
        picks++;
        return [
          'assets/brand/mockareel-mark.png',
          'assets/brand/icon-preview.png',
        ];
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          picker,
          null,
        ),
      );
      await show();
      expect(find.text('Choose journey locations'), findsOneWidget);
      final dir = Directory.systemTemp.createTempSync('planned-orbit-');
      addTearDown(() => dir.deleteSync(recursive: true));
      Directory('${dir.path}/media').createSync();
      store.root = dir;
      await tester.tap(find.text('Use Tokyo Station'));
      await tester.pump();
      for (
        var i = 0;
        i < 100 && project.streetview.locations.first.mapPath == null;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      expect(
        File(project.streetview.locations.first.mapPath!).existsSync(),
        isTrue,
      );
      await tester.ensureVisible(find.text('Add location'));
      await tester.pump();
      await tester.tap(find.text('Add location'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(MapsWebSearchPage), findsOneWidget);
      nav.currentState!.pop(
        MapsWebImport(
          PlaceDetails(name: 'Kyoto', latitude: 35, longitude: 135),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Geometry download failed'), findsOneWidget);
      await tester.ensureVisible(find.text('Retry geometry'));
      await tester.tap(find.text('Retry geometry'));
      for (
        var i = 0;
        i < 100 && project.streetview.locations.last.mapPath == null;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      expect(kyotoAttempts, 2);
      expect(find.text('3D geometry saved'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(picks, 0);
      expect(project.clips, isEmpty);
      expect((await store.restore()).streetview.locations.map((l) => l.label), [
        'Tokyo Station',
        'Kyoto',
      ]);
      await tester.pumpWidget(const SizedBox());
      project = await store.restore();
      await show();
      final target = project.streetview.locations.first;
      final button = find.text('Add clips here');
      await tester.ensureVisible(button);
      await tester.pump();
      await tester.tap(button);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(picks, 1);
      expect(project.clips, hasLength(2));
      expect(
        project.clips.map((c) => c.streetview.locationId),
        everyElement(target.id),
      );
      expect(
        project.clips.map((c) => c.streetview.place.latitude),
        everyElement(target.place.latitude),
      );
      expect(find.text('Arrange your clips'), findsOneWidget);
      expect(
        project.clips.map((c) => c.streetview.mapPath),
        everyElement(target.mapPath),
      );
      for (
        int i = 0;
        i < 80 && project.clips.any((c) => c.streetview.wallId == null);
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      expect(
        project.clips.map((c) => c.streetview.wallId),
        everyElement(isNotNull),
      );
      expect(
        project.clips.first.streetview.wallId,
        isNot(project.clips.last.streetview.wallId),
      );
      final locationPicker = tester.widget<OrbitLocationPicker>(
        find.byType(OrbitLocationPicker),
      );
      locationPicker.onChanged!(project.streetview.locations.last);
      await tester.pump();
      expect(project.clips.first.streetview.place.name, 'Kyoto');
      expect(project.clips.last.streetview.locationId, target.id);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'a reopened clip previews its saved placement and can find a new wall',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final dir = Directory.systemTemp.createTempSync('orbit-wall-');
      addTearDown(() => dir.deleteSync(recursive: true));
      Directory('${dir.path}/media').createSync();
      final terrain = jsonEncode({
        'grid': List.filled(625, 0),
        'shapes': [],
        'credit': 'Test map',
      });
      final path = File('${dir.path}/terrain.json')..writeAsStringSync(terrain);
      final project = ReelProject(template: 'streetview-3d');
      final location = OrbitLocation(
        place: PlaceDetails(name: 'Station', latitude: 35, longitude: 139),
        mapPath: path.path,
      );
      project.streetview.locations.add(location);
      final clip = ReelClip(
        id: 'photo',
        path: 'assets/brand/mockareel-mark.png',
        name: 'Photo',
        isVideo: false,
      );
      project.streetview.addClipsAt(location, project.clips, [clip]);
      clip.streetview.mapPath = '${dir.path}/lost.json';
      clip.streetview.streetviewTitle = 'Artist title';
      final store = _PhotoStore()..root = dir;
      var attempts = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: MapsEditorPage(
            initialProject: project,
            store: store,
            fetchGeometry: (_, _) async => ++attempts == 1
                ? terrain
                : File('assets/streetview3d/tokyo.json').readAsStringSync(),
          ),
        ),
      );
      Future<void> until(bool Function() condition) async {
        for (int i = 0; i < 100 && !condition(); i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump(const Duration(milliseconds: 20));
        }
        expect(condition(), isTrue);
      }

      final findWall = find.text('Find a wall with open data');
      await until(
        () =>
            clip.streetview.mapPath == path.path &&
            findWall.evaluate().isNotEmpty,
      );
      expect(find.textContaining('No building footprints'), findsOneWidget);
      expect(find.byKey(const ValueKey('orbit-clip-photo')), findsWidgets);
      await tester.ensureVisible(findWall);
      await tester.pump();
      await tester.tap(findWall);
      await until(
        () =>
            find.textContaining('No suitable wall found').evaluate().isNotEmpty,
      );
      expect(location.mapPath, path.path);
      await tester.tap(findWall);
      await until(
        () =>
            find
                .textContaining('Media on building wall')
                .evaluate()
                .isNotEmpty &&
            location.mapPath != path.path,
      );
      expect(clip.streetview.mapPath, location.mapPath);
      expect(clip.streetview.streetviewTitle, 'Artist title');
      await until(() => clip.streetview.wallId != null);
      await tester.tap(find.text('Clips').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final shuffle = find.text('Shuffle wall');
      await until(() => shuffle.evaluate().isNotEmpty);
      await tester.ensureVisible(shuffle);
      await tester.pump();
      final previous = clip.streetview.wallId;
      await tester.tap(shuffle);
      await tester.pump();
      expect(clip.streetview.wallId, isNot(previous));
      expect(
        tester
            .widget<TimelinePreview>(find.byType(TimelinePreview))
            .initialPosition,
        closeTo(
          project.streetview.openingMapSeconds + .85 * clip.duration,
          1e-7,
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(
        (await store.restore()).clips.single.streetview.wallId,
        clip.streetview.wallId,
      );

      await tester.pumpWidget(const SizedBox());
    },
  );

  test(
    'legacy clips recover shared geometry and preserve individual edits',
    () {
      final project = ReelProject(template: 'streetview-3d');
      final pin = OrbitLocation(place: PlaceDetails(name: 'Station'));
      project.streetview.locations.add(pin);
      for (final path in [null, 'saved.json', 'override.json']) {
        project.clips.add(
          ReelClip(
            id: newId(),
            path: 'clip.jpg',
            name: 'Clip',
            isVideo: false,
            streetview: StreetviewMedia(
              locationId: pin.id,
              mapPath: path,
              streetviewTitle: 'Custom title',
            ),
          ),
        );
      }
      final saved = ReelProject.fromJson(project.toJson());
      expect(saved.streetview.adoptClipLocations(saved.clips), isTrue);
      expect(saved.streetview.locations.single.mapPath, 'saved.json');
      expect(saved.clips.map((c) => c.streetview.mapPath), [
        'saved.json',
        'saved.json',
        'override.json',
      ]);
      expect(saved.clips.first.streetview.streetviewTitle, 'Custom title');
      expect(saved.streetview.adoptClipLocations(saved.clips), isFalse);
    },
  );

  test(
    'backups restore empty locations and shared captures in journey order',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'orbit-location-backup-',
      );
      addTearDown(() => dir.delete(recursive: true));
      final store = ProjectStore(root: dir);
      await store.initialize();
      final p = ReelProject(template: 'streetview-3d');
      final plan = p.streetview;
      final locations = [
        for (final name in ['Tokyo', 'Kyoto', 'Osaka'])
          OrbitLocation(
            place: PlaceDetails(name: name),
            mapPath: 'assets/streetview3d/tokyo.json',
            overviewPath: 'assets/brand/mockareel-mark.png',
          ),
      ];
      plan.locations.addAll(locations);
      ReelClip clip(String id) => ReelClip(
        id: id,
        path: 'assets/brand/mockareel-mark.png',
        name: id,
        isVideo: false,
      );
      plan.addClipsAt(locations[1], p.clips, [clip('kyoto')]);
      plan.addClipsAt(locations[0], p.clips, [clip('tokyo1'), clip('tokyo2')]);
      plan.addClipsAt(locations[0], p.clips, [clip('tokyo3')]);
      final scene = await OrbitScene.load(locations.first.mapPath!);
      final placement = OrbitWallPlacement();
      for (final c in p.clips) {
        placement.choose(c, p.clips, scene);
      }
      placement.choose(p.clips.first, p.clips, scene, shuffle: true);
      final restored = await store.importBackup(await store.backup(p));
      expect(
        restored.clips.map((c) => c.streetview.wallId),
        p.clips.map((c) => c.streetview.wallId),
      );
      expect(
        restored.clips.first.streetview.visitedWalls,
        p.clips.first.streetview.visitedWalls,
      );
      expect(restored.clips.map((c) => c.name), [
        'tokyo1',
        'tokyo2',
        'tokyo3',
        'kyoto',
      ]);
      expect(restored.streetview.locations.map((l) => l.label), [
        'Tokyo',
        'Kyoto',
        'Osaka',
      ]);
      expect(
        restored.clips.map((c) => restored.streetview.locationFor(c)?.label),
        ['Tokyo', 'Tokyo', 'Tokyo', 'Kyoto'],
      );
      final paths = {
        ...restored.streetview.locations.map((l) => l.mapPath),
        ...restored.clips.map((c) => c.streetview.mapPath),
      };
      expect(paths, hasLength(1));
      final overviews = restored.streetview.locations
          .map((l) => l.overviewPath)
          .toSet();
      expect(overviews, hasLength(1));
      expect(File(overviews.single!).existsSync(), true);
      expect(paths.single, startsWith(dir.path));
      expect(
        File(paths.single!).readAsStringSync(),
        File(locations.first.mapPath!).readAsStringSync(),
      );
      restored.clips.removeAt(0);
      expect(restored.streetview.adoptClipLocations(restored.clips), false);
    },
  );
}
