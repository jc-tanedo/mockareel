import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockareel/model/app_window_motion.dart';
import 'package:mockareel/model/feed.dart';
import 'package:mockareel/model/m3_motion.dart';
import 'package:mockareel/model/project.dart';
import 'package:mockareel/pages/feed_editor_page.dart';
import 'package:mockareel/services/native_renderer.dart';
import 'package:mockareel/services/project_store.dart';
import 'package:mockareel/widgets/reel_preview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import '../../support/preview_video_platform.dart';

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
              await File(frames[0][30] as String).readAsBytes(),
            );
            checks['search handoff retained'] =
                (args['clips'] as List)[1]['searchEnterDuration'] == 0.175 &&
                (frames[1] as List).length == 11;
            checks['active texture exposed'] =
                await alpha(overlays[1] as String, 540, 800) == 0;
            checks['outgoing poster visible'] =
                await alpha(frames[2][0] as String, 540, 800) == 255;
            checks['incoming texture exposed'] =
                await alpha(frames[2][3] as String, 540, 800) == 0;
            checks['closing animated'] =
                (frames[3] as List).length ==
                (p.feed.outroDuration * M3Motion.exportFps).ceil();
            checks['typing samples reused'] = frames[0][0] == frames[0][1];
            checks['home hold reused'] =
                frames[3][(AppWindowMotion.closeSeconds * M3Motion.exportFps)
                    .ceil()] ==
                (frames[3] as List).last;
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
      for (var i = 0; i < 3000 && request == null; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
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

  testWidgets(
    'video home launch and close keep transparent window cutouts and audio mix settings',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final previousVideoPlatform = VideoPlayerPlatform.instance;
      VideoPlayerPlatform.instance = PreviewVideoPlatform();
      addTearDown(() => VideoPlayerPlatform.instance = previousVideoPlatform);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      late Directory dir;
      late ProjectStore store;
      late File photo;
      late ReelProject p;
      await tester.runAsync(() async {
        dir = await Directory.systemTemp.createTemp('feed-video-export-');
        store = ProjectStore(root: dir);
        await store.initialize();
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawColor(const Color(0xff30ba80), BlendMode.src);
        final image = await recorder.endRecording().toImage(100, 100);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        photo = File('${dir.path}/video.mp4');
        await photo.writeAsBytes(png!.buffer.asUint8List());
        final song = File('${dir.path}/song.mp3');
        await song.writeAsBytes([1, 2, 3, 4]);
        p = ReelProject(
          template: 'tiktok-feed',
          clipAudioVolume: .6,
          music: MusicTrack(
            path: song.path,
            name: 'Track',
            sourceDuration: 15,
            fadeOutSeconds: 1.5,
          ),
          feed: FeedSettings(
            opening: 'home',
            homeSeconds: .2,
            closeToHome: true,
          ),
          clips: [
            ReelClip(
              id: 'v0',
              path: photo.path,
              name: 'Video 0',
              isVideo: true,
              sourceDuration: 4,
              duration: 1,
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
          if (call.method == 'thumbnail') return photo.path;
          if (call.method != 'export') {
            throw PlatformException(code: 'UNEXPECTED', message: call.method);
          }
          try {
            final args = call.arguments as Map;
            final frames = args['sceneFrames'] as List;
            final clips = args['clips'] as List;
            checks['clip audio volume forwarded'] =
                (args['clipAudioVolume'] as num).toDouble() == .6;
            checks['music fade-out forwarded'] =
                ((args['music'] as Map)['fadeOutSeconds'] as num).toDouble() ==
                1.5;
            checks['home-open carries live video without audio'] =
                clips.first['isVideo'] == true &&
                clips.first['keepAudio'] == false &&
                clips.first['windowMotion'] is Map;
            checks['home-close carries live video without audio'] =
                clips.last['isVideo'] == true &&
                clips.last['keepAudio'] == false &&
                clips.last['windowMotion'] is Map;
            checks['home-open hold opaque then opens transparent window'] =
                await alpha(frames.first.first as String, 540, 800) == 255 &&
                await alpha(frames.first.last as String, 540, 800) == 0;
            checks['home-close starts transparent window then rests opaque'] =
                await alpha(frames.last.first as String, 540, 800) == 0 &&
                await alpha(frames.last.last as String, 540, 800) == 255;
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
      await tester.tap(find.text('Render MP4'));
      await tester.pump();
      for (var i = 0; i < 3000 && request == null; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
      }
      expect(captureError, isNull);
      expect(
        request,
        isNotNull,
        reason: 'Export must reach the native encoder',
      );
      expect(checks.values, everyElement(true), reason: checks.toString());
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
