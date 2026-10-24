import '../model/app_window_motion.dart';
import 'package:flutter/widgets.dart';
import '../model/project.dart';
import '../model/feed_timeline.dart';

/// Identical UI samples share a PNG while the scene still retains every 30 fps
/// slot. Loading dots and transitions are always sampled independently.
abstract final class FeedCapturePlan {
  static String key(ReelProject p, FeedScene scene, int frame) {
    final elapsed = frame / 30;
    switch (scene.kind) {
      case 'search':
        if (elapsed < p.feed.typingSeconds) {
          final count =
              (p.feed.search.characters.length * elapsed / p.feed.typingSeconds)
                  .floor();
          return 'typing-$count';
        }
      case 'home-open':
        if (elapsed <= p.feed.homeSeconds) return 'hold';
      case 'home-close':
        if (elapsed >= AppWindowMotion.closeSeconds) return 'hold';
    }
    return 'frame-$frame';
  }
}
