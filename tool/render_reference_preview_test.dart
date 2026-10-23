// Optional visual review using crops of the user-supplied screen recording.
// MOCKAREEL_REFERENCE_VIDEO=/path/reference.mp4 flutter test tool/render_reference_preview_test.dart
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockareel/model/project.dart';
import 'package:mockareel/widgets/reel_preview.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'render the reference layout and left-scroll motion for visual review',
    (tester) async {
      final video =
          Platform.environment['MOCKAREEL_REFERENCE_VIDEO'] ??
          '/workspace/mockareel-reference.mp4';
      final destination =
          Platform.environment['MOCKAREEL_REFERENCE_OUTPUT'] ??
          '/tmp/mockareel-reference-preview';
      final out = Directory(destination);
      final sources = <String>[];
      await tester.runAsync(() async {
        await out.create(recursive: true);
        for (final entry in [
          (4, '230:300:85:860'),
          (2, '150:300:360:860'),
          (0, '240:300:85:860'),
          (0, '150:300:360:860'),
        ]) {
          final path = '${out.path}/source-${sources.length}.png';
          final r = await Process.run('ffmpeg', [
            '-hide_banner',
            '-loglevel',
            'error',
            '-ss',
            '${entry.$1}',
            '-i',
            video,
            '-vf',
            'crop=${entry.$2}',
            '-frames:v',
            '1',
            '-y',
            path,
          ]);
          if (r.exitCode != 0) {
            throw StateError('Reference crop failed: ${r.stderr}');
          }
          sources.add(path);
        }
        final sdk = Platform.environment['FLUTTER_ROOT'];
        if (sdk != null) {
          for (final font in [
            ('Roboto', 'Roboto-Regular.ttf'),
            ('MaterialIcons', 'MaterialIcons-Regular.otf'),
          ]) {
            final loader = FontLoader(font.$1);
            loader.addFont(
              File(
                '$sdk/bin/cache/artifacts/material_fonts/${font.$2}',
              ).readAsBytes().then(ByteData.sublistView),
            );
            await loader.load();
          }
        }
      });
      final p = ReelProject(
        storyBadge: 'ig story idea :',
        storyChrome: true,
        slideSeconds: .35,
        place: PlaceDetails(
          name: 'Kura Sushi Nishishinjuku',
          localName: 'Kura Sushi · Nishishinjuku',
          rating: '3.9',
          reviewCount: '2,186',
          category: 'Conveyor belt sushi restaurant',
          price: '¥1,000–2,000',
          hours: 'Open · Closes 00:00',
        ),
        clips: List.generate(
          5,
          (i) => ReelClip(
            id: '$i',
            path: sources[i % sources.length],
            name: 'Card ${i + 1}',
            isVideo: false,
            duration: 1.56,
            cardWidth: i == 1 ? .92 : .62,
            cardHeight: i == 2 ? .94 : 1,
          ),
        ),
      );
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        await tester.pumpWidget(MaterialApp(home: Container()));
        final context = tester.element(find.byType(Container).first);
        for (final path in sources) {
          await precacheImage(FileImage(File(path)), context);
        }
      });
      for (var i = 0; i < 94; i++) {
        final key = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: RepaintBoundary(
                key: key,
                child: ReelCanvas(
                  project: p,
                  position: i / 12,
                  posterOnly: true,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final image =
              await (key.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          await File(
            '${out.path}/frame-${i.toString().padLeft(3, '0')}.png',
          ).writeAsBytes(png!.buffer.asUint8List());
        });
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
