import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../features/streetview_3d/presentation/orbit_journey_canvas.dart';
import '../model/audio_mix.dart';
import '../model/m3_motion.dart';
import '../model/project.dart';
import '../model/streetview_layout.dart';
import '../model/streetview_motion.dart';
import '../model/streetview_timeline.dart';
import 'm3_ink_ripple.dart';
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
    if (project.isStreetview3d) {
      return OrbitJourneyCanvas(
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
    final tapDur = movement
        ? StreetviewContainerMotion.arrowTapDuration(scene.duration)
        : StreetviewTimeline.rippleSeconds;
    final ripple = map && scene.kind != 'ending-map'
        ? (elapsed - scene.duration + StreetviewTimeline.rippleSeconds) /
              StreetviewTimeline.rippleSeconds
        : scene.kind == 'back'
        ? StreetviewContainerMotion.backTapProgress(elapsed, scene.duration)
        : movement
        ? elapsed / max(.001, tapDur)
        : -1.0;

    final rushStart = tapDur * 0.7;
    final rushU = movement
        ? ((elapsed - rushStart) / max(.001, scene.duration - rushStart)).clamp(
            0.0,
            1.0,
          )
        : 0.0;
    final direction = settings.arrow == 'left' ? -1.0 : 1.0;

    final isMedia = scene.kind == 'media';
    final isBack = scene.kind == 'back';
    final followsMap = StreetviewTimeline.followsMap(project, i);
    final expandDur = StreetviewTimeline.expandDuration(clip);
    final isExpanding = isMedia && followsMap && elapsed < expandDur - 1e-9;

    final expandState = isExpanding
        ? StreetviewContainerMotion.expandAt(elapsed, expandDur)
        : null;
    final shrinkState = isBack
        ? StreetviewContainerMotion.shrinkAt(elapsed, scene.duration)
        : null;
    final activeState = expandState ?? shrinkState;
    final hasCardTransition = activeState != null;

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
        : activeState != null
        ? Rect.fromLTWH(
            activeState.left,
            activeState.top,
            activeState.width,
            activeState.height,
          )
        : fullRect;
    final activeRadius = liveMap ? 12.0 : activeState?.radius ?? 0.0;
    final chromeOpacity = activeState?.chromeOpacity ?? 1.0;
    final scrimAlpha = activeState?.scrimAlpha ?? 0.0;
    final sheetOffset = activeState?.sheetOffset ?? 0.0;
    final borderAlpha = activeState?.borderAlpha ?? 0.0;

    // Material 3 Expressive directional rush + motion blur.
    final rushSpatial = M3Motion.defaultSpatial.eval(rushU);
    final rushEffects = M3Motion.defaultEffects.eval(rushU);
    final blurX = sin(rushU * pi) * 32.0;
    final blurY = sin(rushU * pi) * 7.0;
    final outgoingScale = 1.0 + rushSpatial * 0.75;
    final outgoingOffset = Offset(
      -direction * 170 * rushSpatial,
      -20 * rushSpatial,
    );
    final outgoingOpacity = (1.0 - rushEffects).clamp(0.0, 1.0);
    final incomingScale = (1.0 + (1.0 - rushSpatial) * 0.30).clamp(0.85, 1.4);
    final incomingOffset = Offset(
      direction * 140 * (1.0 - rushSpatial),
      18 * (1.0 - rushSpatial),
    );
    final incomingOpacity = rushEffects.clamp(0.0, 1.0);

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
                        volume: AudioMix.clipVolume(project, c),
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
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        StreetviewMapScene(
                          settings: settings,
                          dark: project.darkOutput,
                          thumbnail: const SizedBox(),
                          showThumbnail: false,
                        ),
                        if (scrimAlpha > 0)
                          ColoredBox(
                            color: Colors.black.withValues(alpha: scrimAlpha),
                          ),
                      ],
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
                if (hasCardTransition && borderAlpha > 0)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _ContainerBorderPainter(
                          activeRect,
                          activeRadius,
                          borderAlpha,
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
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        StreetviewMapScene(
                          settings: settings,
                          dark: project.darkOutput,
                          thumbnail: const SizedBox(),
                          showThumbnail: false,
                        ),
                        if (scrimAlpha > 0)
                          ColoredBox(
                            color: Colors.black.withValues(alpha: scrimAlpha),
                          ),
                      ],
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
                  if (borderAlpha > 0)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _ContainerBorderPainter(
                            activeRect,
                            activeRadius,
                            borderAlpha,
                          ),
                        ),
                      ),
                    ),
                ] else if (isExpanding) ...[
                  // Even-odd cutout keeps the expanding container window
                  // transparent so the live OpenGL video plays inside it.
                  Positioned.fill(
                    child: ClipPath(
                      clipper: _InvertedRRectClipper(activeRect, activeRadius),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          StreetviewMapScene(
                            settings: settings,
                            dark: project.darkOutput,
                            thumbnail: const SizedBox(),
                            showThumbnail: false,
                          ),
                          if (scrimAlpha > 0)
                            ColoredBox(
                              color: Colors.black.withValues(alpha: scrimAlpha),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (borderAlpha > 0)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _ContainerBorderPainter(
                            activeRect,
                            activeRadius,
                            borderAlpha,
                          ),
                        ),
                      ),
                    ),
                  if (clip.streetview.showArrows)
                    Positioned.fromRect(
                      rect: activeRect,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(activeRadius),
                        child: Opacity(
                          opacity: chromeOpacity,
                          child: FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                              width: 360,
                              height: 640,
                              child: media(clip, elapsed, pixels: false),
                            ),
                          ),
                        ),
                      ),
                    ),
                ] else
                  Positioned.fill(
                    child: movement
                        ? transition()
                        : media(clip, elapsed, pixels: false),
                  ),
              ],
              if (!map)
                Positioned.fill(
                  child: Opacity(
                    opacity: chromeOpacity,
                    child: StreetviewChrome(
                      settings: settings,
                      dark: project.darkOutput,
                      sheetOffset: sheetOffset,
                    ),
                  ),
                ),
              if (ripple >= 0 && ripple < 1)
                if (map)
                  Positioned.fromRect(
                    rect: thumbRect,
                    child: M3InkRipple(
                      progress: ripple,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  )
                else if (isBack)
                  Positioned(
                    right: 12,
                    top: 20,
                    width: 30,
                    height: 30,
                    child: M3InkRipple(
                      progress: ripple,
                      borderRadius: BorderRadius.circular(15),
                    ),
                  )
                else
                  Positioned(
                    left: arrow.x - 32,
                    top: arrow.y - 32,
                    width: 64,
                    height: 64,
                    child: M3InkRipple(progress: ripple, softEdge: true),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InvertedRRectClipper extends CustomClipper<Path> {
  final Rect rect;
  final double radius;
  const _InvertedRRectClipper(this.rect, this.radius);

  @override
  Path getClip(Size size) => Path()
    ..fillType = PathFillType.evenOdd
    ..addRect(Offset.zero & size)
    ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));

  @override
  bool shouldReclip(_InvertedRRectClipper old) =>
      rect != old.rect || radius != old.radius;
}

class _ContainerBorderPainter extends CustomPainter {
  final Rect rect;
  final double radius;
  final double alpha;
  const _ContainerBorderPainter(this.rect, this.radius, this.alpha);

  @override
  void paint(Canvas canvas, Size size) {
    if (alpha <= 0) return;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = Colors.white.withValues(alpha: (0.6 * alpha).clamp(0.0, 1.0))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(_ContainerBorderPainter old) =>
      rect != old.rect || radius != old.radius || alpha != old.alpha;
}
