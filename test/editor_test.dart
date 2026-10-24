import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockareel/main.dart';
import 'package:mockareel/model/project.dart';
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
