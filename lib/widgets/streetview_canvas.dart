import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../model/project.dart';
import '../model/streetview_timeline.dart';
import '../model/streetview_motion.dart';
import '../model/streetview_layout.dart';
import 'media_frame.dart';
import 'streetview_chrome.dart';
import 'streetview_camera.dart';

class StreetviewCanvas extends StatelessWidget {
  final ReelProject project;
  final double position;
  final bool playing, overlayOnly, posterOnly;
  final Map<String, String> posters;
  const StreetviewCanvas({
    super.key,
    required this.project,
    this.position = 0,
    this.playing = false,
    this.overlayOnly = false,
    this.posterOnly = false,
    this.posters = const {},
  });
  @override
  Widget build(BuildContext context) {
    if (project.clips.isEmpty) return const ColoredBox(color: Colors.black);
    final scene = StreetviewTimeline.at(project, position),
        i = scene.mediaIndex;
    final clip = project.clips[i], settings = clip.streetview;
    final elapsed = scene.elapsed(position);
    final map = scene.kind == 'map' || scene.kind == 'ending-map',
        movement = scene.kind == 'arrow';
    final ripple = scene.kind == 'back' || (map && scene.kind != 'ending-map')
        ? (elapsed - scene.duration + StreetviewTimeline.rippleSeconds) /
              StreetviewTimeline.rippleSeconds
        : movement
        ? elapsed / StreetviewTimeline.rippleSeconds
        : -1.0;
    final t = movement
        ? ((elapsed - StreetviewTimeline.rippleSeconds) /
                  max(.001, scene.duration - StreetviewTimeline.rippleSeconds))
              .clamp(0.0, 1.0)
        : 0.0;
    final direction = settings.arrow == 'left' ? -1.0 : 1.0;
    Widget image(ReelClip c, double seconds) => ClipPoster(
      clip: c,
      position: seconds,
      resolvedPath: seconds >= c.duration && posters['${c.id}:end'] != null
          ? posters['${c.id}:end']
          : posters[c.id],
    );
    Widget media(ReelClip c, double seconds, {bool pixels = true}) =>
        StreetviewCamera(
          clip: c,
          seconds: seconds,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (pixels)
                posterOnly
                    ? image(c, seconds)
                    : MediaFrame(
                        key: ValueKey(c.id),
                        clip: c,
                        position: seconds,
                        playing:
                            playing &&
                            scene.kind == 'media' &&
                            c.id == clip.id &&
                            position < project.duration,
                      ),
              if (c.streetview.showArrows) const StreetviewArrows(),
            ],
          ),
        );
    Widget transition() => ColoredBox(
      color: Colors.black,
      child: ClipRect(
        child: ImageFiltered(
          imageFilter: ui.ImageFilter.blur(
            sigmaX: sin(t * pi) * 10,
            sigmaY: sin(t * pi) * 2,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Transform.translate(
                offset: Offset(-direction * 130 * t, 0),
                child: Transform.scale(
                  scale: 1 + t * .25,
                  child: media(clip, clip.duration),
                ),
              ),
              Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(direction * 130 * (1 - t), 0),
                  child: Transform.scale(
                    scale: 1 + (1 - t) * .25,
                    child: media(project.clips[i + 1], 0),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final arrow = StreetviewMotion.at(clip, clip.duration).project(
      settings.arrow == 'left'
          ? StreetviewLayout.arrowLeft + StreetviewLayout.arrowWidth / 2
          : 360 - StreetviewLayout.arrowLeft - StreetviewLayout.arrowWidth / 2,
      StreetviewLayout.arrowTop + StreetviewLayout.arrowHeight / 2,
    );
    return FittedBox(
      child: SizedBox(
        width: 360,
        height: 640,
        child: DefaultTextStyle(
          style: const TextStyle(fontFamily: 'Roboto'),
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              if (!overlayOnly)
                Positioned.fill(
                  child: ColoredBox(
                    color: movement ? Colors.black : Colors.transparent,
                  ),
                ),
              if (!overlayOnly)
                Positioned.fill(
                  key: const ValueKey('streetview-media-players'),
                  child: ClipRect(
                    child: ImageFiltered(
                      imageFilter: ui.ImageFilter.blur(
                        sigmaX: movement ? sin(t * pi) * 10 : 0,
                        sigmaY: movement ? sin(t * pi) * 2 : 0,
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          for (
                            var j = max(0, i - 1);
                            j <= min(project.clips.length - 1, i + 1);
                            j++
                          )
                            Positioned.fill(
                              key: ValueKey(
                                'streetview-player-${project.clips[j].id}',
                              ),
                              child: Opacity(
                                opacity: map
                                    ? 0
                                    : movement
                                    ? (j == i
                                          ? 1
                                          : j == i + 1
                                          ? t
                                          : 0)
                                    : j == i
                                    ? 1
                                    : 0,
                                child: Transform.translate(
                                  offset: Offset(
                                    movement
                                        ? direction *
                                              130 *
                                              (j == i ? -t : 1 - t)
                                        : 0,
                                    0,
                                  ),
                                  child: Transform.scale(
                                    scale: movement
                                        ? 1 + .25 * (j == i ? t : 1 - t)
                                        : 1,
                                    child: media(
                                      project.clips[j],
                                      j < i
                                          ? project.clips[j].duration
                                          : j > i || map
                                          ? 0
                                          : scene.kind == 'media'
                                          ? elapsed
                                          : clip.duration,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (map)
                Positioned.fill(
                  child: StreetviewMapScene(
                    settings: settings,
                    dark: project.darkOutput,
                    thumbnail: image(clip, 0),
                  ),
                )
              else ...[
                if (overlayOnly)
                  Positioned.fill(
                    child: movement
                        ? transition()
                        : media(
                            clip,
                            scene.kind == 'back' ? clip.duration : elapsed,
                            pixels: scene.kind == 'back',
                          ),
                  ),
                Positioned.fill(
                  child: StreetviewChrome(
                    settings: settings,
                    dark: project.darkOutput,
                  ),
                ),
              ],
              if (ripple >= 0 && ripple < 1)
                Positioned(
                  left: map
                      ? StreetviewLayout.thumbnailLeft +
                            StreetviewLayout.thumbnailWidth / 2
                      : scene.kind == 'back'
                      ? 333
                      : arrow.x,
                  top: map
                      ? StreetviewLayout.thumbnailTop +
                            StreetviewLayout.thumbnailHeight / 2
                      : scene.kind == 'back'
                      ? 35
                      : arrow.y,
                  child: _Ripple(progress: ripple),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Ripple extends StatelessWidget {
  final double progress;
  const _Ripple({required this.progress});
  @override
  Widget build(BuildContext context) => Transform.translate(
    offset: const Offset(-24, -24),
    child: Transform.scale(
      scale: .3 + progress,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: .45 * (1 - progress)),
          border: Border.all(
            color: Colors.white.withValues(alpha: 1 - progress),
            width: 2,
          ),
        ),
      ),
    ),
  );
}
