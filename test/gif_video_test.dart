import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockareel/model/gif_info.dart';
import 'package:mockareel/model/project.dart';
import 'package:mockareel/services/gif_media.dart';
import 'package:mockareel/services/gif_videos.dart';
import 'package:mockareel/services/project_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/gif_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('GIF timing, trimmed boundaries, looping and project round trip', () {
    final info = GifInfo.parse(timedGifFixture);
    expect(info.delaysMs, [100, 200, 300]);
    expect(info.duration, .6);
    expect(info.samples(.12, .3, false), [1, 1, 1, 1, 1, 1, 2, 2, 2]);
    expect(info.samples(.55, .3, true), [2, 2, 0, 0, 0, 1, 1, 1, 1]);
    final c = ReelClip(
      id: 'gif',
      path: 'gif',
      name: 'gif',
      isVideo: false,
      isGif: true,
      sourceDuration: .6,
      trimStart: .55,
      duration: 3,
    );
    expect(c.maxDuration, 30);
    expect(c.trimStart, .55);
    final copy = ReelClip.fromJson(c.toJson());
    expect(copy.isGif, isTrue);
    expect(copy.loopGif, isTrue);
    expect(copy.trimStart, .55);
    copy.loopGif = false;
    copy.normalize();
    expect(copy.duration, .6);
    expect(copy.trimStart, 0);
    c.setGifLoop(false);
    expect(c.trimStart, closeTo(.55, .0001));
    expect(c.duration, closeTo(.05, .0001));
    expect(
      () => GifInfo.parse(timedGifFixture.sublist(0, 15)),
      throwsFormatException,
    );
  });
  testWidgets(
    'only selected GIF frames reach encoding; cache avoids repeated decoding',
    (tester) async {
      await tester.runAsync(() async {
        final dir = await Directory.systemTemp.createTemp('gif-segment-test-');
        final source = File('${dir.path}/image.jpg');
        await source.writeAsBytes(timedGifFixture);
        final clip = ReelClip(
          id: 'gif',
          path: source.path,
          name: 'GIF',
          isVideo: false,
          duration: .3,
        );
        await GifMedia.hydrate(clip);
        clip.duration = .3;
        clip.loopGif = false;
        clip.trimStart = .12;
        clip.normalize();
        final service = GifVideos(root: Directory('${dir.path}/cache'));
        var calls = 0;
        String? scratch;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          GifVideos.channel,
          (call) async {
            if (call.method == 'cancel') return null;
            calls++;
            final args = call.arguments as Map;
            final frames = args['frames'] as List;
            expect(args['duration'], .3);
            expect(frames.map((f) => f['timeUs']), [0, 200000]);
            expect(frames.map((f) => (f['path'] as String).split('/').last), [
              '1.png',
              '2.png',
            ]);
            scratch = File(args['base'] as String).parent.path;
            for (var i = 0; i < frames.length; i++) {
              final codec = await ui.instantiateImageCodec(
                await File(frames[i]['path'] as String).readAsBytes(),
              );
              final frame = await codec.getNextFrame();
              final pixel = (await frame.image.toByteData())!.buffer
                  .asUint8List()
                  .take(4);
              expect(pixel, i == 0 ? [0, 0, 255, 255] : [0, 255, 0, 255]);
              frame.image.dispose();
              codec.dispose();
            }
            await File(
              args['output'] as String,
            ).writeAsBytes([0, 0, 0, 20, 102, 116, 121, 112]);
            return null;
          },
        );
        try {
          final first = await service.video(clip);
          expect(await File(first).exists(), isTrue);
          expect(await Directory(scratch!).exists(), isFalse);
          expect(await service.video(clip), first);
          expect(calls, 1);
          clip.trimStart = .2;
          // A changed timing window must prepare a different cached clip.
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            GifVideos.channel,
            (call) async {
              calls++;
              final args = call.arguments as Map;
              await File(args['output'] as String).writeAsBytes([1, 2, 3]);
              return null;
            },
          );
          expect(await service.video(clip), isNot(first));
          expect(calls, 2);
          expect(await source.readAsBytes(), orderedEquals(timedGifFixture));
        } finally {
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            GifVideos.channel,
            null,
          );
          await dir.delete(recursive: true);
        }
      });
    },
  );
  testWidgets(
    'failed GIF preparations remove partial videos and frame scratch',
    (tester) async {
      await tester.runAsync(() async {
        final dir = await Directory.systemTemp.createTemp('gif-failure-test-');
        final file = File('${dir.path}/image.gif');
        await file.writeAsBytes(timedGifFixture);
        final service = GifVideos(root: Directory('${dir.path}/cache'));
        final clip = ReelClip(
          id: 'gif',
          path: file.path,
          name: 'GIF',
          isVideo: false,
          duration: .2,
        );
        String? scratch, output;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          GifVideos.channel,
          (call) async {
            final args = call.arguments as Map;
            output = args['output'] as String;
            scratch = File(args['base'] as String).parent.path;
            await File(output!).writeAsBytes([1]);
            throw PlatformException(code: 'TEST_FAILURE');
          },
        );
        try {
          await expectLater(
            service.video(clip),
            throwsA(isA<PlatformException>()),
          );
          expect(await File(output!).exists(), isFalse);
          expect(await Directory(scratch!).exists(), isFalse);
        } finally {
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            GifVideos.channel,
            null,
          );
          await dir.delete(recursive: true);
        }
      });
    },
  );
  testWidgets(
    'cancelling an active GIF encode cleans its partial video and frames',
    (tester) async {
      await tester.runAsync(() async {
        final dir = await Directory.systemTemp.createTemp('gif-cancel-test-');
        final source = File('${dir.path}/source.gif');
        await source.writeAsBytes(timedGifFixture);
        final service = GifVideos(root: Directory('${dir.path}/cache'));
        final started = Completer<void>(), pending = Completer<void>();
        String? output, scratch;
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          GifVideos.channel,
          (call) async {
            if (call.method == 'cancel') {
              pending.completeError(PlatformException(code: 'CANCELLED'));
              return null;
            }
            final args = call.arguments as Map;
            output = args['output'] as String;
            scratch = File(args['base'] as String).parent.path;
            await File(output!).writeAsBytes([1]);
            started.complete();
            await pending.future;
            return null;
          },
        );
        try {
          final result = expectLater(
            service.video(
              ReelClip(
                id: 'gif',
                path: source.path,
                name: 'GIF',
                isVideo: false,
              ),
            ),
            throwsA(isA<PlatformException>()),
          );
          await started.future;
          await service.cancel();
          await result;
          expect(await File(output!).exists(), isFalse);
          expect(await Directory(scratch!).exists(), isFalse);
        } finally {
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            GifVideos.channel,
            null,
          );
          await dir.delete(recursive: true);
        }
      });
    },
  );
  testWidgets(
    'existing GIF photos are detected on restore and retain timing through backups',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.runAsync(() async {
        final dir = await Directory.systemTemp.createTemp('gif-project-test-');
        final store = ProjectStore(root: dir);
        await store.initialize();
        final source = File('${dir.path}/media/old-photo.jpg');
        await source.writeAsBytes(timedGifFixture);
        final project = ReelProject(
          clips: [
            ReelClip(
              id: 'legacy',
              path: source.path,
              name: 'Old photo.jpg',
              isVideo: false,
            ),
          ],
        );
        try {
          await store.save(project);
          final restored = (await store.projects()).single;
          final gif = restored.clips.single;
          expect(gif.isGif, isTrue);
          expect(gif.sourceDuration, .6);
          expect(gif.duration, 3.5);
          gif.loopGif = false;
          gif.duration = .3;
          gif.trimStart = .12;
          gif.normalize();
          final archive = await store.backup(restored);
          final imported = await store.importBackup(archive);
          expect(imported.clips.single.isGif, isTrue);
          expect(imported.clips.single.loopGif, isFalse);
          expect(imported.clips.single.trimStart, .12);
          expect(imported.clips.single.duration, .3);
          expect(
            await File(imported.clips.single.path).readAsBytes(),
            orderedEquals(timedGifFixture),
          );
        } finally {
          await dir.delete(recursive: true);
        }
      });
    },
  );
}
