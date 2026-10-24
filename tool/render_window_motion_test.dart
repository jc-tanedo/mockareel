// Optional visual review: flutter test tool/render_window_motion_test.dart
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockareel/model/feed.dart';
import 'package:mockareel/model/project.dart';
import 'package:mockareel/widgets/feed_canvas.dart';

void main() {
  testWidgets('render app launch and dismissal samples', (tester) async {
    tester.view.physicalSize = const Size(1000, 560);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
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
      feed: FeedSettings(opening: 'home', homeSeconds: .5, closeToHome: true),
      clips: [
        ReelClip(
          id: 'photo',
          path: '/tmp/mockareel-reference-preview/source-0.png',
          name: 'Photo',
          isVideo: false,
          duration: 1,
        ),
      ],
    );
    final key = GlobalKey();
    Widget row(String label, List<double> times, double start) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final time in times)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(
                  children: [
                    SizedBox(
                      width: 120,
                      height: 120 * 16 / 9,
                      child: FeedCanvas(
                        project: p,
                        position: start + time,
                        posterOnly: true,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${(time * 1000).round()} ms',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(),
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  row('LAUNCH', [0, .04, .08, .12, .2, .32, .46], .5),
                  const SizedBox(height: 12),
                  row('CLOSE', [
                    0,
                    .03,
                    .06,
                    .09,
                    .15,
                    .24,
                    .36,
                  ], p.feed.introDuration + 1),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => precacheImage(
        FileImage(File(p.clips.first.path)),
        tester.element(find.byType(Scaffold)),
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
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '/tmp/mockareel-window-motion.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
      } finally {
        image.dispose();
      }
    });
    await tester.pumpWidget(const SizedBox());
  });
}
