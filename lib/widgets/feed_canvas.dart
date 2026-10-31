import '../model/app_window_motion.dart';
import '../model/feed_timeline.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import '../model/project.dart';
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

  Widget _media(ReelClip c, double elapsed, {bool still = false, bool? play}) =>
      still || posterOnly
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
        );

  Widget _postLayer(
    ReelClip c,
    double elapsed, {
    AppWindowFrame? window,
    bool home = false,
    bool hold = false,
    double? top,
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
              child: Stack(
                children: [
                  if (!overlayOnly || home)
                    Positioned.fill(
                      child: _media(
                        c,
                        elapsed,
                        play: playing && !home && !hold,
                      ),
                    ),
                  Positioned.fill(child: FeedPostSurface(post: c.post)),
                  if (home)
                    Positioned.fill(child: FeedChrome(time: project.feed.time)),
                ],
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
        children.add(_postLayer(c, elapsed));
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
    } else {
      final home = f.homeMedia;
      final opening = s.kind == 'home-open';
      final window = AppWindowMotion.at(
        icon: f.launchIcon,
        opening: opening,
        elapsed: elapsed,
        hold: f.homeSeconds,
      );
      children.add(
        Positioned.fill(
          child: Stack(
            children: [
              if (!overlayOnly && home != null)
                Positioned.fill(child: _media(home, elapsed % home.duration)),
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
            ],
          ),
        ),
      );
      if (project.clips.isNotEmpty) {
        final c = project.clips[opening ? 0 : project.clips.length - 1];
        // Preload the opening video even while its app tile is invisible. The
        // same player and widget ancestry continue into/out of the feed scene.
        children.add(
          _postLayer(c, opening ? 0 : c.duration, window: window, home: true),
        );
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
