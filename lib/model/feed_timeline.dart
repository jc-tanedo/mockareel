import 'dart:math';
import 'project.dart';

/// The same scene plan drives scrubbing, playback and native export.
class FeedScene {
  final String kind;
  final int postIndex;
  final double start, duration;
  const FeedScene(this.kind, this.postIndex, this.start, this.duration);
}

abstract final class FeedTimeline {
  static List<FeedScene> scenes(ReelProject p) {
    final result = <FeedScene>[];
    var start = 0.0;
    void add(String kind, int index, double seconds) {
      result.add(FeedScene(kind, index, start, seconds));
      start += seconds;
    }

    if (p.feed.introDuration > 0) {
      add(p.feed.hasSearch ? 'search' : 'home-open', 0, p.feed.introDuration);
    }
    for (var i = 0; i < p.clips.length; i++) {
      add('post', i, p.clips[i].duration);
    }
    if (p.feed.closeToHome) {
      add('home-close', max(0, p.clips.length - 1), p.feed.outroDuration);
    }
    return result;
  }

  static double duration(ReelProject p) =>
      scenes(p).fold(0, (n, s) => n + s.duration);
  static FeedScene at(ReelProject p, double time) {
    final all = scenes(p);
    return all.firstWhere(
      (s) => time < s.start + s.duration,
      orElse: () => all.isEmpty ? const FeedScene('post', 0, 0, 0) : all.last,
    );
  }

  static double postStart(ReelProject p, int index) =>
      p.feed.introDuration + p.startOf(index);
  static double transition(ReelProject p, int index) =>
      index == 0 ? 0 : min(p.slideSeconds, p.clips[index].duration * .45);
  static double entry(ReelProject p, int index, double elapsed) {
    final d = transition(p, index);
    return d <= 0 ? 0 : 640 * pow(1 - (elapsed / d).clamp(0, 1), 3).toDouble();
  }
}
