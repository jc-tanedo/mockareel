import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockareel/model/project.dart';
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
      final restored = await store.importBackup(await store.backup(p));
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
