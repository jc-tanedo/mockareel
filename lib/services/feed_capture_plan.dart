import '../model/app_window_motion.dart';
import 'package:flutter/widgets.dart';
import '../model/feed_timeline.dart';
import '../model/m3_motion.dart';
import '../model/project.dart';

/// Identical UI samples share a PNG while the scene still retains every 60 fps
/// slot. Loading dots, icon tap ripples, search-exit handoffs and transitions
/// are always sampled independently.
abstract final class FeedCapturePlan {
  static String key(ReelProject p, FeedScene scene, int frame) {
    final elapsed = frame / M3Motion.exportFps;
    switch (scene.kind) {
      case 'search':
        if (elapsed < p.feed.typingSeconds) {
          final count =
              (p.feed.search.characters.length * elapsed / p.feed.typingSeconds)
                  .floor();
          return 'typing-$count';
        }
      case 'home-open':
        final tapStart = p.feed.homeSeconds - AppWindowMotion.iconTapSeconds;
        if (elapsed < tapStart) return 'hold';
      case 'home-close':
        if (elapsed >= AppWindowMotion.closeSeconds) return 'hold';
    }
    return 'frame-$frame';
  }
}
