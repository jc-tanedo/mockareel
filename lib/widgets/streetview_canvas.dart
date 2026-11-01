import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../model/project.dart';
import '../model/streetview_layout.dart';
import '../model/streetview_motion.dart';
import '../model/streetview_timeline.dart';
import 'media_frame.dart';
import 'streetview_camera.dart';
import 'streetview_chrome.dart';

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
    final is3d = project.isStreetview3d;
    final scene = StreetviewTimeline.at(project, position),
        i = scene.mediaIndex;
    final clip = project.clips[i], settings = clip.streetview;
    final elapsed = scene.elapsed(position);
    final map = scene.kind == 'map' || scene.kind == 'ending-map',
        movement = scene.kind == 'arrow',
        isSwoop = scene.kind == 'swoop';
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

    // Classic Streetview thumbnail zoom (100ms)
    const transitionSec = 0.1;
    final isMedia = scene.kind == 'media';
    final isBack = scene.kind == 'back';
    final isExpanding = !is3d && isMedia && elapsed < transitionSec;
    final expandProgress = isExpanding
        ? (elapsed / transitionSec).clamp(0.0, 1.0)
        : 1.0;
    final expandT = Curves.easeInOut.transform(expandProgress);

    final backStart = max(0.0, scene.duration - transitionSec);
    final isShrinking = !is3d && isBack && elapsed >= backStart;
    final shrinkProgress = isShrinking
        ? ((elapsed - backStart) / transitionSec).clamp(0.0, 1.0)
        : 0.0;
    final shrinkT = Curves.easeInOut.transform(shrinkProgress);

    final hasCardTransition = isExpanding || isShrinking;
    final cardT = isExpanding ? expandT : (1.0 - shrinkT);

    const thumbOffset = Offset(-127.0, 191.0);
    const thumbScale = 82.0 / 360.0;
    final activeScale = isExpanding
        ? ui.lerpDouble(thumbScale, 1.0, expandT)!
        : isShrinking
        ? ui.lerpDouble(1.0, thumbScale, shrinkT)!
        : 1.0;
    final activeOffset = isExpanding
        ? Offset.lerp(thumbOffset, Offset.zero, expandT)!
        : isShrinking
        ? Offset.lerp(Offset.zero, thumbOffset, shrinkT)!
        : Offset.zero;
    final activeRadius = isExpanding
        ? ui.lerpDouble(48.29, 0.0, expandT)!
        : isShrinking
        ? ui.lerpDouble(0.0, 48.29, shrinkT)!
        : 0.0;

    // Classic motion blur and camera pan
    final blurX = sin(t * pi) * 36.0;
    final blurY = sin(t * pi) * 8.0;
    final outgoingScale = (1.0 + pow(t, 1.3) * 0.9).toDouble();
    final outgoingProgress = pow(t, 1.2).toDouble();
    final outgoingOffset = Offset(
      -direction * 180 * outgoingProgress,
      -25 * outgoingProgress,
    );
    final outgoingOpacity = (1.0 - pow(t, 1.8)).clamp(0.0, 1.0).toDouble();
    final incomingScale = 1.0 + (1.0 - t) * 0.35;
    final incomingOffset = Offset(direction * 150 * (1.0 - t), 20 * (1.0 - t));
    final incomingOpacity = pow(t, 0.7).clamp(0.0, 1.0).toDouble();

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
              if (c.id == clip.id && c.streetview.showArrows && !movement)
                is3d
                    ? Streetview3dRailOverlay(settings: c.streetview)
                    : const StreetviewArrows(),
            ],
          ),
        );

    Widget classicTransition() => ColoredBox(
      color: Colors.black,
      child: ClipRect(
        child: ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: blurX, sigmaY: blurY),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Opacity(
                opacity: outgoingOpacity,
                child: Transform.translate(
                  offset: outgoingOffset,
                  child: Transform.scale(
                    scale: outgoingScale,
                    child: media(clip, clip.duration),
                  ),
                ),
              ),
              Opacity(
                opacity: incomingOpacity,
                child: Transform.translate(
                  offset: incomingOffset,
                  child: Transform.scale(
                    scale: incomingScale,
                    child: media(project.clips[i + 1], 0),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final arrow = is3d
        ? const Point<double>(0, 0)
        : StreetviewMotion.at(clip, clip.duration).project(
            settings.arrow == 'left'
                ? StreetviewLayout.arrowLeft + StreetviewLayout.arrowWidth / 2
                : 360 -
                      StreetviewLayout.arrowLeft -
                      StreetviewLayout.arrowWidth / 2,
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
              // 1. Streetview 3D Swoop Dive
              if (is3d && isSwoop)
                Positioned.fill(
                  child: Streetview3dAerialSwoopScene(
                    progress: elapsed / max(0.001, scene.duration),
                    settings: settings,
                    streetClip: media(clip, 0, pixels: !overlayOnly),
                    dark: project.darkOutput,
                  ),
                )
              // 2. Streetview 3D On-Rails Forward Movement
              else if (is3d && movement) ...[
                if (elapsed < StreetviewTimeline.rippleSeconds) ...[
                  Positioned.fill(
                    child: media(clip, clip.duration, pixels: !overlayOnly),
                  ),
                  Positioned.fill(
                    child: Streetview3dTapDisc(
                      progress: elapsed / StreetviewTimeline.rippleSeconds,
                      railStop: settings.railStop,
                    ),
                  ),
                  Positioned.fill(
                    child: StreetviewChrome(
                      settings: settings,
                      dark: project.darkOutput,
                      is3d: true,
                    ),
                  ),
                ] else ...[
                  Positioned.fill(
                    child: Streetview3dDollyScene(
                      progress: t,
                      outgoingMedia: media(
                        clip,
                        clip.duration,
                        pixels: !overlayOnly,
                      ),
                      incomingMedia: media(
                        project.clips[i + 1],
                        0,
                        pixels: !overlayOnly,
                      ),
                      settings: settings,
                    ),
                  ),
                  Positioned.fill(
                    child: StreetviewChrome(
                      settings: project.clips[i + 1].streetview,
                      dark: project.darkOutput,
                      is3d: true,
                    ),
                  ),
                ],
              ]
              // 3. Regular rendering (Classic Streetview or Streetview 3D at rest / aerial hold)
              else ...[
                if (!overlayOnly) ...[
                  Positioned.fill(
                    child: ColoredBox(
                      color: movement ? Colors.black : Colors.transparent,
                    ),
                  ),
                  if (hasCardTransition)
                    Positioned.fill(
                      child: StreetviewMapScene(
                        settings: settings,
                        dark: project.darkOutput,
                        thumbnail: const SizedBox(),
                      ),
                    ),
                  Positioned.fill(
                    key: const ValueKey('streetview-media-players'),
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
                                        ? outgoingOpacity
                                        : j == i + 1
                                        ? incomingOpacity
                                        : 0)
                                  : j == i
                                  ? 1.0
                                  : 0,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  hasCardTransition && j == i
                                      ? activeRadius
                                      : 0.0,
                                ),
                                child: Transform.translate(
                                  offset: hasCardTransition && j == i
                                      ? activeOffset
                                      : movement
                                      ? (j == i
                                            ? outgoingOffset
                                            : incomingOffset)
                                      : Offset.zero,
                                  child: Transform.scale(
                                    scale: hasCardTransition && j == i
                                        ? activeScale
                                        : movement
                                        ? (j == i
                                              ? outgoingScale
                                              : incomingScale)
                                        : 1.0,
                                    child: media(
                                      project.clips[j],
                                      j < i
                                          ? project.clips[j].duration
                                          : j > i || map
                                          ? 0
                                          : isMedia
                                          ? elapsed
                                          : clip.duration,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (map)
                    Positioned.fill(
                      child: is3d
                          ? Streetview3dAerialScene(
                              settings: settings,
                              dark: project.darkOutput,
                              thumbnail: image(clip, 0),
                            )
                          : StreetviewMapScene(
                              settings: settings,
                              dark: project.darkOutput,
                              thumbnail: image(clip, 0),
                            ),
                    ),
                ],
                if (overlayOnly) ...[
                  if (map)
                    Positioned.fill(
                      child: is3d
                          ? Streetview3dAerialScene(
                              settings: settings,
                              dark: project.darkOutput,
                              thumbnail: image(clip, 0),
                            )
                          : StreetviewMapScene(
                              settings: settings,
                              dark: project.darkOutput,
                              thumbnail: image(clip, 0),
                            ),
                    )
                  else
                    Positioned.fill(
                      child: movement
                          ? classicTransition()
                          : media(
                              clip,
                              isBack ? clip.duration : elapsed,
                              pixels: isBack,
                            ),
                    ),
                ],
                if (!map)
                  Positioned.fill(
                    child: Opacity(
                      opacity: hasCardTransition ? cardT : 1.0,
                      child: StreetviewChrome(
                        settings: settings,
                        dark: project.darkOutput,
                        is3d: is3d,
                      ),
                    ),
                  ),
                if (ripple >= 0 && ripple < 1 && !is3d)
                  Positioned(
                    left: map
                        ? StreetviewLayout.thumbnailLeft + 41.0
                        : scene.kind == 'back'
                        ? 333
                        : arrow.x,
                    top: map
                        ? StreetviewLayout.thumbnailTop + 27.0
                        : scene.kind == 'back'
                        ? 35
                        : arrow.y,
                    child: _Ripple(progress: ripple),
                  ),
                if (ripple >= 0 && ripple < 1 && is3d && map)
                  Positioned(
                    left: 45,
                    top: 625,
                    child: _Ripple(progress: ripple),
                  ),
              ],
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
