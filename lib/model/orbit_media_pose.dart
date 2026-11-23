import 'dart:math';
import 'package:flutter/widgets.dart';

/// Orthographic projection of an upright 9:16 media plane. Both Flutter's
/// panel and the Media3 video texture use these coefficients at the same frame.
class OrbitMediaPose {
  final double progress;
  const OrbitMediaPose(this.progress);
  double get zoom => 1 + .74 * progress;
  factory OrbitMediaPose.at(String kind, double t) {
    final u = Curves.easeInOut.transform(t.clamp(0.0, 1.0));
    return switch (kind) {
      'map' => OrbitMediaPose(.35 * u),
      'media' => OrbitMediaPose(.35 + .65 * u),
      'back' => OrbitMediaPose(1 - u),
      'ending-map' => OrbitMediaPose(.35 * u),
      _ => const OrbitMediaPose(1),
    };
  }
  // Angle between the camera and the normal to the mounted media.
  double get yaw => (-13 + 26 * progress) * pi / 180;
  double get sx => .30 * zoom * cos(yaw);
  double get sy => .30 * zoom;
  double get shear => .30 * zoom * sin(yaw) * .64;
  double get left => 180 - 180 * sx;
  double get top => 640 * .54 - 640 * sy - 180 * shear;
  Matrix4 get matrix => Matrix4.identity()
    ..setEntry(0, 0, sx)
    ..setEntry(1, 0, shear)
    ..setEntry(1, 1, sy)
    ..setTranslationRaw(left, top, 0);
  // Media3 coordinates are centered and have an upward Y axis.
  List<double> get native => [
    sx,
    0,
    0,
    -shear * 360 / 640,
    sy,
    1 - 2 * (top + 180 * shear + 320 * sy) / 640,
    0,
    0,
    1,
  ];
}
