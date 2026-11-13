import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../model/project.dart';
import '../model/streetview_layout.dart';
import '../model/streetview_motion.dart';
import '../model/streetview_timeline.dart';
import 'media_frame.dart';
import 'streetview_3d_canvas.dart';
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
    if (project.isStreetview3d) {
      return Streetview3dCanvas(
        project: project,
        position: position,
        playing: playing,
        overlayOnly: overlayOnly,
        posterOnly: posterOnly,
        posters: posters,
      );
    }
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

    // 100ms quick transition between map thumbnail and full sized media
    const transitionSec = 0.1;
    final isMedia = scene.kind == 'media';
    final isBack = scene.kind == 'back';
    // Arrow handoffs already arrive at full size. Only a map thumbnail
    // should expand into the next media scene.
    final followsMap =
        i == 0 || project.clips[i - 1].streetview.transition == 'map';
    // Export composites native media at full size, so its overlay must be
    // fully visible even when captured at the first frame of the scene.
    final isExpanding =
        !overlayOnly && isMedia && followsMap && elapsed < transitionSec;
    final expandProgress = isExpanding
        ? (elapsed / transitionSec).clamp(0.0, 1.0)
        : 1.0;
    final expandT = Curves.easeInOut.transform(expandProgress);

    final backStart = max(0.0, scene.duration - transitionSec);
    final isShrinking = isBack && elapsed >= backStart;
    final shrinkProgress = isShrinking
        ? ((elapsed - backStart) / transitionSec).clamp(0.0, 1.0)
        : 0.0;
    final shrinkT = Curves.easeInOut.transform(shrinkProgress);

    final hasCardTransition = isExpanding || isShrinking;
    final cardT = isExpanding ? expandT : (1.0 - shrinkT);

    const fullRect = Rect.fromLTWH(0, 0, 360, 640);
    const thumbRect = Rect.fromLTWH(
      StreetviewLayout.thumbnailLeft,
      StreetviewLayout.thumbnailTop,
      StreetviewLayout.thumbnailWidth,
      StreetviewLayout.thumbnailHeight,
    );
    final liveMap = map && !posterOnly;
    final activeRect = liveMap
        ? thumbRect
        : isExpanding
        ? Rect.lerp(thumbRect, fullRect, expandT)!
        : isShrinking
        ? Rect.lerp(fullRect, thumbRect, shrinkT)!
        : fullRect;
    final activeRadius = liveMap
        ? 12.0
        : isExpanding
        ? ui.lerpDouble(12, 0, expandT)!
        : isShrinking
        ? ui.lerpDouble(0, 12, shrinkT)!
        : 0.0;

    // Dramatic motion blur and streetview camera rush
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
              if (c.streetview.showArrows)
                Opacity(opacity: map ? 0 : 1, child: const StreetviewArrows()),
            ],
          ),
        );

    Widget transition() => ColoredBox(
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
              if (!overlayOnly) ...[
                Positioned.fill(
                  child: ColoredBox(
                    color: movement ? Colors.black : Colors.transparent,
                  ),
                ),
                if (hasCardTransition || liveMap)
                  Positioned.fill(
                    key: const ValueKey('streetview-map-background'),
                    child: StreetviewMapScene(
                      settings: settings,
                      dark: project.darkOutput,
                      thumbnail: const SizedBox(),
                      showThumbnail: false,
                    ),
                  ),
                Positioned.fill(
                  key: const ValueKey('streetview-media-players'),
                  child: ClipRect(
                    child: ImageFiltered(
                      imageFilter: ui.ImageFilter.blur(
                        sigmaX: movement ? blurX : 0,
                        sigmaY: movement ? blurY : 0,
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          for (
                            var j = max(0, i - 1);
                            j <= min(project.clips.length - 1, i + 1);
                            j++
                          )
                            Positioned.fromRect(
                              key: ValueKey(
                                'streetview-player-${project.clips[j].id}',
                              ),
                              rect: j == i ? activeRect : fullRect,
                              child: Opacity(
                                opacity: map
                                    ? (liveMap && j == i ? 1 : 0)
                                    : movement
                                    ? (j == i
                                          ? outgoingOpacity
                                          : j == i + 1
                                          ? incomingOpacity
                                          : 0)
                                    : j == i
                                    ? 1
                                    : 0,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    j == i ? activeRadius : 0.0,
                                  ),
                                  child: Transform.translate(
                                    offset: movement
                                        ? (j == i
                                              ? outgoingOffset
                                              : incomingOffset)
                                        : Offset.zero,
                                    child: Transform.scale(
                                      scale: movement
                                          ? (j == i
                                                ? outgoingScale
                                                : incomingScale)
                                          : 1.0,
                                      child: FittedBox(
                                        fit: BoxFit.cover,
                                        child: SizedBox(
                                          width: 360,
                                          height: 640,
                                          child: media(
                                            project.clips[j],
                                            j < i
                                                ? project.clips[j].duration
                                                : j > i ||
                                                      (map &&
                                                          scene.kind !=
                                                              'ending-map')
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
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (liveMap)
                  const Positioned(
                    left: StreetviewLayout.thumbnailLeft,
                    top: StreetviewLayout.thumbnailTop,
                    width: StreetviewLayout.thumbnailWidth,
                    height: StreetviewLayout.thumbnailHeight,
                    child: StreetviewMapThumbnail(thumbnail: SizedBox()),
                  ),
                if (map && !liveMap)
                  Positioned.fill(
                    child: StreetviewMapScene(
                      settings: settings,
                      dark: project.darkOutput,
                      thumbnail: image(
                        clip,
                        scene.kind == 'ending-map' ? clip.duration : 0,
                      ),
                    ),
                  ),
              ],
              if (overlayOnly) ...[
                if (map)
                  Positioned.fill(
                    child: StreetviewMapScene(
                      settings: settings,
                      dark: project.darkOutput,
                      thumbnail: image(
                        clip,
                        scene.kind == 'ending-map' ? clip.duration : 0,
                      ),
                    ),
                  )
                else if (isBack) ...[
                  // Keep the map and held poster mounted for the whole return
                  // scene so decoding cannot interrupt the shrinking card.
                  Positioned.fill(
                    child: StreetviewMapScene(
                      settings: settings,
                      dark: project.darkOutput,
                      thumbnail: const SizedBox(),
                      showThumbnail: false,
                    ),
                  ),
                  Positioned.fromRect(
                    rect: activeRect,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(activeRadius),
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: 360,
                          height: 640,
                          child: media(clip, clip.duration),
                        ),
                      ),
                    ),
                  ),
                ] else
                  Positioned.fill(
                    child: movement
                        ? transition()
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
                    ),
                  ),
                ),
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
