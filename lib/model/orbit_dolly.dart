import 'dart:math';
import 'dart:ui';
import 'orbit_media_pose.dart';
import 'orbit_scene.dart';
import 'project.dart';

/// One moving camera, expressed in the local coordinates of each capture.
class OrbitDolly {
  final OrbitMediaPose departure, arrival;
  final bool sharedWorld;
  const OrbitDolly._(this.departure, this.arrival, this.sharedWorld);

  static Offset? _pinOffset(PlaceDetails from, PlaceDetails to) {
    final a = from.latitude,
        b = to.latitude,
        x = from.longitude,
        y = to.longitude;
    if (a == null ||
        b == null ||
        x == null ||
        y == null ||
        ![a, b, x, y].every((n) => n.isFinite) ||
        a.abs() > 90 ||
        b.abs() > 90 ||
        x.abs() > 180 ||
        y.abs() > 180) {
      return null;
    }
    final longitude = (y - x + 540) % 360 - 180;
    return Offset(
      longitude * 111320 * cos((a + b) * pi / 360),
      (a - b) * 111132,
    );
  }

  factory OrbitDolly.between(
    StreetviewMedia from,
    StreetviewMedia to,
    OrbitScene? source,
    OrbitScene? destination,
    double t,
  ) {
    final start = OrbitMediaPose.at(
      'media',
      1,
      scene: source,
      wallId: from.wallId,
    );
    final end = OrbitMediaPose.at(
      'media',
      0,
      scene: destination,
      wallId: to.wallId,
    );
    final pins = _pinOffset(from.place, to.place);
    final samePin = pins != null && pins.distance < 1;
    final shared =
        from.mapPath != null &&
        from.mapPath == to.mapPath &&
        (pins == null || samePin);
    final origin = start.mount?.center ?? Offset.zero;
    final target = end.mount?.center ?? Offset.zero;
    final side = from.arrow == 'left' ? -1 : 1;
    final fallback =
        Offset(cos(start.heading), -sin(start.heading)) * (side * .8) -
        Offset(sin(start.heading), cos(start.heading)) * .6;
    final repeated = (shared || samePin) && start.mount?.id == end.mount?.id;
    // Both map grids span 1.2 km. Compress the missing middle of longer trips.
    final displacement = pins ?? (shared ? Offset.zero : fallback * 150);
    final span = displacement.distance;
    final limit = source?.atlas != null || destination?.atlas != null
        ? 120.0
        : 450.0;
    final delta =
        displacement * (span > limit ? limit / span : 1) + target - origin;
    final x = t.clamp(0.0, 1.0), u = x * x * (3 - 2 * x), arc = 4 * u * (1 - u);
    final push = repeated
        ? fallback * (32 * arc * (start.mount?.sizeFactor ?? 1))
        : Offset.zero;
    final progress = 1 - .65 * u;
    final rotation = atan2(
      sin(end.heading - start.heading),
      cos(end.heading - start.heading),
    );
    final heading = start.heading + rotation * u;
    final nominalZoom = exp(lerpDouble(log(start.zoom), log(end.zoom), u)!);
    final transitZoom = repeated
        ? nominalZoom * 1.16
        : min(nominalZoom, 230 / max(1.0, delta.distance));
    final zoom = lerpDouble(nominalZoom, transitZoom, arc)!;
    double reliefOf(OrbitScene? scene) =>
        scene == null || scene.atlas != null ? 0 : scene.localRelief;
    final relief = lerpDouble(
      reliefOf(source),
      reliefOf(destination),
      u,
    )!.clamp(0.0, 180.0);
    final tilt = arc * (.065 + relief / 1800);
    double datum(OrbitScene? scene) =>
        scene == null || scene.atlas != null ? 0 : scene.elevation(Offset.zero);
    const sourceHeight = 0.0;
    final destHeight = (datum(destination) - datum(source)).clamp(
      -100.0,
      100.0,
    );
    // Follow local terrain while keeping the two camera projections registered
    // through the handoff, including when the wall mounts differ in elevation.
    final sourceFocus = delta * u + push, destFocus = delta * (u - 1) + push;
    double rise(OrbitScene? scene, Offset center, Offset focus) =>
        scene == null || scene.atlas != null
        ? 0
        : scene.elevation(center + focus) - scene.elevation(center);
    final altitude =
        lerpDouble(
          sourceHeight + (start.mount?.baseAbovePin ?? 0),
          destHeight + (end.mount?.baseAbovePin ?? 0),
          u,
        )! +
        lerpDouble(
          rise(source, origin, sourceFocus),
          rise(destination, target, destFocus),
          u,
        )! +
        arc * min(relief * .14, 25 / zoom);
    OrbitMediaPose local(OrbitMediaPose endpoint, Offset focus, double ground) {
      final base = OrbitMediaPose(progress, mount: endpoint.mount);
      return OrbitMediaPose(
        progress,
        mount: endpoint.mount,
        focus: focus,
        turn: atan2(sin(heading - base.heading), cos(heading - base.heading)),
        tilt: tilt,
        distanceScale: zoom / base.zoom,
        lift: altitude - ground - (endpoint.mount?.baseAbovePin ?? 0),
      );
    }

    final outgoing = x == 0 ? start : local(start, sourceFocus, sourceHeight);
    final incoming = x == 1 ? end : local(end, destFocus, destHeight);
    return OrbitDolly._(outgoing, incoming, shared);
  }
}
