import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockareel/model/feed.dart';
import 'package:mockareel/model/project.dart';
import 'package:mockareel/pages/feed_editor_page.dart';
import 'package:mockareel/widgets/reel_preview.dart';
import 'package:mockareel/services/native_renderer.dart';
import 'package:mockareel/services/project_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'real MP4 action captures typed search, swipe masks and closing frames',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      late Directory dir;
      late ProjectStore store;
      late ReelProject p;
      await tester.runAsync(() async {
        dir = await Directory.systemTemp.createTemp('feed-export-');
        store = ProjectStore(root: dir);
        await store.initialize();
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawColor(const Color(0xff30ba80), BlendMode.src);
        final image = await recorder.endRecording().toImage(100, 100);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        final photo = File('${dir.path}/photo.png');
        await photo.writeAsBytes(png!.buffer.asUint8List());
        p = ReelProject(
          template: 'tiktok-feed',
          slideSeconds: .2,
          feed: FeedSettings(
            search: 'hello',
            typingSeconds: .5,
            loadingSeconds: .2,
            homeSeconds: .5,
            closeToHome: true,
          ),
          clips: [
            for (var i = 0; i < 2; i++)
              ReelClip(
                id: '$i',
                path: photo.path,
                name: 'Photo $i',
                isVideo: false,
                duration: .5,
              ),
          ],
        );
      });
      Map? request;
      final checks = <String, bool>{};
      Object? captureError;
      Future<int> alpha(String path, int x, int y) async {
        final codec = await ui.instantiateImageCodec(
          await File(path).readAsBytes(),
        );
        try {
          final frame = await codec.getNextFrame();
          try {
            final bytes = await frame.image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            );
            return bytes!.getUint8((y * frame.image.width + x) * 4 + 3);
          } finally {
            frame.image.dispose();
          }
        } finally {
          codec.dispose();
        }
      }

      const progressChannel = MethodChannel('dev.mockareel/render-progress');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        progressChannel,
        (call) async => null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          progressChannel,
          null,
        ),
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        NativeRenderer.channel,
        (call) async {
          if (call.method == 'cancel') return null;
          if (call.method != 'export') {
            throw PlatformException(code: 'UNEXPECTED', message: call.method);
          }
          try {
            final args = call.arguments as Map;
            final frames = args['sceneFrames'] as List;
            final overlays = args['overlays'] as List;
            checks['search changes'] = !listEquals(
              await File(frames[0][0] as String).readAsBytes(),
              await File(frames[0][15] as String).readAsBytes(),
            );
            checks['active texture exposed'] =
                await alpha(overlays[1] as String, 540, 800) == 0;
            checks['outgoing poster visible'] =
                await alpha(frames[2][0] as String, 540, 800) == 255;
            checks['incoming texture exposed'] =
                await alpha(frames[2][3] as String, 540, 800) == 0;
            checks['closing animated'] = (frames[3] as List).length == 35;
            request = args;
          } catch (e) {
            captureError = e;
            request = {};
          }
          throw PlatformException(
            code: 'TEST_COMPLETE',
            message: 'Captured native export request',
          );
        },
      );
      addTearDown(() async {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          NativeRenderer.channel,
          null,
        );
        await dir.delete(recursive: true);
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: FeedEditorPage(store: store, project: p),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Export').last);
      await tester.pumpAndSettle();
      expect(find.byType(TimelinePreview), findsOneWidget);
      await tester.tap(find.text('Render MP4'));
      await tester.pump();
      expect(
        find.byType(TimelinePreview),
        findsNothing,
        reason: 'Release preview video/audio players while encoding',
      );
      for (var i = 0; i < 1600 && request == null; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
      }
      expect(captureError, isNull);
      expect(
        request,
        isNotNull,
        reason: 'Export must reach the native encoder',
      );
      expect(request!['template'], 'tiktok-feed');
      expect((request!['clips'] as List).length, 4);
      expect(checks.values, everyElement(true), reason: checks.toString());
      for (
        var i = 0;
        i < 100 && find.text('Cancel export').evaluate().isNotEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 16));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
      }
      await tester.pumpAndSettle();
      expect(find.text('Cancel export'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
