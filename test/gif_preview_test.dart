import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockareel/model/project.dart';
import 'package:mockareel/widgets/media_frame.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

class GifPreviewPlatform extends VideoPlayerPlatform {
  int created = 0;
  final disposed = <int>[];
  final events = <int, StreamController<VideoEvent>>{};
  final positions = <int, Duration>{};
  @override
  Future<void> init() async {}
  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async =>
      ++created;
  @override
  Stream<VideoEvent> videoEventsFor(int playerId) {
    final controller = events[playerId] = StreamController<VideoEvent>();
    controller.add(
      VideoEvent(
        eventType: VideoEventType.initialized,
        duration: const Duration(seconds: 10),
        size: const Size(1080, 1920),
      ),
    );
    return controller.stream;
  }

  @override
  Future<void> dispose(int playerId) async {
    disposed.add(playerId);
    unawaited(events.remove(playerId)?.close());
  }

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}
  @override
  Future<void> setLooping(int playerId, bool looping) async {}
  @override
  Future<void> setVolume(int playerId, double volume) async {}
  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}
  @override
  Future<void> seekTo(int playerId, Duration position) async {
    positions[playerId] = position;
  }

  @override
  Future<Duration> getPosition(int playerId) async =>
      positions[playerId] ?? Duration.zero;
  @override
  Future<void> play(int playerId) async {}
  @override
  Future<void> pause(int playerId) async {}
  @override
  Widget buildViewWithOptions(VideoViewOptions options) => const SizedBox();
}

void main() {
  testWidgets(
    'GIF preview uses selected segment time and rebuilds only when timing changes',
    (tester) async {
      await tester.runAsync(() async {
        final previous = VideoPlayerPlatform.instance;
        final platform = GifPreviewPlatform();
        VideoPlayerPlatform.instance = platform;
        addTearDown(() => VideoPlayerPlatform.instance = previous);
        final clip = ReelClip(
          id: 'gif',
          path: 'source.gif',
          name: 'GIF',
          isVideo: false,
          isGif: true,
          sourceDuration: .6,
          trimStart: .12,
          duration: .3,
          loopGif: false,
        );
        var preparations = 0;
        Future<String> prepare(ReelClip c) async {
          preparations++;
          return 'segment-${c.trimStart}-${c.duration}.mp4';
        }

        Future<VideoPlayerController> show(double time) async {
          await tester.pumpWidget(
            MaterialApp(
              home: MediaFrame(
                clip: clip,
                position: time,
                gifVideoBuilder: prepare,
              ),
            ),
          );
          await Future<void>.delayed(const Duration(milliseconds: 350));
          await tester.pump();
          await tester.pump();
          return tester
              .widget<VideoPlayer>(find.byType(VideoPlayer))
              .controller;
        }

        final first = await show(.1);
        expect(first.dataSource, contains('segment-0.12-0.3.mp4'));
        expect(first.value.position.inMilliseconds, 100);
        expect(preparations, 1);
        final scrubbed = await show(.2);
        expect(identical(first, scrubbed), isTrue);
        expect(scrubbed.value.position.inMilliseconds, 200);
        expect(preparations, 1);
        clip.trimStart = .2;
        final updated = await show(.05);
        expect(identical(first, updated), isFalse);
        expect(preparations, 2);
        expect(updated.dataSource, contains('segment-0.2-0.3.mp4'));
        expect(updated.value.position.inMilliseconds, 50);
        await tester.pumpWidget(const SizedBox());
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
        expect(platform.disposed.length, 2);
      });
    },
  );
  testWidgets(
    'a GIF discovered after first render replaces uncontrolled image playback',
    (tester) async {
      await tester.runAsync(() async {
        final previous = VideoPlayerPlatform.instance;
        final platform = GifPreviewPlatform();
        VideoPlayerPlatform.instance = platform;
        final clip = ReelClip(
          id: 'legacy',
          path: 'missing.gif',
          name: 'GIF',
          isVideo: false,
          duration: 1,
        );
        Future<String> prepare(ReelClip _) async => 'prepared.mp4';
        Future<void> show() async {
          await tester.pumpWidget(
            MaterialApp(
              home: MediaFrame(clip: clip, gifVideoBuilder: prepare),
            ),
          );
          await Future<void>.delayed(const Duration(milliseconds: 350));
          await tester.pump();
          await tester.pump();
        }

        try {
          await show();
          expect(find.byType(VideoPlayer), findsNothing);
          clip.isGif = true;
          clip.sourceDuration = 1;
          clip.normalize();
          await show();
          expect(find.byType(VideoPlayer), findsOneWidget);
          expect(
            tester
                .widget<VideoPlayer>(find.byType(VideoPlayer))
                .controller
                .value
                .isPlaying,
            isFalse,
          );
        } finally {
          await tester.pumpWidget(const SizedBox());
          await Future<void>.delayed(Duration.zero);
          VideoPlayerPlatform.instance = previous;
        }
      });
    },
  );
}
