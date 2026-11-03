import 'dart:async';
import 'dart:io';
import 'dart:math';
import '../model/feed_timeline.dart';
import '../model/project.dart';
import '../services/feed_capture_plan.dart';
import '../services/native_renderer.dart';
import '../services/project_store.dart';
import '../widgets/export_monitor.dart';

class FeedExportPipeline {
  final ReelProject project;
  final ProjectStore store;
  final NativeRenderer renderer;
  final Future<void> Function(String path) onPrecache;
  final Future<String> Function(
    Directory dir,
    String name,
    double time, {
    bool overlay,
  })
  onCapture;
  final void Function(String status) onStatus;
  final void Function(double? progress) onProgress;
  final void Function(ExportPhase phase) onPhase;
  final void Function(double position) onPosition;
  final void Function(Map<String, String> posters) onPosters;
  final bool Function() isCancelled;

  const FeedExportPipeline({
    required this.project,
    required this.store,
    required this.renderer,
    required this.onPrecache,
    required this.onCapture,
    required this.onStatus,
    required this.onProgress,
    required this.onPhase,
    required this.onPosition,
    required this.onPosters,
    required this.isCancelled,
  });

  Future<String> run() async {
    Directory? temp;
    StreamSubscription<double>? subscription;
    try {
      temp = await Directory(
        '${store.root!.path}/exports/feed_${newId()}',
      ).create();

      final posters = <String, String>{};
      for (final c in [
        ...project.clips,
        if (project.feed.homeMedia != null) project.feed.homeMedia!,
      ]) {
        if (isCancelled()) throw const FormatException('Export cancelled');
        if (!await File(c.path).exists()) {
          throw FormatException('“${c.name}” is missing. Replace this media.');
        }
        for (final end in [false, true]) {
          final path = await renderer.poster(
            c,
            position: end ? c.duration - .001 : 0,
          );
          posters['${c.id}:${end ? 'end' : 'start'}'] = path;
          await onPrecache(path);
        }
      }

      for (final c in project.clips) {
        if (c.post.avatarPath != null) await onPrecache(c.post.avatarPath!);
      }

      onPosters(posters);

      final clips = <Map<String, dynamic>>[],
          overlays = <String>[],
          frames = <List<String>>[],
          transitions = <double>[];
      final scenes = FeedTimeline.scenes(project);
      final totalFrames = scenes.fold<int>(0, (sum, scene) {
        final animated = scene.kind == 'post'
            ? FeedTimeline.transition(project, scene.postIndex)
            : scene.duration;
        return sum + (animated * 30).ceil() + 1;
      });

      var completedFrames = 0;
      for (var i = 0; i < scenes.length; i++) {
        final s = scenes[i];
        final isPost = s.kind == 'post';
        onStatus('Preparing scene ${i + 1} of ${scenes.length}…');
        final transition = isPost
            ? FeedTimeline.transition(project, s.postIndex)
            : 0.0;
        final animated = isPost ? transition : s.duration;
        final sceneFrames = <String>[];
        final cached = <String, String>{};

        for (var frame = 0; frame < (animated * 30).ceil(); frame++) {
          if (isCancelled()) throw const FormatException('Export cancelled');
          final key = FeedCapturePlan.key(project, s, frame);
          final path = cached[key] ??= await onCapture(
            temp,
            'scene_${i}_$frame',
            s.start + frame / 30,
            overlay: true,
          );
          sceneFrames.add(path);
          completedFrames++;
          onProgress(completedFrames / totalFrames * .35);
        }

        final overlay = await onCapture(
          temp,
          'overlay_$i',
          s.start + min(s.duration - .001, animated + .001),
          overlay: true,
        );
        completedFrames++;
        overlays.add(overlay);
        frames.add(sceneFrames);
        transitions.add(transition);

        ReelClip? source = isPost
            ? project.clips[s.postIndex]
            : s.kind.startsWith('home')
            ? project.feed.homeMedia
            : null;

        if (source == null) {
          final base = await onCapture(temp, 'base_$i', s.start);
          clips.add(
            ReelClip(
              id: newId(),
              path: base,
              name: 'Scene',
              isVideo: false,
              duration: s.duration,
            ).toJson(),
          );
        } else {
          clips.add({
            ...source.toJson(),
            'duration': s.duration,
            'loopSource': !isPost && source.isTimed,
            'loopDuration': source.duration,
          });
        }
      }

      if (isCancelled()) throw const FormatException('Export cancelled');

      onPhase(ExportPhase.encoding);
      onStatus('Encoding video…');
      onProgress(.35);
      onPosition(0);

      subscription = renderer.progress.listen((value) {
        onStatus('Encoding video…');
        onPosition(FeedTimeline.duration(project) * value.clamp(0, 1));
        onProgress(.35 + .65 * value);
      });

      final path = await renderer.exportFeed(
        clips: clips,
        overlays: overlays,
        frames: frames,
        transitions: transitions,
        music: project.music,
      );

      if (isCancelled()) throw const FormatException('Export cancelled');
      return path;
    } finally {
      await subscription?.cancel();
      if (temp != null && await temp.exists()) {
        await temp.delete(recursive: true);
      }
    }
  }
}
