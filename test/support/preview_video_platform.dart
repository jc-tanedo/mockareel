import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

class PreviewVideoPlatform extends VideoPlayerPlatform {
  int created = 0;
  final disposed = <int>[];
  final events = <int, StreamController<VideoEvent>>{};
  final positions = <int, Duration>{};
  final nativePlaying = <int, bool>{};
  final commands = <String>[];
  Future<void> Function()? playBarrier;
  @override
  Future<void> init() async {}
  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async =>
      ++created;
  @override
  Stream<VideoEvent> videoEventsFor(int id) {
    final controller = events[id] = StreamController<VideoEvent>();
    controller.add(
      VideoEvent(
        eventType: VideoEventType.initialized,
        duration: const Duration(seconds: 30),
        size: const Size(1080, 1920),
      ),
    );
    return controller.stream;
  }

  @override
  Future<void> dispose(int id) async {
    disposed.add(id);
    unawaited(events.remove(id)?.close());
  }

  @override
  Future<void> setMixWithOthers(bool value) async {}
  @override
  Future<void> setLooping(int id, bool value) async {}
  @override
  Future<void> setVolume(int id, double value) async {}
  @override
  Future<void> setPlaybackSpeed(int id, double value) async {}
  @override
  Future<void> seekTo(int id, Duration position) async {
    commands.add('seek:$id:${position.inMilliseconds}');
    positions[id] = position;
  }

  @override
  Future<Duration> getPosition(int id) async => positions[id] ?? Duration.zero;
  @override
  Future<void> play(int id) async {
    commands.add('play:$id');
    await playBarrier?.call();
    nativePlaying[id] = true;
  }

  @override
  Future<void> pause(int id) async {
    commands.add('pause:$id');
    nativePlaying[id] = false;
  }

  @override
  Widget buildViewWithOptions(VideoViewOptions options) => const SizedBox();
}
