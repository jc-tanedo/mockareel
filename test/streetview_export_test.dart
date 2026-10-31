import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'support/preview_video_platform.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockareel/model/project.dart';
import 'package:mockareel/pages/maps_editor_page.dart';
import 'package:mockareel/widgets/reel_preview.dart';
import 'package:mockareel/services/native_renderer.dart';
import 'package:mockareel/services/project_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'Streetview MP4 preserves timeline boundaries, video textures and animated transitions',
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
      late ReelProject p;
      await tester.runAsync(() async {
        dir = await Directory.systemTemp.createTemp('streetview-export-');
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
          template: 'streetview',
          streetview: StreetviewSettings(
            openingMapSeconds: .5,
            laterMapSeconds: .5,
            endOnMap: true,
          ),
          clips: [
            for (var i = 0; i < 2; i++)
              ReelClip(
                id: '$i',
                path: photo.path,
                name: 'Media $i',
                isVideo: i == 1,
                sourceDuration: 3,
                duration: .5,
                streetview: StreetviewMedia(
                  place: PlaceDetails(name: 'Place $i', address: 'Address $i'),
                  mapPath: photo.path,
                  panZoom: i == 1,
                  transitionSeconds: .25,
                ),
              ),
          ],
        );
      });
      p.clips[1].edits = MediaEdits(
        fisheye: true,
        strength: .5,
        spots: [BlurSpot()],
      );
      final effectInputs = <Map>[];
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
          if (call.method == 'thumbnail') return p.clips.first.path;
          if (call.method == 'processMedia') {
            final args = call.arguments as Map;
            effectInputs.add(args);
            await File(args['output'] as String).writeAsBytes([1, 2, 3]);
            return args['output'];
          }
          if (call.method != 'export') {
            throw PlatformException(code: 'UNEXPECTED', message: call.method);
          }
          try {
            final args = call.arguments as Map;
            final frames = args['sceneFrames'] as List;
            final overlays = args['overlays'] as List;
            checks['opening map animated'] = (frames[0] as List).length == 15;
            checks['active texture exposed'] =
                await alpha(overlays[1] as String, 540, 800) == 0;
            checks['movement composited'] =
                await alpha(frames[2][4] as String, 540, 800) == 255;
            checks['ending map animated'] = (frames[5] as List).length == 15;
            final clips = args['clips'] as List;
            checks['video retained'] = clips[3]['isVideo'] == true;
            checks['edited source retained'] = (clips[3]['path'] as String)
                .contains('source-edits-v1');
            checks['UI is never source-processed'] =
                effectInputs.length == 1 &&
                effectInputs.single['path'] == p.clips[1].path;
            checks['pan zoom retained'] = clips[3]['slowPanZoom'] == true;
            checks['timeline duration'] =
                ((clips.fold<double>(
                          0,
                          (n, c) => n + (c['duration'] as num).toDouble(),
                        )) -
                        p.duration)
                    .abs() <
                .000001;
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
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            home: MapsEditorPage(store: store, initialProject: p),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      Future<void> settleMedia() async {
        for (var i = 0; i < 40; i++) {
          await tester.pump(const Duration(milliseconds: 30));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
        }
        await tester.pumpAndSettle();
      }

      await settleMedia();
      await tester.tap(find.text('Export').last);
      await settleMedia();
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
      expect((request!['clips'] as List).length, 6);
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
      await settleMedia();
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
