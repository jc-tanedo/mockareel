import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../model/orbit_media_pose.dart';
import '../model/project.dart';
import '../model/streetview_motion.dart';
import '../model/streetview_timeline.dart';
import 'media_frame.dart';
import 'orbit_map.dart';
import 'photo_walk_frame.dart';
import 'streetview_arrows.dart';

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
    // Leave at least three movement samples even for a short arrow tap.
    final lastFrame = ((scene.duration * 30).ceil() - 1) / 30;
    final tapSeconds = arrow
        ? min(StreetviewTimeline.rippleSeconds, max(0.0, lastFrame - 3 / 30))
        : StreetviewTimeline.rippleSeconds;
    final t = arrow
        ? ((elapsed - tapSeconds) / max(1 / 30, lastFrame - tapSeconds)).clamp(
            0.0,
            1.0,
          )
        : 0.0;
    final direction = settings.arrow == 'left' ? -1 : 1;
    final shared =
        arrow &&
        settings.mapPath != null &&
        settings.mapPath == project.clips[index + 1].streetview.mapPath;
    final blend = Curves.easeInOut.transform(((t - .25) / .5).clamp(0.0, 1.0));
    Widget shot(int i) {
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
            final flying =
                arrow &&
                (active || incoming) &&
                geometry != null &&
                geometry.atlas == null;
            final pose = flying
                ? OrbitMediaPose.travel(
                    geometry,
                    t,
                    incoming && !shared ? -direction : direction,
                  )
                : OrbitMediaPose.at(
                    active ? scene.kind : 'media',
                    active ? fraction : 0,
                  );
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
            final world = Stack(
              fit: StackFit.expand,
              children: [
                if (!(flying && shared && incoming))
                  if (timedHole)
                    ClipPath(clipper: _OutsidePlane(pose), child: map)
                  else
                    map,
                Opacity(
                  opacity: flying && active ? 1 - blend : 1,
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
                if (flying && t > 0 && t < 1)
                  IgnorePointer(
                    child: Opacity(
                      opacity: min(1.0, 8 * t * (1 - t)),
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
              ],
            );
            final opacity = active
                ? (flying ? 1.0 : 1 - t)
                : incoming
                ? (flying ? blend : t)
                : 0.0;
            return Opacity(
              opacity: opacity,
              child: Transform.translate(
                offset: Offset(
                  arrow && !flying
                      ? direction * (active ? -t : 1 - t) * 110
                      : 0,
                  0,
                ),
                child: world,
              ),
            );
          },
        ),
      );
    }

    final label = settings.streetviewTitle.isNotEmpty
        ? settings.streetviewTitle
        : settings.place.name;
    final place = settings.place;
    final locationText = label.isNotEmpty
        ? label
        : place.address.isNotEmpty
        ? place.address
        : (place.latitude != null && place.longitude != null)
        ? '${place.latitude!.toStringAsFixed(5)}, ${place.longitude!.toStringAsFixed(5)}'
        : '';
    final ripple = arrow || back
        ? elapsed / tapSeconds
        : scene.kind == 'map'
        ? (elapsed - scene.duration + StreetviewTimeline.rippleSeconds) /
              StreetviewTimeline.rippleSeconds
        : -1.0;
    final rippleCenter = arrow
        ? Offset(direction < 0 ? 63 : 297, 476)
        : back
        ? const Offset(326, 40)
        : const Offset(180, 330);
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
              ImageFiltered(
                imageFilter: ui.ImageFilter.blur(
                  sigmaX: sin(t * pi) * 2.5,
                  sigmaY: sin(t * pi) * 1.0,
                ),
                enabled: arrow && t > 0,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    for (
                      int j = max(0, index - 1);
                      j <= min(index + 1, project.clips.length - 1);
                      j++
                    )
                      if (!overlayOnly ||
                          j == index ||
                          (arrow && j == index + 1))
                        shot(j),
                  ],
                ),
              ),
              if (settings.showLocation && locationText.isNotEmpty)
                Positioned(
                  left: 16,
                  right: 60,
                  top: 22,
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
                          if (settings.date.isNotEmpty) settings.date,
                        ].join(' · '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                ),
              if (settings.showControls && (media || back || arrow))
                const Positioned(
                  right: 17,
                  top: 23,
                  child: CircleAvatar(
                    radius: 17,
                    backgroundColor: Colors.black54,
                    child: Icon(Icons.close, color: Colors.white, size: 18),
                  ),
                ),
              if (settings.showArrows && (media || arrow || back))
                const StreetviewArrows(),
              if (ripple >= 0 && ripple < 1)
                Positioned(
                  left: rippleCenter.dx - 18,
                  top: rippleCenter.dy - 18,
                  child: Transform.scale(
                    scale: .35 + ripple,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(
                          alpha: .4 * (1 - ripple),
                        ),
                        border: Border.all(color: Colors.white70),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
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
  bool shouldReclip(_OutsidePlane old) => pose.progress != old.pose.progress;
}
