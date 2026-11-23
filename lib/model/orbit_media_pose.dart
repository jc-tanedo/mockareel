import 'dart:math';
import 'package:flutter/widgets.dart';
import 'orbit_scene.dart';

/// Orthographic projection of an upright 9:16 media plane. Both Flutter's
/// panel and the Media3 video texture use these coefficients at the same frame.
class OrbitMediaPose {
  final double progress;
  final double turn, tilt, distanceScale, lift;
  final Offset focus;
  const OrbitMediaPose(
    this.progress, {
    this.turn = 0,
    this.tilt = 0,
    this.distanceScale = 1,
    this.focus = Offset.zero,
    this.lift = 0,
  });
  double get zoom => (1 + .74 * progress) * distanceScale;

  /// Leave the outgoing media end pose and land at the incoming start pose.
  /// Separate captures each show the locally mapped half of the manoeuvre.
  factory OrbitMediaPose.travel(OrbitScene scene, double t, int direction) {
    final x = t.clamp(0.0, 1.0);
    final u = x * x * (3 - 2 * x);
    final arc = 4 * u * (1 - u);
    final progress = 1 - .65 * u;
    final turn = direction * arc * pi / 4;
    final heading = (-65 + 26 * progress) * pi / 180 + turn;
    final focus = Offset(cos(heading), -sin(heading)) * (direction * 85 * arc);
    final groundRise = scene.elevation(focus) - scene.elevation(Offset.zero);
    final relief = scene.localRelief.clamp(0.0, 180.0);
    return OrbitMediaPose(
      progress,
      turn: turn,
      tilt: arc * (.21 + relief / 1000),
      distanceScale: 1 - arc * (.19 + relief / 1500),
      focus: focus,
      lift: groundRise + arc * relief * .22,
    );
  }
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
  double get heading => (-65 + 26 * progress) * pi / 180 + turn;
  static const panelHeading = 52 * pi / 180;
  double get yaw => heading + panelHeading;
  static final _normal = Offset(-sin(panelHeading), cos(panelHeading));
  static bool inFrontOfPanel(OrbitFootprint building) =>
      building.points.every((p) => p.dx * _normal.dx + p.dy * _normal.dy > 0);
  double get depthScale => .64 * cos(tilt) + .77 * sin(tilt);
  double get heightScale => .77 * cos(tilt) - .64 * sin(tilt);
  double get sx => .30 * zoom * cos(yaw);
  double get sy => .30 * zoom * heightScale / .77;
  double get shear => .30 * zoom * sin(yaw) * depthScale;

  Offset pin(Size size, double scale) {
    final c = cos(heading), s = sin(heading);
    return Offset(
      size.width * .5 - (focus.dx * c - focus.dy * s) * scale,
      size.height * .54 +
          (lift * heightScale - (focus.dx * s + focus.dy * c) * depthScale) *
              scale,
    );
  }

  Offset get anchor => pin(const Size(360, 640), 360 / 450 * zoom);
  double get left => anchor.dx - 180 * sx;
  double get top => anchor.dy - 640 * sy - 180 * shear;
  Matrix4 get matrix => Matrix4.identity()
    ..setEntry(0, 0, sx)
    ..setEntry(1, 0, shear)
    ..setEntry(1, 1, sy)
    ..setTranslationRaw(left, top, 0);
  // Media3 coordinates are centered and have an upward Y axis.
  List<double> get native => [
    sx,
    0,
    anchor.dx / 180 - 1,
    -shear * 360 / 640,
    sy,
    1 - 2 * (top + 180 * shear + 320 * sy) / 640,
    0,
    0,
    1,
  ];
}
