import 'dart:math';
import 'project.dart';

class MusicSegment {
  final int startMs, endMs, timelineOffsetMs;
  const MusicSegment({
    required this.startMs,
    required this.endMs,
    required this.timelineOffsetMs,
  });
}

/// Shared audio mixing rules for preview players and Media3 export.
abstract final class AudioMix {
  static double clipVolume(ReelProject project, ReelClip clip) =>
      clip.isVideo && !clip.isGif && !clip.muted
      ? project.clipAudioVolume.clamp(0.0, 1.0).toDouble()
      : 0.0;

  static double musicGain({
    required double position,
    required double totalDuration,
    required double volume,
    required double fadeOutSeconds,
  }) {
    final vol = volume.isFinite ? volume.clamp(0.0, 1.0).toDouble() : 0.0;
    final fade = fadeOutSeconds.isFinite
        ? min(
            fadeOutSeconds.clamp(0.0, 5.0).toDouble(),
            max(0.0, totalDuration),
          )
        : 0.0;
    if (fade <= 0 || totalDuration <= 0 || position <= totalDuration - fade) {
      return vol;
    }
    final remaining = ((totalDuration - position) / fade).clamp(0.0, 1.0);
    return vol * 0.5 * (1.0 - cos(remaining * pi));
  }

  static List<MusicSegment> planMusicSegments({
    required int sourceMs,
    required int trimStartMs,
    required int reelMs,
    required bool loop,
  }) {
    if (sourceMs <= 0 || reelMs <= 0) return const [];
    final int maxStart = max(0, sourceMs - 100);
    final int start = trimStartMs.clamp(0, maxStart).toInt();
    final int available = sourceMs - start;
    if (available <= 0) return const [];
    if (!loop || available >= reelMs) {
      return [
        MusicSegment(
          startMs: start,
          endMs: min(sourceMs, start + reelMs),
          timelineOffsetMs: 0,
        ),
      ];
    }
    final segments = <MusicSegment>[];
    var offset = 0;
    while (offset < reelMs) {
      final int length = min(available, reelMs - offset);
      segments.add(
        MusicSegment(
          startMs: start,
          endMs: start + length,
          timelineOffsetMs: offset,
        ),
      );
      offset += length;
    }
    return segments;
  }
}
