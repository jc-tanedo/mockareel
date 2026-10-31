import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockareel/model/project.dart';
import 'package:mockareel/services/media_edits.dart';
import 'package:mockareel/services/gif_videos.dart';
import 'support/gif_fixture.dart';
import 'package:mockareel/services/project_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late File original;
  late EditedMedia processor;
  final calls = <Map>[];
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('source-edits-test');
    original = await File('${dir.path}/original.jpg').writeAsBytes([1, 2, 3]);
    processor = EditedMedia(root: Directory('${dir.path}/cache'));
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(EditedMedia.channel, (call) async {
          if (call.method == 'cancelMediaEdits') return null;
          final args = call.arguments as Map;
          calls.add(args);
          await File(args['output'] as String).writeAsBytes([4, 5, 6]);
          return args['output'];
        });
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(EditedMedia.channel, null);
    await dir.delete(recursive: true);
  });
  ReelClip clip({bool video = false}) => ReelClip(
    id: 'source',
    path: original.path,
    name: 'Source',
    isVideo: video,
    sourceDuration: video ? 10 : 0,
    duration: 2,
    trimStart: video ? 1.5 : 0,
    zoom: 1.4,
    panX: .3,
    edits: MediaEdits(
      fisheye: true,
      strength: .6,
      spots: [BlurSpot(x: .3, y: .4)],
    ),
  );

  test(
    'edits produce shared source assets, retaining originals and template framing',
    () async {
      final c = clip();
      final results = await Future.wait([
        processor.prepare(c),
        processor.prepare(c),
      ]);
      expect(c.path, original.path);
      expect(c.edits.active, true);
      expect(await original.readAsBytes(), [1, 2, 3]);
      expect(results.first.path, results.last.path);
      expect(
        results.first.edits.active,
        false,
        reason: 'Baked source edits must not run a second time',
      );
      expect(results.first.zoom, 1.4);
      expect(results.first.panX, .3);
      expect(calls.length, 1);
      expect((calls.single['edits'] as Map)['strength'], .6);
      expect(await File(results.first.path).readAsBytes(), [4, 5, 6]);
      await processor.prepare(c);
      expect(
        calls.length,
        1,
        reason: 'Players, posters and export share the cached source',
      );
    },
  );
  test(
    'edited videos trim once and keep their complete selected duration',
    () async {
      final result = await processor.prepare(clip(video: true));
      expect(calls.single['isVideo'], true);
      expect(calls.single['trimStart'], 1.5);
      expect(calls.single['duration'], 2);
      expect(result.isVideo, true);
      expect(result.trimStart, 0);
      expect(result.duration, 2);
      expect(result.sourceDuration, 2);
    },
  );
  test(
    'GIF edits process the selected looping segment once and retain motion',
    () async {
      final gif = await File(
        '${dir.path}/source.gif',
      ).writeAsBytes(timedGifFixture);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(GifVideos.channel, (call) async {
            final args = call.arguments as Map;
            await File(args['output'] as String).writeAsBytes([1, 2, 3]);
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(GifVideos.channel, null),
      );
      final c = ReelClip(
        id: 'gif',
        path: gif.path,
        name: 'GIF',
        isVideo: false,
        isGif: true,
        sourceDuration: .6,
        trimStart: .1,
        duration: 1.2,
        edits: MediaEdits(spots: [BlurSpot()]),
      );
      final result = await processor.prepare(c);
      expect(calls.single['path'], isNot(gif.path));
      expect(calls.single['path'], endsWith('.mp4'));
      expect(calls.single['isVideo'], true);
      expect(calls.single['trimStart'], 0);
      expect(calls.single['duration'], 1.2);
      expect(result.isVideo, true);
      expect(result.isGif, false);
      expect(result.duration, 1.2);
      expect(result.trimStart, 0);
    },
  );
  test('rapid slider updates skip obsolete edits before encoding', () async {
    final c = clip();
    final first = processor.prepare(c);
    final obsolete = expectLater(first, throwsA(isA<PlatformException>()));
    c.edits.strength = .9;
    final result = await processor.prepare(c);
    await obsolete;
    expect(calls.length, 1);
    expect((calls.single['edits'] as Map)['strength'], .9);
    expect(result.edits.active, false);
  });
  test('cancellation clears incomplete media and permits retry', () async {
    final gate = Completer<String>();
    final started = Completer<void>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(EditedMedia.channel, (call) async {
          if (call.method == 'processMedia') {
            started.complete();
            return gate.future;
          }
          gate.completeError(PlatformException(code: 'CANCELLED'));
          return null;
        });
    final pending = processor.prepare(clip());
    final rejected = expectLater(pending, throwsA(isA<PlatformException>()));
    await started.future;
    await processor.cancel();
    await rejected;
    expect(await Directory('${dir.path}/cache').list().length, 0);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(EditedMedia.channel, (call) async {
          final args = call.arguments as Map;
          await File(args['output'] as String).writeAsBytes([7]);
          return args['output'];
        });
    expect(await File((await processor.prepare(clip())).path).readAsBytes(), [
      7,
    ]);
  });
  test(
    'portable backups preserve the recipe rather than temporary edited paths',
    () async {
      SharedPreferences.setMockInitialValues({});
      final c = clip();
      c.streetview.locationSelected = true;
      final p = ReelProject(template: 'streetview', clips: [c]);
      final store = ProjectStore(root: Directory('${dir.path}/projects'));
      await store.initialize();
      await processor.prepare(c);
      final restored = await store.importBackup(await store.backup(p));
      final saved = restored.clips.single;
      expect(saved.edits.fisheye, true);
      expect(saved.edits.strength, .6);
      expect(saved.edits.spots.single.x, .3);
      expect(saved.edits.spots.single.y, .4);
      expect(saved.streetview.canCaptureMap, true);
      expect(await File(saved.path).readAsBytes(), [1, 2, 3]);
      expect(saved.path, isNot(contains('source-edits-v1')));
    },
  );
  test(
    'old media remains untouched and imported effect values are bounded',
    () async {
      final c = clip()..edits = MediaEdits();
      expect(await processor.prepare(c), same(c));
      expect(calls, isEmpty);
      final edits = MediaEdits.fromJson({
        'fisheye': true,
        'strength': double.nan,
        'spots': List.generate(
          20,
          (_) => {'x': -9, 'y': double.infinity, 'radius': 9},
        ),
      });
      expect(edits.strength, .35);
      expect(edits.spots.length, 8);
      expect(edits.spots.first.x, 0);
      expect(edits.spots.first.y, .5);
      expect(edits.spots.first.radius, .3);
    },
  );
}
