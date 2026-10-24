import 'package:mockareel/model/app_window_motion.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockareel/model/feed_timeline.dart';
import 'package:mockareel/model/feed.dart';
import 'package:mockareel/model/project.dart';
import 'package:mockareel/widgets/feed_canvas.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

class _VideoPlatform extends VideoPlayerPlatform {
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
    await events.remove(playerId)?.close();
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
  testWidgets('home launch and app close retain the video player', (
    tester,
  ) async {
    final previous = VideoPlayerPlatform.instance;
    final platform = _VideoPlatform();
    VideoPlayerPlatform.instance = platform;
    addTearDown(() => VideoPlayerPlatform.instance = previous);
    final p = ReelProject(
      template: 'tiktok-feed',
      feed: FeedSettings(opening: 'home', closeToHome: true, homeSeconds: .5),
      clips: [
        ReelClip(
          id: 'video',
          path: 'video.mp4',
          name: 'Video',
          isVideo: true,
          duration: 3,
          sourceDuration: 10,
          trimStart: 1,
        ),
      ],
    );
    Future<VideoPlayerController> show(double time) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FeedCanvas(project: p, position: time, playing: true),
        ),
      );
      await tester.pump();
      await tester.pump();
      return tester
          .widget<VideoPlayer>(find.byType(VideoPlayer, skipOffstage: false))
          .controller;
    }

    final controller = await show(0);
    expect(controller.value.isPlaying, isFalse);
    final start = p.feed.introDuration;
    final end = start + p.clips.single.duration;
    for (final time in [
      p.feed.homeSeconds + .01,
      start - .01,
      start,
      start + 1,
      end - .01,
      end,
      end + .2,
      end + AppWindowMotion.closeSeconds + .01,
    ]) {
      expect(await show(time), same(controller), reason: 'Continuity at $time');
      expect(platform.created, 1);
      expect(controller.value.isPlaying, time >= start && time < end);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    expect(platform.disposed, [1]);
  });
  testWidgets('incoming video keeps its player when outgoing post leaves', (
    tester,
  ) async {
    final previous = VideoPlayerPlatform.instance;
    final platform = _VideoPlatform();
    VideoPlayerPlatform.instance = platform;
    addTearDown(() => VideoPlayerPlatform.instance = previous);
    final p = ReelProject(
      template: 'tiktok-feed',
      clips: [
        for (var i = 0; i < 3; i++)
          ReelClip(
            id: '$i',
            path: 'video-$i.mp4',
            name: 'Video $i',
            isVideo: true,
            sourceDuration: 10,
            duration: 3,
            trimStart: 1,
          ),
      ],
    );
    Future<void> show(double time) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FeedCanvas(project: p, position: time, playing: true),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    for (var i = 1; i < p.clips.length; i++) {
      final start = FeedTimeline.postStart(p, i);
      final duration = FeedTimeline.transition(p, i);
      await show(start + duration / 2);
      final controller = tester
          .widget<VideoPlayer>(find.byType(VideoPlayer))
          .controller;
      final count = platform.created;
      await show(start + duration + .01);
      expect(platform.created, count, reason: 'No decoder restart after swipe');
      expect(
        tester.widget<VideoPlayer>(find.byType(VideoPlayer)).controller,
        same(controller),
      );
      expect(controller.value.isPlaying, isTrue);
      expect(controller.value.position.inMilliseconds, greaterThan(1000));
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await Future<void>.delayed(Duration.zero);
    });
    expect(platform.disposed.length, platform.created);
  });
}
