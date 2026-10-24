import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockareel/model/project.dart';
import 'package:mockareel/pages/feed_editor_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/memory_project_store.dart';

void main() {
  testWidgets(
    'tablet search keeps focus and keyboard connection when insets change',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1100, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final project = ReelProject(template: 'tiktok-feed');
      final store = MemoryProjectStore();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: FeedEditorPage(store: store, project: project),
        ),
      );
      await tester.pumpAndSettle();
      final field = find.widgetWithText(TextFormField, 'Search query');
      await tester.showKeyboard(field);
      final editable = find.descendant(
        of: field,
        matching: find.byType(EditableText),
      );
      final state = tester.state<EditableTextState>(editable);
      expect(state.widget.focusNode.hasFocus, true);
      tester.view.viewInsets = const FakeViewPadding(bottom: 320);
      await tester.pumpAndSettle();
      expect(tester.state<EditableTextState>(editable), same(state));
      expect(state.widget.focusNode.hasFocus, true);
      expect(tester.testTextInput.isVisible, true);
      tester.testTextInput.enterText('a tablet search');
      await tester.pump(const Duration(milliseconds: 800));
      expect(project.feed.search, 'a tablet search');
      expect((await store.restore()).feed.search, 'a tablet search');
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pumpAndSettle();
      expect(tester.state<EditableTextState>(editable), same(state));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
