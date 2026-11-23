import 'dart:math';
import 'package:flutter/widgets.dart';
import 'orbit_scene.dart';

/// Orthographic projection of an upright 9:16 media plane. Both Flutter's
/// panel and the Media3 video texture use these coefficients at the same frame.
class OrbitMediaPose {
  final double progress;
  final double turn, tilt, distanceScale, lift;
  final Offset focus;
  final OrbitWallMount? mount;
  const OrbitMediaPose(
    this.progress, {
    this.mount,
    this.turn = 0,
    this.tilt = 0,
    this.distanceScale = 1,
    this.focus = Offset.zero,
    this.lift = 0,
  });
  double get _framing => (progress / .35).clamp(0.0, 1.0);
  // Retain some surrounding streetscape even when framing a small facade.
  double get zoom =>
      (1 + .74 * progress) *
      distanceScale /
      pow(mount?.sizeFactor ?? 1, .94 * _framing);
  double get _panelScale => .30 * zoom * (mount?.sizeFactor ?? 1);

  /// Leave the outgoing media end pose and land at the incoming start pose.
  /// Separate captures each show the locally mapped half of the manoeuvre.
  factory OrbitMediaPose.travel(OrbitScene scene, double t, int direction) {
    final x = t.clamp(0.0, 1.0);
    final u = x * x * (3 - 2 * x);
    final arc = 4 * u * (1 - u);
    final progress = 1 - .65 * u;
    final turn = direction * arc * pi / 4;
    final mount = scene.wallMount;
    final heading = _heading(progress, turn, mount);
    final factor = mount?.sizeFactor ?? 1;
    final center = mount?.center ?? Offset.zero;
    final focus =
        Offset(cos(heading), -sin(heading)) * (direction * 85 * arc * factor);
    final groundRise =
        scene.elevation(center + focus) - scene.elevation(center);
    final relief = scene.localRelief.clamp(0.0, 180.0);
    return OrbitMediaPose(
      progress,
      mount: mount,
      turn: turn,
      tilt: arc * (.21 + relief / 1000),
      distanceScale: 1 - arc * (.19 + relief / 1500),
      focus: focus,
      lift: groundRise + arc * relief * .22 * factor,
    );
  }
  factory OrbitMediaPose.at(String kind, double t, {OrbitScene? scene}) {
    final u = Curves.easeInOut.transform(t.clamp(0.0, 1.0));
    final progress = switch (kind) {
      'map' || 'ending-map' => .35 * u,
      'media' => .35 + .65 * u,
      'back' => 1.0 - u,
      _ => 1.0,
    };
    return OrbitMediaPose(progress, mount: scene?.wallMount);
  }

  static double _heading(double progress, double turn, OrbitWallMount? mount) =>
      (-65 + 26 * progress) * pi / 180 +
      turn +
      (mount == null
          ? 0
          : OrbitWallMount.defaultHeading - mount.tangent.direction);
  double get heading => _heading(progress, turn, mount);
  double get yaw =>
      heading + (mount?.tangent.direction ?? OrbitWallMount.defaultHeading);
  static final _defaultNormal = Offset(
    -sin(OrbitWallMount.defaultHeading),
    cos(OrbitWallMount.defaultHeading),
  );
  bool inFrontOfPanel(OrbitFootprint building) {
    final normal = mount?.normal ?? _defaultNormal;
    final anchor = mount?.center ?? Offset.zero;
    return building.points.every(
      (p) =>
          (p.dx - anchor.dx) * normal.dx + (p.dy - anchor.dy) * normal.dy > 0,
    );
  }

  double get depthScale => .64 * cos(tilt) + .77 * sin(tilt);
  double get heightScale => .77 * cos(tilt) - .64 * sin(tilt);
  double get sx => _panelScale * cos(yaw);
  double get sy => _panelScale * heightScale / .77;
  double get shear => _panelScale * sin(yaw) * depthScale;

  Offset _project(Offset p, double h, double scale) {
    final c = cos(heading), s = sin(heading);
    return Offset(
      (p.dx * c - p.dy * s) * scale,
      ((p.dx * s + p.dy * c) * depthScale - h * heightScale) * scale,
    );
  }

  Offset pin(Size size, double scale) {
    final target = focus + (mount?.center ?? Offset.zero) * _framing;
    final height = lift + (mount?.baseAbovePin ?? 0) * _framing;
    return Offset(size.width * .5, size.height * .54) -
        _project(target, height, scale);
  }

  Offset get anchor {
    const size = Size(360, 640);
    final scale = size.width / 450 * zoom;
    return pin(size, scale) +
        _project(mount?.center ?? Offset.zero, mount?.baseAbovePin ?? 0, scale);
  }

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
