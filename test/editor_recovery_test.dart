import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockareel/model/maps_web_result.dart';
import 'package:mockareel/model/project.dart';
import 'package:mockareel/pages/maps_editor_page.dart';
import 'package:mockareel/pages/maps_web_header_page.dart';
import 'package:mockareel/pages/maps_web_search_page.dart';
import 'package:mockareel/services/export_maps.dart';
import 'package:mockareel/widgets/maps_editor_scaffold.dart';
import 'package:mockareel/widgets/maps_key_dialog.dart';
import 'package:mockareel/widgets/orbit_locations_editor.dart';
import 'package:mockareel/widgets/streetview_inspector.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/memory_project_store.dart';

class _FailingStore extends MemoryProjectStore {
  bool fail = true;
  int attempts = 0;
  @override
  Future<void> save(ReelProject p) async {
    attempts++;
    if (fail) throw const FileSystemException('Storage full');
    await super.save(p);
  }
}

const photo = 'assets/brand/mockareel-mark.png';
const orbit = 'assets/streetview3d/tokyo.json';

ReelClip _clip(String id, {String? mapPath}) => ReelClip(
  id: id,
  name: id,
  path: photo,
  isVideo: false,
  streetview: StreetviewMedia(
    locationSelected: true,
    mapPath: mapPath,
    place: PlaceDetails(name: id),
  ),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'failed app and system back saves keep the editor open for retry',
    (tester) async {
      final store = _FailingStore(), project = ReelProject();
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(navigatorKey: nav, home: const Scaffold()),
      );
      nav.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => MapsEditorPage(store: store, initialProject: project),
        ),
      );
      await tester.pumpAndSettle();
      MapsEditorScaffold editor() =>
          tester.widget(find.byType(MapsEditorScaffold));
      editor().onChanged();
      await tester.pump();
      await nav.currentState!.maybePop();
      await tester.pump();
      expect(editor().dirty, isTrue);
      expect(store.attempts, 1);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('Could not save project'), findsOneWidget);
      editor().onMenuSelected('projects');
      await tester.pump();
      expect(editor().dirty, isTrue);
      await tester.tap(find.byTooltip('Back to projects'));
      await tester.pump();
      expect(editor().dirty, isTrue);
      store.fail = false;
      await nav.currentState!.maybePop();
      await tester.pumpAndSettle();
      expect(find.byType(MapsEditorScaffold), findsNothing);
      expect((await store.restore()).id, project.id);
    },
  );

  for (final threeD in [false, true]) {
    testWidgets(
      'cancelling a ${threeD ? '3D' : '2D'} replacement preserves the saved place and map',
      (tester) async {
        final clip = _clip('Old place', mapPath: threeD ? orbit : photo);
        final original = clip.streetview.toJson();
        final project = ReelProject(
          template: threeD ? 'streetview-3d' : 'streetview',
          clips: [clip],
        );
        var changes = 0;
        final nav = GlobalKey<NavigatorState>();
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: nav,
            home: Scaffold(
              body: SingleChildScrollView(
                child: StreetviewInspector(
                  project: project,
                  clip: clip,
                  store: MemoryProjectStore(),
                  onChanged: () => changes++,
                  onSettings: () {},
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Select this media’s location'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(MapsWebSearchPage), findsOneWidget);
        nav.currentState!.pop(MapsWebImport(PlaceDetails(name: 'New place')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(
          find.text('Enter pin coordinates'),
          threeD ? findsOneWidget : findsNothing,
        );
        if (!threeD) {
          expect(
            tester
                .widget<MapsWebHeaderPage>(find.byType(MapsWebHeaderPage))
                .place
                .name,
            'New place',
          );
        }
        expect(find.text('Capturing…', skipOffstage: false), findsOneWidget);
        expect(clip.streetview.toJson(), original);
        expect(
          find.text('Preparing photo walkthrough…', skipOffstage: false),
          findsNothing,
        );
        nav.currentState!.pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(clip.streetview.toJson(), original);
        expect(changes, 0);
      },
    );
  }

  testWidgets(
    'map write failure preserves the old capture and retry commits once',
    (tester) async {
      final dir = Directory.systemTemp.createTempSync('map-replacement-');
      addTearDown(() => dir.deleteSync(recursive: true));
      final store = MemoryProjectStore()..root = dir;
      final clip = _clip('Old place', mapPath: photo);
      final project = ReelProject(template: 'streetview', clips: [clip]);
      final nav = GlobalKey<NavigatorState>();
      var changes = 0;
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: nav,
          home: Scaffold(
            body: SingleChildScrollView(
              child: StreetviewInspector(
                project: project,
                clip: clip,
                store: store,
                onChanged: () => changes++,
                onSettings: () {},
              ),
            ),
          ),
        ),
      );
      final png = File(photo).readAsBytesSync();
      Future<void> capture() async {
        await tester.tap(find.text('Select this media’s location'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        nav.currentState!.pop(MapsWebImport(PlaceDetails(name: 'Replacement')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        nav.currentState!.pop(png);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        for (
          int i = 0;
          i < 100 && find.text('Capturing…').evaluate().isNotEmpty;
          i++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 5)),
          );
          await tester.pump();
        }
      }

      await capture();
      await tester.pumpAndSettle();
      expect(find.textContaining('Could not capture map'), findsOneWidget);
      expect(clip.streetview.place.name, 'Old place');
      expect(clip.streetview.mapPath, photo);
      expect(changes, 0);
      Directory('${dir.path}/media').createSync();
      await capture();
      expect(clip.streetview.place.name, 'Replacement');
      expect(File(clip.streetview.mapPath!).readAsBytesSync(), png);
      expect(changes, 1);
    },
  );

  test('2D needs map screens and 3D also needs arrow destinations', () {
    final clips = [
      _clip('first', mapPath: orbit),
      _clip('middle'),
      _clip('last', mapPath: orbit),
    ];
    final project = ReelProject(template: 'streetview', clips: clips);
    expect(project.firstMissingMapClip, isNull);
    clips.first.streetview.transition = 'map';
    expect(project.firstMissingMapClip, 1);
    clips.first.streetview.transition = 'arrow';
    clips.last.streetview.mapPath = null;
    project.streetview.endOnMap = true;
    expect(project.firstMissingMapClip, 2);
    final threeD = ReelProject(template: 'streetview-3d', clips: clips);
    expect(threeD.firstMissingMapClip, 1);
    clips[1].streetview.mapPath = 'missing.map';
    expect(threeD.firstMissingMapClip, 1);
    clips[1].streetview.mapPath = clips.last.streetview.mapPath = orbit;
    expect(threeD.firstMissingMapClip, isNull);
  });

  testWidgets(
    'export opens the affected clip and both settings entries share the saved key',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final clips = [_clip('first', mapPath: orbit), _clip('second')];
      await tester.pumpWidget(
        MaterialApp(
          home: MapsEditorPage(
            store: MemoryProjectStore(),
            initialProject: ReelProject(
              template: 'streetview-3d',
              clips: clips,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Export').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Render MP4'),
            )
            .onPressed,
        isNull,
      );
      await tester.ensureVisible(find.text('Capture map for clip 2'));
      await tester.pump();
      await tester.tap(find.text('Capture map for clip 2'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        tester
            .widget<OrbitLocationsEditor>(find.byType(OrbitLocationsEditor))
            .selected
            ?.id,
        clips.last.streetview.locationId,
      );
      final tileSettings = find.text('Google 3D tile settings');
      await tester.ensureVisible(tileSettings);
      await tester.pump();
      await tester.tap(tileSettings);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.enterText(
        find.descendant(
          of: find.byType(MapsKeyDialog),
          matching: find.byType(TextField),
        ),
        'updated-test-key',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      tester
          .widget<MapsEditorScaffold>(find.byType(MapsEditorScaffold))
          .onMenuSelected('settings');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        tester.widget<MapsKeyDialog>(find.byType(MapsKeyDialog)).initialValue,
        'updated-test-key',
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
}
