import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockareel/model/project.dart';
import 'package:mockareel/theme/app_theme.dart';
import 'package:mockareel/widgets/editor_section_card.dart';
import 'package:mockareel/widgets/editor_workspace.dart';
import 'package:mockareel/widgets/streetview_inspector.dart';
import 'support/memory_project_store.dart';

void main() {
  testWidgets(
    'Streetview motion, overlays and journey timing are peer cards with aligned headings',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final clip = ReelClip(
        id: 'a',
        path: 'photo.png',
        name: 'Photo',
        isVideo: false,
      );
      final project = ReelProject(template: 'streetview', clips: [clip]);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, update) => EditorWorkspace(
                previewBuilder: (_) => const SizedBox(),
                inspector: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: StreetviewInspector(
                    project: project,
                    clip: clip,
                    store: MemoryProjectStore(),
                    onChanged: () => update(() {}),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      for (final size in [
        const Size(360, 800),
        const Size(844, 390),
        const Size(1024, 768),
      ]) {
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        expect(find.byType(ExpansionTile), findsNothing);
        double? left, previousBottom;
        for (final title in [
          'Camera motion',
          'Street View overlays',
          'Journey timing and ending',
        ]) {
          final heading = find.text(title);
          final card = find.ancestor(
            of: heading,
            matching: find.byType(EditorSectionCard),
          );
          expect(
            card,
            findsOneWidget,
            reason: '$title must not be nested inside a peer card',
          );
          final titleRect = tester.getRect(heading),
              cardRect = tester.getRect(card);
          left ??= titleRect.left;
          expect(titleRect.left, closeTo(left, .001));
          if (previousBottom != null) {
            expect(cardRect.top, greaterThanOrEqualTo(previousBottom));
          }
          previousBottom = cardRect.bottom;
        }
        expect(find.text('Applies to the whole journey'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      final turn = find.widgetWithText(SwitchListTile, 'Slow turntable');
      await tester.ensureVisible(turn);
      await tester.pumpAndSettle();
      await tester.tap(turn);
      await tester.pumpAndSettle();
      expect(clip.streetview.turntable, true);
      final angle = find.ancestor(
        of: find.text('Turn angle'),
        matching: find.byType(EditorSlider),
      );
      tester.widget<EditorSlider>(angle).onChanged(-7);
      await tester.pump();
      expect(clip.streetview.turntableDegrees, -7);
      final timing = find.ancestor(
        of: find.text('Opening map'),
        matching: find.byType(EditorSlider),
      );
      tester.widget<EditorSlider>(timing).onChanged(4);
      await tester.pump();
      expect(project.streetview.openingMapSeconds, 4);
      expect(clip.duration, 3.5);
      expect(tester.takeException(), isNull);
    },
  );
}
