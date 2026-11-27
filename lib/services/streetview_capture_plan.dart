import '../model/m3_motion.dart';
import '../model/project.dart';
import '../model/streetview_timeline.dart';

/// Reuse static PNGs on map holds at 60 fps while preserving full frame-by-frame
/// capture during tap ripples, container transforms, and arrow rushes.
abstract final class StreetviewCapturePlan {
  static String key(ReelProject p, StreetviewScene scene, int frame) {
    final elapsed = frame / M3Motion.exportFps;
    switch (scene.kind) {
      case 'ending-map':
        return 'static';
      case 'map':
        if (elapsed < scene.duration - StreetviewTimeline.rippleSeconds) {
          return 'hold';
        }
    }
    return 'frame-$frame';
  }
}
