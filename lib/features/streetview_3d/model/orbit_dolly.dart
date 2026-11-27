import 'dart:math';
import 'dart:ui';
import 'package:mockareel/model/place_details.dart';
import 'package:mockareel/model/reel_clip.dart';
import 'package:mockareel/model/streetview_data.dart';
import 'orbit_media_pose.dart';
import 'orbit_scene.dart';

/// One moving camera, expressed in the local coordinates of each capture.
class OrbitDolly {
  final OrbitMediaPose departure, arrival;
  final bool sharedWorld, distinctWalls;
  const OrbitDolly._(
    this.departure,
    this.arrival,
    this.sharedWorld,
    this.distinctWalls,
  );

  static Offset? pinOffset(PlaceDetails from, PlaceDetails to) {
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

  static bool isSharedWorld(StreetviewMedia from, StreetviewMedia to) {
    final pins = pinOffset(from.place, to.place);
    final samePin = pins != null && pins.distance < 1;
    return from.mapPath != null &&
        from.mapPath == to.mapPath &&
        (pins == null || samePin);
  }

  static bool continuesSamePin(
    List<ReelClip> clips,
    int index,
    OrbitScene? scene,
  ) {
    if (index <= 0 || index >= clips.length || scene == null) return false;
    final prev = clips[index - 1].streetview;
    final curr = clips[index].streetview;
    if (prev.transition == 'map' || !isSharedWorld(prev, curr)) return false;
    final a = scene.wallFor(prev.wallId);
    final b = scene.wallFor(curr.wallId);
    return a != null && b != null && a.id != b.id;
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
    final pins = pinOffset(from.place, to.place);
    final samePin = pins != null && pins.distance < 1;
    final shared = isSharedWorld(from, to);
    final destMount = destination?.wallFor(to.wallId);
    final distinctWalls =
        shared &&
        start.mount != null &&
        destMount != null &&
        start.mount!.id != destMount.id;
    final end = OrbitMediaPose.at(
      'media',
      0,
      scene: destination,
      wallId: to.wallId,
      closeApproach: distinctWalls,
    );
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
    final x = t.clamp(0.0, 1.0),
        u = x * x * x * (x * (6 * x - 15) + 10),
        arc = 4 * u * (1 - u);
    final progress = 1 - .65 * u;
    var rotation = atan2(
      sin(end.heading - start.heading),
      cos(end.heading - start.heading),
    );
    if (rotation.abs() > pi * .92) {
      rotation = side * rotation.abs();
    }
    final heading = start.heading + rotation * u;
    final turnFraction = (rotation.abs() / pi).clamp(0.0, 1.0);
    final push = distinctWalls
        ? () {
            final midHeading = start.heading + rotation * .5;
            final bowDistance = min(
              22.0,
              max(6.0, delta.distance * .28) * (.35 + .65 * turnFraction),
            );
            return Offset(sin(midHeading), cos(midHeading)) *
                (bowDistance * arc);
          }()
        : repeated
        ? fallback * (32 * arc * (start.mount?.sizeFactor ?? 1))
        : Offset.zero;
    final nominalZoom = exp(lerpDouble(log(start.zoom), log(end.zoom), u)!);
    final double zoom;
    if (distinctWalls) {
      final avgWall =
          OrbitWallMount.defaultWidth *
          ((start.mount!.sizeFactor + end.mount!.sizeFactor) / 2);
      final spanMeters = max(delta.distance * 1.65 + avgWall * .9, 55.0);
      final frameBothZoom = (450.0 / spanMeters).clamp(1.0, nominalZoom);
      final turnPullback = 1.0 - .34 * (.45 + .55 * turnFraction);
      final transitZoom = min(
        nominalZoom * turnPullback,
        frameBothZoom,
      ).clamp(1.0, nominalZoom);
      zoom = exp(lerpDouble(log(nominalZoom), log(transitZoom), arc)!);
    } else {
      final transitZoom = repeated
          ? nominalZoom * 1.16
          : min(nominalZoom, 230 / max(1.0, delta.distance));
      zoom = lerpDouble(nominalZoom, transitZoom, arc)!;
    }
    double reliefOf(OrbitScene? scene) =>
        scene == null || scene.atlas != null ? 0 : scene.localRelief;
    final relief = lerpDouble(
      reliefOf(source),
      reliefOf(destination),
      u,
    )!.clamp(0.0, 180.0);
    final tilt = distinctWalls
        ? arc * (.045 + .045 * turnFraction + min(.05, relief / 2400))
        : arc * (.065 + relief / 1800);
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
      final base = OrbitMediaPose(
        progress,
        mount: endpoint.mount,
        closeApproach: endpoint.closeApproach,
      );
      return OrbitMediaPose(
        progress,
        mount: endpoint.mount,
        closeApproach: endpoint.closeApproach,
        focus: focus,
        turn: atan2(sin(heading - base.heading), cos(heading - base.heading)),
        tilt: tilt,
        distanceScale: zoom / base.zoom,
        lift: altitude - ground - (endpoint.mount?.baseAbovePin ?? 0),
      );
    }

    final outgoing = x == 0 ? start : local(start, sourceFocus, sourceHeight);
    final incoming = x == 1 ? end : local(end, destFocus, destHeight);
    return OrbitDolly._(outgoing, incoming, shared, distinctWalls);
  }
}
