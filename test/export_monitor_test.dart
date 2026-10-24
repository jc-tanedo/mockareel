import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockareel/theme/app_theme.dart';
import 'package:mockareel/widgets/export_monitor.dart';

void main() {
  testWidgets(
    'export workspace has themed text, responsive preview and cancellation',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var cancelled = false;
      for (final size in [
        const Size(390, 844),
        const Size(844, 390),
        const Size(600, 1024),
        const Size(320, 568),
      ]) {
        tester.view.physicalSize = size;
        // Deliberately outside a Scaffold, reproducing the old fallback text bug.
        await tester.pumpWidget(
          MaterialApp(
            theme: buildAppTheme(),
            home: Stack(
              children: [
                Positioned.fill(
                  child: ExportMonitor(
                    title: 'Weekend feed',
                    status: 'Encoding video…',
                    phase: ExportPhase.encoding,
                    progress: .62,
                    position: 7,
                    duration: 12,
                    preview: const ColoredBox(color: Colors.teal),
                    onCancel: () => cancelled = true,
                  ),
                ),
              ],
            ),
          ),
        );
        await tester.pump();
        final text = tester.element(find.text('Encoding video…'));
        final style = DefaultTextStyle.of(text).style;
        expect(style.decoration, isNot(TextDecoration.underline));
        expect(style.fontSize, lessThan(20));
        expect(find.text('62%'), findsOneWidget);
        expect(find.text('SCENE PREVIEW · 0:07 / 0:12'), findsOneWidget);
        await tester.ensureVisible(find.text('Cancel export'));
        await tester.tap(find.text('Cancel export'));
        expect(tester.takeException(), isNull, reason: '$size');
      }
      expect(cancelled, isTrue);
      await tester.pump(const Duration(seconds: 2));
      expect(find.textContaining('Elapsed 0:0'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
