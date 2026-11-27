import 'dart:math';
import '../model/m3_motion.dart';
import '../model/project.dart';
import '../model/streetview_timeline.dart';

/// Reuse static PNGs on map holds at 60 fps while preserving full frame-by-frame
/// capture during tap ripples, container transforms, arrow rushes, and 3D dives.
abstract final class StreetviewCapturePlan {
  static ({
    double lastFrame,
    double flightStart,
    double entryTap,
    double holdEnd,
  })
  orbitMapTiming(double duration) {
    final lastFrame = max(
      0.0,
      ((duration * M3Motion.exportFps).ceil() - 1) / M3Motion.exportFps,
    );
    final flightStart = max(0.0, lastFrame - min(.85, lastFrame * .62));
    final entryTap = min(StreetviewTimeline.rippleSeconds, flightStart);
    final holdEnd = max(0.0, flightStart - entryTap);
    return (
      lastFrame: lastFrame,
      flightStart: flightStart,
      entryTap: entryTap,
      holdEnd: holdEnd,
    );
  }

  static String key(ReelProject p, StreetviewScene scene, int frame) {
    final elapsed = frame / M3Motion.exportFps;
    switch (scene.kind) {
      case 'ending-map':
        return 'static';
      case 'map':
        if (p.isStreetview3d) {
          if (elapsed <= orbitMapTiming(scene.duration).holdEnd + 1e-9) {
            return 'hold';
          }
        } else if (elapsed <
            scene.duration - StreetviewTimeline.rippleSeconds) {
          return 'hold';
        }
    }
    return 'frame-$frame';
  }
}
