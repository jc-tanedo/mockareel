import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:mockareel/model/m3_motion.dart';
import 'package:mockareel/model/project.dart';
import 'package:mockareel/model/streetview_layout.dart';
import 'package:mockareel/model/streetview_motion.dart';
import 'package:mockareel/model/streetview_timeline.dart';
import 'package:mockareel/widgets/media_frame.dart';
import 'package:mockareel/widgets/streetview_arrows.dart';
import 'package:mockareel/widgets/streetview_map_scene.dart';
import '../model/orbit_dolly.dart';
import '../model/orbit_media_pose.dart';
import '../model/orbit_scene.dart';
import 'orbit_map.dart';
import 'photo_walk_frame.dart';

class OrbitJourneyCanvas extends StatelessWidget {
  final ReelProject project;
  final double position;
  final bool playing, overlayOnly, posterOnly;
  final Map<String, String> posters;
  const OrbitJourneyCanvas({
    super.key,
    required this.project,
    required this.position,
    required this.playing,
    required this.overlayOnly,
    required this.posterOnly,
    required this.posters,
  });

  static double _faceVisibility(OrbitMediaPose pose) {
    final facing = pose.frontFacing;
    if (facing <= .02) return 0;
    if (facing >= .14) return 1;
    return M3Motion.cameraEase((facing - .02) / .12);
  }

  @override
  Widget build(BuildContext context) {
    final scene = StreetviewTimeline.at(project, position),
        index = scene.mediaIndex;
    final elapsed = StreetviewMotion.sample(
      scene.elapsed(position),
      scene.duration,
    );
    final fraction = elapsed / scene.duration;
    final arrow = scene.kind == 'arrow',
        media = scene.kind == 'media',
        back = scene.kind == 'back';
    final clip = project.clips[index], settings = clip.streetview;
    final plan = scene.kind == 'map' || scene.kind == 'ending-map';
    // Leave at least three movement samples even for a short arrow tap.
    const step = 1 / M3Motion.exportFps;
    final lastFrame =
        ((scene.duration * M3Motion.exportFps).ceil() - 1) / M3Motion.exportFps;
    final tapSeconds = arrow
        ? min(.14, max(0.0, lastFrame - 3 * step))
        : StreetviewTimeline.rippleSeconds;
    final rippleDuration = arrow
        ? min(StreetviewTimeline.rippleSeconds * .8, max(step, lastFrame))
        : StreetviewTimeline.rippleSeconds;
    final t = arrow
        ? ((elapsed - tapSeconds) / max(step, lastFrame - tapSeconds)).clamp(
            0.0,
            1.0,
          )
        : 0.0;
    final entering = scene.kind == 'map';
    final mapHandoff = entering || back;
    // Use the existing scene budget. The final encoded frame reaches the
    // exact first pose of the following scene, even at the shortest duration.
    final flightStart = back
        ? min(.2, lastFrame * .25)
        : max(0.0, lastFrame - min(.85, lastFrame * .62));
    final flightFraction =
        ((elapsed - flightStart) / max(step, lastFrame - flightStart)).clamp(
          0.0,
          1.0,
        );
    final eased = M3Motion.cameraEase(flightFraction);
    final world = back
        ? 1 - eased
        : entering
        ? eased
        : plan
        ? 0.0
        : 1.0;
    final returningToNext = back && index + 1 < project.clips.length;
    final planClip = returningToNext ? project.clips[index + 1] : clip;
    final mapOpacity =
        1 - M3Motion.defaultEffects.eval((world / .67).clamp(0.0, 1.0));
    final hudOpacity = M3Motion.defaultEffects.eval(
      ((world - .62) / .38).clamp(0.0, 1.0),
    );
    final direction = settings.arrow == 'left' ? -1 : 1;
    final blend = M3Motion.defaultEffects.eval(
      ((t - .25) / .5).clamp(0.0, 1.0),
    );
    Widget shot(int i, OrbitDolly? dolly) {
      final item = project.clips[i];
      final active = i == index, incoming = arrow && i == index + 1;
      final seconds = active
          ? (media ? elapsed : (scene.kind == 'map' ? 0.0 : item.duration))
          : i < index
          ? item.duration
          : 0.0;
      final timedHole = overlayOnly && media && active && item.isTimed;
      final path = item.streetview.mapPath;
      final held = seconds >= item.duration
          ? posters['${item.id}:end']
          : posters[item.id];
      Widget surface;
      if (timedHole) {
        surface = const SizedBox.expand();
      } else if (!item.isTimed && item.streetview.walking) {
        surface = PhotoWalkFrame(clip: item, seconds: seconds);
      } else if (posterOnly || overlayOnly) {
        surface = ClipPoster(clip: item, position: seconds, resolvedPath: held);
      } else {
        surface = MediaFrame(
          key: ValueKey(item.id),
          clip: item,
          position: seconds,
          playing: playing && active && media && position < project.duration,
        );
      }
      return Positioned.fill(
        key: ValueKey('orbit-clip-${item.id}'),
        child: OrbitSceneBuilder(
          path: path,
          builder: (geometry, failed) {
            final travelling = dolly != null && (active || incoming);
            final dualWall = travelling && dolly.distinctWalls;
            final close =
                active &&
                media &&
                OrbitDolly.continuesSamePin(project.clips, i, geometry);
            final pose = travelling
                ? (incoming ? dolly.arrival : dolly.departure)
                : active && mapHandoff
                ? OrbitMediaPose.mapFlight(
                    geometry,
                    world,
                    returning: back,
                    wallId: item.streetview.wallId,
                  )
                : OrbitMediaPose.at(
                    active ? scene.kind : 'media',
                    active ? fraction : 0,
                    scene: geometry,
                    wallId: item.streetview.wallId,
                    closeApproach: close,
                  );
            final double panelOpacity;
            if (dualWall) {
              final endRamp = active
                  ? (t <= .82
                        ? 1.0
                        : 1.0 -
                              M3Motion.defaultEffects.eval(
                                ((t - .82) / .18).clamp(0.0, 1.0),
                              ))
                  : (t >= .18
                        ? 1.0
                        : M3Motion.defaultEffects.eval(
                            (t / .18).clamp(0.0, 1.0),
                          ));
              panelOpacity = (_faceVisibility(pose) * endRamp).clamp(0.0, 1.0);
            } else {
              panelOpacity = travelling && active ? 1 - blend : 1.0;
            }
            final arrowOpacity = dualWall
                ? (active
                      ? M3Motion.fadeThroughOut(t)
                      : M3Motion.fadeThroughIn(t))
                : (travelling && active ? 1 - blend : hudOpacity);
            final map = Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(
                  color: project.darkOutput
                      ? const Color(0xff233747)
                      : const Color(0xffcad9cf),
                ),
                if (path != null)
                  OrbitMapView(
                    scene: geometry,
                    failed: failed,
                    camera: pose,
                    dark: project.darkOutput,
                    zoom: pose.zoom,
                  ),
                if (pose.mount == null)
                  Positioned(
                    left: pose.anchor.dx - 80 * pose.zoom * .58,
                    top: pose.anchor.dy - 5,
                    width: 160 * pose.zoom * .58,
                    height: 12,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                  ),
              ],
            );
            final worldView = Stack(
              fit: StackFit.expand,
              children: [
                if (!dualWall && !(travelling && dolly.sharedWorld && incoming))
                  if (timedHole)
                    ClipPath(clipper: _OutsidePlane(pose), child: map)
                  else
                    map,
                Opacity(
                  key: ValueKey('orbit-panel-${item.id}'),
                  opacity: panelOpacity,
                  child: Transform(
                    transform: pose.matrix,
                    child: DecoratedBox(
                      position: DecorationPosition.foreground,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white70, width: 2),
                      ),
                      child: ClipRect(child: surface),
                    ),
                  ),
                ),
                if (geometry != null &&
                    geometry.atlas == null &&
                    panelOpacity > 0 &&
                    (pose.mount != null || (travelling && t > 0 && t < 1)) &&
                    (!dualWall || pose.frontFacing > .02))
                  IgnorePointer(
                    child: Opacity(
                      opacity: dualWall || pose.mount != null
                          ? 1
                          : min(1.0, 8 * t * (1 - t)),
                      child: CustomPaint(
                        painter: OrbitPainter(
                          geometry,
                          pose.progress,
                          project.darkOutput,
                          zoom: pose.zoom,
                          camera: pose,
                          foregroundOnly: true,
                        ),
                      ),
                    ),
                  ),
                if (item.streetview.showArrows &&
                    (media || arrow || mapHandoff))
                  Opacity(
                    opacity: arrowOpacity,
                    child: Transform(
                      transform: pose.groundFrom(
                        OrbitMediaPose.at(
                          'media',
                          1,
                          scene: geometry,
                          wallId: item.streetview.wallId,
                        ),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          const StreetviewArrows(),
                          if (arrow && active && elapsed < rippleDuration)
                            _TapRipple(
                              center: Offset(
                                direction < 0
                                    ? StreetviewLayout.arrowLeft +
                                          StreetviewLayout.arrowWidth / 2
                                    : StreetviewLayout.width -
                                          StreetviewLayout.arrowLeft -
                                          StreetviewLayout.arrowWidth / 2,
                                StreetviewLayout.arrowTop +
                                    StreetviewLayout.arrowHeight / 2,
                              ),
                              progress: (elapsed / rippleDuration).clamp(
                                0.0,
                                1.0,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
            return Opacity(
              opacity: dualWall
                  ? 1
                  : active
                  ? 1
                  : incoming
                  ? blend
                  : 0,
              child: worldView,
            );
          },
        ),
      );
    }

    final chrome = arrow && blend >= .5
        ? project.clips[index + 1].streetview
        : settings;
    final label = chrome.streetviewTitle.isNotEmpty
        ? chrome.streetviewTitle
        : chrome.place.name;
    final place = chrome.place;
    final locationText = label.isNotEmpty
        ? label
        : place.address.isNotEmpty
        ? place.address
        : (place.latitude != null && place.longitude != null)
        ? '${place.latitude!.toStringAsFixed(5)}, ${place.longitude!.toStringAsFixed(5)}'
        : '';
    final entryTap = min(StreetviewTimeline.rippleSeconds, flightStart);
    final ripple = back
        ? elapsed / max(step, flightStart)
        : entering
        ? (elapsed - flightStart + entryTap) / max(step, entryTap)
        : -1.0;
    Widget canvas(OrbitDolly? dolly, OrbitScene? source) {
      final dualWorld =
          arrow && dolly != null && dolly.distinctWalls && source != null;
      final indices = <int>[
        for (
          int j = max(0, index - 1);
          j <= min(index + 1, project.clips.length - 1);
          j++
        )
          if (!overlayOnly || j == index || (arrow && j == index + 1)) j,
      ];
      if (dualWorld) {
        final activePos = indices.indexOf(index);
        final nextPos = indices.indexOf(index + 1);
        if (activePos >= 0 && nextPos >= 0) {
          final depthA = dolly.departure.depthOf(
            dolly.departure.mount?.center ?? Offset.zero,
          );
          final depthB = dolly.departure.depthOf(
            dolly.arrival.mount?.center ?? Offset.zero,
          );
          final swap = depthA > depthB;
          if (swap && activePos < nextPos || !swap && activePos > nextPos) {
            indices[activePos] = index + 1;
            indices[nextPos] = index;
          }
        }
      }
      return FittedBox(
        child: SizedBox(
          width: 360,
          height: 640,
          child: DefaultTextStyle(
            style: const TextStyle(color: Colors.white, fontFamily: 'Roboto'),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (arrow)
                  ColoredBox(
                    color: project.darkOutput
                        ? const Color(0xff233747)
                        : const Color(0xffcad9cf),
                  ),
                Opacity(
                  opacity: world == 0 ? 0 : 1,
                  child: ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(
                      sigmaX: sin(t * pi) * (dualWorld ? .45 : 2.5),
                      sigmaY: sin(t * pi) * (dualWorld ? .2 : 1.0),
                    ),
                    enabled: arrow && t > 0,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (dualWorld)
                          Positioned.fill(
                            key: const ValueKey('orbit-shared-world'),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                ColoredBox(
                                  color: project.darkOutput
                                      ? const Color(0xff233747)
                                      : const Color(0xffcad9cf),
                                ),
                                OrbitMapView(
                                  scene: source,
                                  failed: false,
                                  camera: dolly.departure,
                                  dark: project.darkOutput,
                                  zoom: dolly.departure.zoom,
                                ),
                              ],
                            ),
                          ),
                        for (final j in indices) shot(j, dolly),
                      ],
                    ),
                  ),
                ),
                if ((plan || back) && mapOpacity > 0)
                  Positioned.fill(
                    child: OrbitSceneBuilder(
                      path: planClip.streetview.mapPath,
                      builder: (geometry, _) {
                        final path = project.streetview
                            .locationFor(planClip)
                            ?.overviewPath;
                        final fallback = OrbitPlanMap(
                          scene: geometry,
                          dark: project.darkOutput,
                          name: planClip.streetview.place.name,
                        );
                        final ending =
                            scene.kind == 'ending-map' ||
                            (back && !returningToNext);
                        final mapView = StreetviewMapScene(
                          settings: planClip.streetview,
                          dark: project.darkOutput,
                          basemap: path == null
                              ? fallback
                              : Image.file(
                                  File(path),
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, _, _) => fallback,
                                ),
                          thumbnail: ClipPoster(
                            clip: planClip,
                            position: ending ? planClip.duration : 0,
                            resolvedPath: ending
                                ? posters['${planClip.id}:end']
                                : posters[planClip.id],
                          ),
                        );
                        if (world == 0) return mapView;
                        // Carry the flat map sheet in the same projection as the
                        // descending camera while the raised scenery takes over.
                        final camera = OrbitMediaPose.mapFlight(
                          back ? source : geometry,
                          world,
                          returning: back,
                          wallId: settings.wallId,
                        );
                        final overhead = OrbitMediaPose.mapFlight(
                          back ? source : geometry,
                          0,
                          returning: back,
                          wallId: settings.wallId,
                        );
                        return Opacity(
                          opacity: mapOpacity,
                          child: Transform(
                            transform: camera.groundFrom(overhead),
                            child: mapView,
                          ),
                        );
                      },
                    ),
                  ),
                if (hudOpacity > 0 &&
                    chrome.showLocation &&
                    locationText.isNotEmpty)
                  Positioned(
                    left: 16,
                    right: 60,
                    top: 22,
                    child: Opacity(
                      opacity: hudOpacity,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            [
                              locationText,
                              if (chrome.date.isNotEmpty) chrome.date,
                            ].join(' · '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (chrome.showControls && hudOpacity > 0)
                  Positioned(
                    right: 17,
                    top: 23,
                    child: Opacity(
                      opacity: hudOpacity,
                      child: const CircleAvatar(
                        radius: 17,
                        backgroundColor: Colors.black54,
                        child: Icon(Icons.close, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                if (ripple > 0 && ripple < 1)
                  _TapRipple(
                    center: back
                        ? const Offset(326, 40)
                        : const Offset(
                            StreetviewLayout.thumbnailLeft +
                                StreetviewLayout.thumbnailWidth / 2,
                            StreetviewLayout.thumbnailTop +
                                StreetviewLayout.thumbnailHeight / 2,
                          ),
                    progress: ripple,
                  ),
              ],
            ),
          ),
        ),
      );
    }

    // Keep the player subtree mounted as the route comes in and out of view.
    final next = arrow ? project.clips[index + 1].streetview : null;
    return OrbitSceneBuilder(
      path: arrow || back ? settings.mapPath : null,
      builder: (source, _) => OrbitSceneBuilder(
        path: next?.mapPath,
        builder: (destination, _) => canvas(
          next == null
              ? null
              : OrbitDolly.between(settings, next, source, destination, t),
          source,
        ),
      ),
    );
  }
}

class _TapRipple extends StatelessWidget {
  final Offset center;
  final double progress;
  const _TapRipple({required this.center, required this.progress});
  @override
  Widget build(BuildContext context) => Positioned(
    left: center.dx - 18,
    top: center.dy - 18,
    child: Transform.scale(
      scale: .35 + progress,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: .4 * (1 - progress)),
          border: Border.all(color: Colors.white70),
        ),
      ),
    ),
  );
}

class _OutsidePlane extends CustomClipper<Path> {
  final OrbitMediaPose pose;
  _OutsidePlane(this.pose);
  @override
  Path getClip(Size size) {
    final rect = Offset.zero & size;
    final plane = (Path()..addRect(rect)).transform(pose.matrix.storage);
    return Path.combine(PathOperation.difference, Path()..addRect(rect), plane);
  }

  @override
  bool shouldReclip(_OutsidePlane old) => pose.matrix != old.pose.matrix;
}
