// Optional visual review: flutter test tool/render_export_preview_test.dart
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockareel/model/feed.dart';
import 'package:mockareel/model/project.dart';
import 'package:mockareel/theme/app_theme.dart';
import 'package:mockareel/widgets/export_monitor.dart';
import 'package:mockareel/widgets/feed_canvas.dart';

void main() {
  testWidgets('render encoder workspace at phone and landscape sizes', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final output = Directory('/tmp/mockareel-export-preview');
    await tester.runAsync(() async {
      await output.create(recursive: true);
      final sdk = Platform.environment['FLUTTER_ROOT'];
      for (final font in [
        ('Roboto', 'Roboto-Regular.ttf'),
        ('MaterialIcons', 'MaterialIcons-Regular.otf'),
      ]) {
        await (FontLoader(font.$1)..addFont(
              File(
                '$sdk/bin/cache/artifacts/material_fonts/${font.$2}',
              ).readAsBytes().then(ByteData.sublistView),
            ))
            .load();
      }
    });
    final p = ReelProject(
      template: 'tiktok-feed',
      title: 'Tokyo on my feed',
      feed: FeedSettings(search: 'A little taste of Tokyo'),
      clips: [
        ReelClip(
          id: 'one',
          path: '/tmp/mockareel-reference-preview/source-0.png',
          name: 'Tokyo.jpg',
          isVideo: false,
          duration: 8,
          post: FeedPost(
            username: 'tokyo.diary',
            title: 'You had me at sushi',
            caption: 'A little Tokyo moment. #tokyo #foodfinds',
            verified: true,
          ),
        ),
      ],
    );
    final key = GlobalKey();
    for (final entry in [
      ('export-phone', const Size(390, 844), ExportPhase.encoding, .62, 5.5),
      (
        'export-landscape',
        const Size(844, 390),
        ExportPhase.encoding,
        .62,
        5.5,
      ),
      ('export-prepare', const Size(390, 844), ExportPhase.preparing, .12, 1.3),
    ]) {
      tester.view.physicalSize = entry.$2;
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(),
            home: ExportMonitor(
              title: p.title,
              status: entry.$3 == ExportPhase.preparing
                  ? 'Preparing scene 1 of 4…'
                  : 'Encoding video…',
              phase: entry.$3,
              progress: entry.$4,
              position: entry.$5,
              duration: 10.8,
              preview: FeedCanvas(
                project: p,
                position: entry.$5,
                posterOnly: true,
              ),
              onCancel: () {},
            ),
          ),
        ),
      );
      await tester.runAsync(
        () => precacheImage(
          FileImage(File(p.clips.first.path)),
          tester.element(find.byType(ExportMonitor)),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final image =
            await (key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        try {
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '${output.path}/${entry.$1}.png',
          ).writeAsBytes(png!.buffer.asUint8List());
        } finally {
          image.dispose();
        }
      });
    }
    await tester.pumpWidget(const SizedBox());
  });
}
