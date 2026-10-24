import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:mockareel/main.dart';
import 'package:mockareel/model/project.dart';
import 'package:mockareel/widgets/creation_steps.dart';
import 'package:mockareel/widgets/reel_preview.dart';
import 'support/memory_project_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late MemoryProjectStore store;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store = MemoryProjectStore();
  });
  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MockareelApp(store: store));
    await tester.pumpAndSettle();
  }

  testWidgets('real editor and export empty state fit a narrow phone', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('MAPS PLACE STORY · 9:16'), findsOneWidget);
    for (final tab in ['Timeline', 'Text', 'Audio', 'Export', 'Place']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$tab layout');
    }
    await tester.tap(find.text('Export').last);
    await tester.pumpAndSettle();
    final renderButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Render MP4'),
    );
    expect(renderButton.onPressed, isNull);
    expect(find.textContaining('Add at least one photo'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'output theme toggles and saves independently of the editor theme',
    (tester) async {
      await open(tester);
      expect((await store.restore()).darkOutput, false);
      await tester.tap(find.text('Look'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Dark output'));
      await tester.tap(find.byTooltip('Dark output'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Save project'));
      await tester.pumpAndSettle();
      expect((await store.restore()).darkOutput, true);
      expect(
        Theme.of(tester.element(find.byType(EditorPage))).brightness,
        Brightness.dark,
      );
      await tester.pumpWidget(const SizedBox());
      await open(tester);
      await tester.tap(find.text('Look'));
      await tester.pumpAndSettle();
      final picker = tester.widget<SegmentedButton<bool>>(
        find.byType(SegmentedButton<bool>),
      );
      expect(picker.selected, {true});
      await tester.ensureVisible(find.byTooltip('Light output'));
      await tester.tap(find.byTooltip('Light output'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Save project'));
      await tester.pumpAndSettle();
      expect((await store.restore()).darkOutput, false);
      expect(
        Theme.of(tester.element(find.byType(EditorPage))).brightness,
        Brightness.dark,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'numbered steps guide forward without requiring optional text or music',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await open(tester);
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Step 3 of 5, Text, optional'))
            .getSemanticsData()
            .hasAction(ui.SemanticsAction.tap),
        true,
      );
      semantics.dispose();
      expect(find.text('STEP 1 OF 5'), findsOneWidget);
      for (final next in ['Timeline', 'Text', 'Audio', 'Export']) {
        await tester.tap(find.byTooltip('Next step: $next'));
        await tester.pumpAndSettle();
      }
      expect(find.text('STEP 5 OF 5'), findsOneWidget);
      expect((await store.restore()).tags, isEmpty);
      expect((await store.restore()).music, isNull);
      await tester.tap(find.text('Place').last);
      await tester.pumpAndSettle();
      expect(find.text('STEP 1 OF 5'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'preview stays pinned while the inspector scrolls and expands on demand',
    (tester) async {
      await open(tester);
      final rect = tester.getRect(find.byType(TimelinePreview));
      await tester.drag(
        find.byKey(const ValueKey('place-inspector-0')),
        const Offset(0, -170),
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(TimelinePreview)), rect);
      await tester.tap(find.byTooltip('Expand preview'));
      await tester.pumpAndSettle();
      expect(find.text('Details'), findsNothing);
      expect(
        tester.getSize(find.byType(TimelinePreview)).height,
        greaterThan(rect.height),
      );
      await tester.tap(find.byTooltip('Show editing controls'));
      await tester.pumpAndSettle();
      expect(find.text('Details'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('controls fit a short phone and landscape with real clips', (
    tester,
  ) async {
    await store.save(
      ReelProject(
        clips: [
          ReelClip(
            id: 'one',
            path: '/missing.jpg',
            name: 'A very long media filename.jpg',
            isVideo: false,
          ),
        ],
      ),
    );
    await open(tester);
    for (final size in [const Size(320, 568), const Size(844, 390)]) {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      for (final step in ['Timeline', 'Text', 'Audio', 'Export', 'Place']) {
        await tester.tap(find.text(step).last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$size $step');
      }
    }
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'keyboard gives the inspector space while preserving the focused field',
    (tester) async {
      await open(tester);
      final field = find.widgetWithText(TextField, 'Place name');
      await tester.ensureVisible(field);
      await tester.tap(field);
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(find.byType(CreationSteps), findsNothing);
      expect(find.byType(TimelinePreview), findsNothing);
      await tester.enterText(field, 'Keyboard edit');
      tester.view.resetViewInsets();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(find.byType(CreationSteps), findsOneWidget);
      await tester.tap(find.byTooltip('Save project'));
      await tester.pumpAndSettle();
      expect((await store.restore()).place.name, 'Keyboard edit');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('edited place persists and restores with the project', (
    tester,
  ) async {
    await open(tester);
    final field = find.widgetWithText(TextField, 'Place name');
    await tester.ensureVisible(field);
    await tester.enterText(field, 'Weekend cafe');
    await tester.tap(find.byTooltip('Save project'));
    await tester.pumpAndSettle();
    expect((await store.restore()).place.name, 'Weekend cafe');
    await tester.pumpWidget(const SizedBox());
    await open(tester);
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, 'Place name'))
          .controller!
          .text,
      'Weekend cafe',
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('timeline uses real clip count and independent timing', (
    tester,
  ) async {
    final p = ReelProject(
      clips: List.generate(
        7,
        (i) => ReelClip(
          id: '$i',
          path: '/missing/$i.jpg',
          name: 'Photo $i',
          isVideo: false,
          duration: i + 1,
        ),
      ),
    );
    await store.save(p);
    await open(tester);
    await tester.tap(find.text('Timeline').last);
    await tester.pumpAndSettle();
    expect(find.text('7 clips · 28.0 seconds'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byTooltip('Remove clip 1'),
      150,
      scrollable: find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .first,
    );
    await tester.tap(find.byTooltip('Remove clip 1'));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byWidgetPredicate(
        (w) => w is ListView && w.scrollDirection == Axis.vertical,
      ),
      const Offset(0, 800),
    );
    await tester.pumpAndSettle();
    expect(find.text('6 clips · 27.0 seconds'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Save project'));
    await tester.pumpAndSettle();
    expect((await store.restore()).clips.first.name, 'Photo 1');
    await tester.pumpWidget(const SizedBox());
  });
}
