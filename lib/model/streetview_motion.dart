import 'dart:math';
import 'project.dart';

/// Camera coordinates are logical 360×640 pixels. The Android texture renderer
/// uses the same homography in normalized GL coordinates.
class StreetviewPose {
  final double scale, yaw, offsetX;
  const StreetviewPose(this.scale, this.yaw, this.offsetX);
  static const perspective = .0014;
  Point<double> project(double x, double y) {
    final centeredX = x - 180, centeredY = y - 320;
    final w = 1 - perspective * sin(yaw) * centeredX;
    return Point(
      180 + offsetX + scale * cos(yaw) * centeredX / w,
      320 + scale * centeredY / w,
    );
  }
}

abstract final class StreetviewMotion {
  static bool active(ReelClip c) =>
      (c.streetview.slowZoom && c.streetview.zoomAmount != 0) ||
      (c.streetview.slowPan && c.streetview.panAmount != 0) ||
      (c.streetview.turntable && c.streetview.turntableDegrees != 0);
  static double sample(double time, double duration) =>
      min(max(0, (time * 30).round()), max(0, (duration * 30).ceil() - 1)) / 30;
  static StreetviewPose at(ReelClip c, double seconds) {
    final s = c.streetview;
    final t = (sample(seconds, c.duration) / max(.001, c.duration)).clamp(
      0.0,
      1.0,
    );
    final yaw = s.turntable ? s.turntableDegrees * pi / 180 * t : 0.0;
    final offsetX = s.slowPan ? -s.panAmount * 360 * t : 0.0;
    final cover =
        (1 + (StreetviewPose.perspective * 180 * sin(yaw)).abs()) /
        cos(yaw).abs();
    final scale =
        (1 + (s.slowZoom ? s.zoomAmount * t : 0)) *
        cover *
        (1 + 2 * offsetX.abs() / 360);
    return StreetviewPose(scale, yaw, offsetX);
  }

  static Map<String, dynamic> native(ReelClip c) => {
    'zoom': c.streetview.slowZoom ? c.streetview.zoomAmount : 0.0,
    'pan': c.streetview.slowPan ? c.streetview.panAmount : 0.0,
    'turn': c.streetview.turntable ? c.streetview.turntableDegrees : 0.0,
  };
}
