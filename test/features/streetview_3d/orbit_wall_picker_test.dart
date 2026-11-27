import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockareel/features/streetview_3d/model/orbit_scene.dart';
import 'package:mockareel/features/streetview_3d/presentation/orbit_wall_picker.dart';
import 'package:mockareel/model/project.dart';
import 'package:mockareel/pages/maps_editor_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/memory_project_store.dart';

class _PhotoStore extends MemoryProjectStore {
  @override
  Future<String> retainMedia(String source, String name) async => source;
}

OrbitScene _twoWallScene() => OrbitScene(
  [
    OrbitFootprint(24, const [
      Offset(-60, 20),
      Offset(-20, 20),
      Offset(-20, 60),
      Offset(-60, 60),
    ]),
    OrbitFootprint(24, const [
      Offset(20, 20),
      Offset(60, 20),
      Offset(60, 60),
      Offset(20, 60),
    ]),
  ],
  List.filled(625, 10),
  'Pick',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('OrbitWallPickerLayout hits projected wall badges and segments', () {
    final scene = _twoWallScene();
    expect(scene.walls.length, greaterThanOrEqualTo(2));
    final layout = OrbitWallPickerLayout.fit(scene, const Size(320, 200));
    final walls = scene.walls.values.toList();
    for (final wall in walls) {
      expect(layout.hitTest(layout.badgeCenter(wall)), wall.id);
      final (a, b) = layout.segment(wall);
      expect(layout.hitTest((a + b) / 2), wall.id);
    }
    expect(layout.hitTest(const Offset(5000, 5000)), isNull);
  });

  testWidgets(
    'Pick wall lets the user select a specific wall and keeps siblings distinct',
    (tester) async {
      final dir = Directory.systemTemp.createTempSync('wall-picker-');
      addTearDown(() => dir.deleteSync(recursive: true));
      final scene = _twoWallScene();
      final ids = scene.walls.keys.toList();
      final w0 = ids[0], w1 = ids[1];
      final mapFile = File('${dir.path}/station.json')
        ..writeAsStringSync(
          '{"credit":"Pick","grid":${List.filled(625, 10)},"shapes":['
          '[24,[-60,20,-20,20,-20,60,-60,60]],'
          '[24,[20,20,60,20,60,60,20,60]]]}',
        );
      final photo = File('${dir.path}/photo.png')..writeAsBytesSync([0]);
      final place = PlaceDetails(name: 'Plaza', latitude: 35, longitude: 139);
      final location = OrbitLocation(place: place, mapPath: mapFile.path);
      final project = ReelProject(
        template: 'streetview-3d',
        streetview: StreetviewSettings(locations: [location]),
        clips: [
          ReelClip(
            id: 'a',
            path: photo.path,
            name: 'A',
            isVideo: false,
            streetview: StreetviewMedia(
              locationId: location.id,
              place: place,
              mapPath: mapFile.path,
              wallId: w0,
            ),
          ),
          ReelClip(
            id: 'b',
            path: photo.path,
            name: 'B',
            isVideo: false,
            streetview: StreetviewMedia(
              locationId: location.id,
              place: place,
              mapPath: mapFile.path,
              wallId: w1,
            ),
          ),
        ],
      );
      final store = _PhotoStore()..root = dir;
      await tester.pumpWidget(
        MaterialApp(
          home: MapsEditorPage(
            initialProject: project,
            store: store,
            fetchGeometry: (_, _) async => mapFile.readAsStringSync(),
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

      await until(() => find.text('Clips').evaluate().isNotEmpty);
      await tester.tap(find.text('Clips').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final pickButton = find.text('Pick wall');
      await until(() => pickButton.evaluate().isNotEmpty);
      await tester.ensureVisible(pickButton);
      await tester.pump();
      await tester.tap(pickButton);
      await tester.pumpAndSettle();

      expect(find.text('Pick building wall'), findsOneWidget);
      final wall2Chip = find.text('Wall 2 · Clip 2');
      expect(wall2Chip, findsOneWidget);
      await tester.tap(wall2Chip);
      await tester.pump();
      expect(project.clips[0].streetview.wallId, w1);
      expect(project.clips[1].streetview.wallId, w0);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    },
  );
}
