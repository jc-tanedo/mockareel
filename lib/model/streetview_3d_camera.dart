import 'dart:math';
import 'dart:ui';

import 'package:flutter/animation.dart';

/// Immutable 3D vector in meters (+X right, +Y up, +Z forward along road).
class Vec3 {
  final double x, y, z;
  const Vec3(this.x, this.y, this.z);

  Vec3 operator +(Vec3 o) => Vec3(x + o.x, y + o.y, z + o.z);
  Vec3 operator -(Vec3 o) => Vec3(x - o.x, y - o.y, z - o.z);
  Vec3 operator *(double s) => Vec3(x * s, y * s, z * s);

  double get length => sqrt(x * x + y * y + z * z);

  static Vec3 lerp(Vec3 a, Vec3 b, double t) => Vec3(
    lerpDouble(a.x, b.x, t)!,
    lerpDouble(a.y, b.y, t)!,
    lerpDouble(a.z, b.z, t)!,
  );
}

/// 6-DOF perspective camera for Streetview 3D.
class Camera3D {
  final Vec3 pos;
  final double pitch; // radians; 0 = horizon, negative = looking down
  final double yaw; // radians; 0 = +Z, positive = turning right (+X)
  final double roll; // radians; banking angle
  final double fovY; // vertical field of view in radians
  final double nearPlane;

  const Camera3D({
    this.pos = const Vec3(0, 1.7, 0),
    this.pitch = 0,
    this.yaw = 0,
    this.roll = 0,
    this.fovY = 62 * pi / 180,
    this.nearPlane = 0.25,
  });

  /// Transforms a world-space point into camera-local coordinates (+Z forward).
  Vec3 toCameraSpace(Vec3 w) {
    final dx = w.x - pos.x;
    final dy = w.y - pos.y;
    final dz = w.z - pos.z;

    final cosY = cos(yaw);
    final sinY = sin(yaw);
    final x1 = dx * cosY - dz * sinY;
    final z1 = dx * sinY + dz * cosY;

    final cosP = cos(pitch);
    final sinP = sin(pitch);
    final y2 = dy * cosP - z1 * sinP;
    final z2 = dy * sinP + z1 * cosP;

    if (roll == 0) return Vec3(x1, y2, z2);
    final cosR = cos(roll);
    final sinR = sin(roll);
    return Vec3(x1 * cosR + y2 * sinR, -x1 * sinR + y2 * cosR, z2);
  }

  /// Projects a world-space point to 2D screen coordinates, or null if behind
  /// the near clipping plane.
  Offset? project(Vec3 w, Size viewport) {
    final c = toCameraSpace(w);
    if (c.z <= nearPlane) return null;
    final f = (viewport.height * 0.5) / tan(fovY * 0.5);
    return Offset(
      viewport.width * 0.5 + (c.x / c.z) * f,
      viewport.height * 0.5 - (c.y / c.z) * f,
    );
  }

  /// Projects a camera-space point directly (useful after near-plane clipping).
  Offset projectCameraPoint(Vec3 c, Size viewport) {
    final z = max(nearPlane, c.z);
    final f = (viewport.height * 0.5) / tan(fovY * 0.5);
    return Offset(
      viewport.width * 0.5 + (c.x / z) * f,
      viewport.height * 0.5 - (c.y / z) * f,
    );
  }

  /// Screen-space scale factor (pixels per meter at world point [w]).
  double scaleAt(Vec3 w, Size viewport) {
    final c = toCameraSpace(w);
    if (c.z <= nearPlane) return 0;
    return ((viewport.height * 0.5) / tan(fovY * 0.5)) / c.z;
  }

  /// Aerial hold camera hovering high above the corridor.
  static const Camera3D aerialHold = Camera3D(
    pos: Vec3(0, 58, -6),
    pitch: -1.38,
    fovY: 58 * pi / 180,
  );

  /// Street-level resting camera.
  static const Camera3D streetRest = Camera3D(
    pos: Vec3(0, 1.7, 0),
    pitch: 0,
    fovY: 62 * pi / 180,
  );

  /// Interpolates the aerial-to-street 3D swoop dive for [u] in 0..1.
  static Camera3D swoopAt(double u) {
    final t = u.clamp(0.0, 1.0);
    final easePos = Curves.easeInOutCubic.transform(t);
    final easePitch = Curves.easeInOut.transform(t);
    return Camera3D(
      pos: Vec3(
        0,
        lerpDouble(58.0, 1.7, pow(easePos, 0.72).toDouble())!,
        lerpDouble(-6.0, 0.0, easePos)!,
      ),
      pitch: lerpDouble(-1.38, 0.0, easePitch)!,
      fovY: lerpDouble(58, 62, easePos)! * pi / 180 + sin(t * pi) * 0.14,
    );
  }

  /// Interpolates an on-rails forward or turn hop for [t] in 0..1.
  static Camera3D railHopAt(
    double t, {
    String railStop = 'near',
    String railDirection = 'straight',
  }) {
    final u = t.clamp(0.0, 1.0);
    final ease = Curves.easeInOutCubic.transform(u);
    final distance = railStop == 'far' ? 28.0 : 18.0;
    final turnSign = railDirection == 'left'
        ? -1.0
        : railDirection == 'right'
        ? 1.0
        : 0.0;
    final turnYaw = turnSign * 1.12 * Curves.easeInOut.transform(u);
    final bankRoll = -turnSign * 0.06 * sin(u * pi);
    final xDrift = turnSign * 4.5 * pow(ease, 1.6);
    final warpFov = 62.0 + sin(u * pi) * 22.0;
    return Camera3D(
      pos: Vec3(xDrift, 1.7, ease * distance),
      pitch: 0,
      yaw: turnYaw,
      roll: bankRoll,
      fovY: warpFov * pi / 180,
    );
  }
}
