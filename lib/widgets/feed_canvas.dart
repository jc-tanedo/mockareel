import '../model/app_window_motion.dart';
import '../model/audio_mix.dart';
import '../model/feed_timeline.dart';
import '../model/m3_motion.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import '../model/project.dart';
import 'm3_ink_ripple.dart';
import 'media_frame.dart';
import 'home_surface.dart';
import 'feed_chrome.dart';
import 'feed_post_surface.dart';
import 'feed_search_surface.dart';

export 'home_surface.dart';
export 'phone_status.dart';
export 'feed_chrome.dart';
export 'feed_post_surface.dart';
export 'feed_search_surface.dart';

class FeedCanvas extends StatelessWidget {
  final ReelProject project;
  final double position;
  final bool playing, overlayOnly, posterOnly;
  final Map<String, String> posters;
  const FeedCanvas({
    super.key,
    required this.project,
    this.position = 0,
    this.playing = false,
    this.overlayOnly = false,
    this.posterOnly = false,
    this.posters = const {},
  });

  Widget _media(
    ReelClip c,
    double elapsed, {
    bool still = false,
    bool? play,
    bool mute = false,
  }) => still || posterOnly
      ? ClipPoster(
          clip: c,
          position: elapsed,
          resolvedPath:
              posters['${c.id}:${elapsed >= c.duration ? 'end' : 'start'}'],
        )
      : MediaFrame(
          key: ValueKey(c.id),
          clip: c,
          position: elapsed.clamp(0, max(0, c.duration - .001)),
          playing: play ?? playing,
          volume: mute ? 0 : AudioMix.clipVolume(project, c),
        );

  Widget _postLayer(
    ReelClip c,
    double elapsed, {
    AppWindowFrame? window,
    bool home = false,
    bool hold = false,
    bool hideMedia = false,
    bool? play,
    bool mute = false,
    double? top,
    double contentScale = 1.0,
  }) {
    return Positioned(
      key: ValueKey('post-${c.id}'),
      left: window?.left ?? 0,
      top:
          window?.top ??
          top ??
          FeedTimeline.entry(project, project.clips.indexOf(c), elapsed),
      width: window?.width ?? 360,
      height: window?.height ?? 640,
      child: Opacity(
        opacity: window?.opacity ?? 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(window?.radius ?? 0),
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: 360,
              height: 640,
              child: Transform.scale(
                scale: contentScale,
                child: Stack(
                  children: [
                    if (!hideMedia && (!overlayOnly || home))
                      Positioned.fill(
                        child: _media(
                          c,
                          elapsed,
                          play: play ?? (playing && !home && !hold),
                          mute: mute || home || hold,
                        ),
                      ),
                    Positioned.fill(child: FeedPostSurface(post: c.post)),
                    if (home)
                      Positioned.fill(
                        child: FeedChrome(time: project.feed.time),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = FeedTimeline.at(project, position), f = project.feed;
    final elapsed = (position - s.start).clamp(0.0, s.duration);
    final children = <Widget>[];
    if (s.kind == 'search') {
      children.add(
        Positioned.fill(
          child: SearchSurface(settings: f, elapsed: elapsed),
        ),
      );
    } else if (s.kind == 'post') {
      final i = s.postIndex;
      final entry = project.clips.isEmpty
          ? 0.0
          : FeedTimeline.entry(project, i, elapsed);
      final searchExit = i == 0
          ? FeedTimeline.searchExitDuration(project)
          : 0.0;
      final inSearchHandoff = searchExit > 0 && elapsed < searchExit;
      final searchU = inSearchHandoff
          ? (elapsed / searchExit).clamp(0.0, 1.0)
          : 1.0;
      final postScale = inSearchHandoff
          ? M3Motion.lerp(0.94, 1.0, M3Motion.defaultSpatial.eval(searchU))
          : 1.0;

      if (!overlayOnly) {
        children.add(
          const Positioned.fill(child: ColoredBox(color: Colors.black)),
        );
      }
      if (i > 0 && entry > 0) {
        final prev = project.clips[i - 1];
        if (!overlayOnly && !posterOnly) {
          children.add(
            _postLayer(prev, prev.duration, top: entry - 640, hold: true),
          );
        } else {
          children.add(
            Positioned(
              key: ValueKey('outgoing-${prev.id}'),
              left: 0,
              top: entry - 640,
              width: 360,
              height: 640,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _media(prev, prev.duration, still: true),
                  ),
                  Positioned.fill(child: FeedPostSurface(post: prev.post)),
                ],
              ),
            ),
          );
        }
      }
      if (project.clips.isNotEmpty) {
        final c = project.clips[i];
        children.add(_postLayer(c, elapsed, contentScale: postScale));
        if (!overlayOnly && !posterOnly && i + 1 < project.clips.length) {
          children.add(
            _postLayer(project.clips[i + 1], 0, top: 640, hold: true),
          );
        }
      } else {
        children.add(
          const Center(
            child: Icon(
              Icons.add_photo_alternate_outlined,
              color: Colors.white54,
              size: 48,
            ),
          ),
        );
      }
      children.add(
        Positioned.fill(
          child: FeedChrome(time: f.time, search: f.hasSearch ? f.search : ''),
        ),
      );
      if (inSearchHandoff) {
        final searchScale = M3Motion.lerp(
          1.0,
          1.06,
          M3Motion.defaultSpatial.eval(searchU),
        );
        final searchAlpha = (1.0 - M3Motion.defaultEffects.eval(searchU)).clamp(
          0.0,
          1.0,
        );
        if (searchAlpha > 0) {
          children.add(
            Positioned.fill(
              child: IgnorePointer(
                child: Opacity(
                  opacity: searchAlpha,
                  child: Transform.scale(
                    scale: searchScale,
                    child: SearchSurface(
                      settings: f,
                      elapsed: f.typingSeconds + f.loadingSeconds + elapsed,
                    ),
                  ),
                ),
              ),
            ),
          );
        }
      }
    } else {
      final home = f.homeMedia;
      final opening = s.kind == 'home-open';
      final window = AppWindowMotion.at(
        icon: f.launchIcon,
        opening: opening,
        elapsed: elapsed,
        hold: f.homeSeconds,
      );
      final windowClip = project.clips.isEmpty
          ? null
          : project.clips[opening ? 0 : project.clips.length - 1];
      final liveWindow =
          home == null && windowClip != null && windowClip.isTimed;
      Widget homeBackdrop() => Stack(
        children: [
          if (!overlayOnly && home != null)
            Positioned.fill(
              child: _media(home, elapsed % home.duration, mute: true),
            ),
          Positioned.fill(
            child: Transform.scale(
              scale: window.backdropScale,
              child: RepaintBoundary(
                child: HomeSurface(
                  settings: f,
                  transparentBackground: home != null,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black.withValues(alpha: window.backdropShade),
            ),
          ),
          if (f.showIcons && window.iconRippleProgress > 0)
            Positioned(
              key: const ValueKey('home-icon-ripple'),
              left: f.launchIcon.left,
              top: f.launchIcon.top,
              width: f.launchIcon.size,
              height: f.launchIcon.size,
              child: Transform.scale(
                scale: window.iconPressScale,
                child: M3InkRipple(
                  progress: window.iconRippleProgress,
                  borderRadius: BorderRadius.circular(f.launchIcon.radius),
                ),
              ),
            ),
        ],
      );
      final windowTime = windowClip == null
          ? 0.0
          : opening
          ? (liveWindow
                ? (elapsed - f.homeSeconds).clamp(0.0, windowClip.duration)
                : 0.0)
          : (liveWindow
                ? max(
                    0.0,
                    windowClip.duration -
                        AppWindowMotion.closeSeconds +
                        elapsed,
                  )
                : windowClip.duration);
      if (overlayOnly && liveWindow && window.opacity > 0) {
        final windowRect = Rect.fromLTWH(
          window.left,
          window.top,
          window.width,
          window.height,
        );
        children.add(
          Positioned.fill(
            child: ClipPath(
              clipper: _InvertedRRectClipper(windowRect, window.radius),
              child: homeBackdrop(),
            ),
          ),
        );
        if (window.opacity < 0.999) {
          children.add(
            Positioned.fill(
              child: ClipPath(
                clipper: _WindowRRectClipper(windowRect, window.radius),
                child: Opacity(
                  opacity: (1.0 - window.opacity).clamp(0.0, 1.0),
                  child: homeBackdrop(),
                ),
              ),
            ),
          );
        }
        children.add(
          _postLayer(
            windowClip,
            windowTime,
            window: window,
            home: true,
            hideMedia: true,
            mute: true,
          ),
        );
      } else {
        children.add(Positioned.fill(child: homeBackdrop()));
        if (windowClip != null) {
          children.add(
            _postLayer(
              windowClip,
              windowTime,
              window: window,
              home: true,
              mute: true,
            ),
          );
        }
      }
    }
    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: 360,
        height: 640,
        child: ClipRect(
          child: DefaultTextStyle(
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Roboto',
              fontSize: 13,
              decoration: TextDecoration.none,
            ),
            child: IconTheme(
              data: const IconThemeData(color: Colors.white),
              child: Stack(children: children),
            ),
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

class _WindowRRectClipper extends CustomClipper<Path> {
  final Rect rect;
  final double radius;
  const _WindowRRectClipper(this.rect, this.radius);

  @override
  Path getClip(Size size) =>
      Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));

  @override
  bool shouldReclip(_WindowRRectClipper old) =>
      rect != old.rect || radius != old.radius;
}
