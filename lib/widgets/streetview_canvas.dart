import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../model/project.dart';
import '../model/streetview_timeline.dart';
import 'media_frame.dart';
import 'story_tags.dart';

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
    final scene = StreetviewTimeline.at(project, position);
    final i = scene.mediaIndex;
    final clip = project.clips[i];
    final settings = clip.streetview;
    final elapsed = scene.elapsed(position);
    final map = scene.kind == 'map' || scene.kind == 'ending-map';
    final movement = scene.kind == 'arrow';
    final ripple = scene.kind == 'back'
        ? (elapsed - scene.duration + StreetviewTimeline.rippleSeconds) /
              StreetviewTimeline.rippleSeconds
        : map && scene.kind != 'ending-map'
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
    final dark = project.darkOutput;
    final surface = dark ? const Color(0xff202124) : Colors.white;
    final ink = dark ? Colors.white : const Color(0xff202124);
    Widget image(ReelClip c, double seconds) => ClipPoster(
      clip: c,
      position: seconds,
      resolvedPath: posters['${c.id}:end'] != null && seconds > 0
          ? posters['${c.id}:end']
          : posters[c.id],
    );
    Widget media({ReelClip? source, double? localSeconds}) {
      if (movement && source == null) {
        final direction = settings.arrow == 'left' ? -1.0 : 1.0;
        return ColoredBox(
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
                      child: media(source: clip, localSeconds: clip.duration),
                    ),
                  ),
                  Opacity(
                    opacity: t,
                    child: Transform.translate(
                      offset: Offset(direction * 130 * (1 - t), 0),
                      child: Transform.scale(
                        scale: 1 + (1 - t) * .25,
                        child: media(
                          source: project.clips[i + 1],
                          localSeconds: 0,
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
      final current = source ?? clip;
      final seconds =
          localSeconds ?? (scene.kind == 'back' ? clip.duration : elapsed);
      final pan = current.streetview.panZoom
          ? seconds / max(.001, current.duration)
          : 0.0;
      return ClipRect(
        child: Transform.translate(
          offset: Offset(-pan * 8, 0),
          child: Transform.scale(
            scale: 1 + pan * .06,
            child: posterOnly
                ? image(current, seconds)
                : MediaFrame(
                    key: ValueKey(current.id),
                    clip: current,
                    position: seconds,
                    playing:
                        playing &&
                        scene.kind == 'media' &&
                        current.id == clip.id &&
                        position < project.duration,
                  ),
          ),
        ),
      );
    }

    final direction = settings.arrow == 'left' ? -1.0 : 1.0;
    final children = <Widget>[
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
                      key: ValueKey('streetview-player-${project.clips[j].id}'),
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
                                ? direction * 130 * (j == i ? -t : 1 - t)
                                : 0,
                            0,
                          ),
                          child: Transform.scale(
                            scale: movement
                                ? 1 + .25 * (j == i ? t : 1 - t)
                                : 1,
                            child: media(
                              source: project.clips[j],
                              localSeconds: j < i
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
      if (map) ...[
        Positioned.fill(child: ColoredBox(color: surface)),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: 370,
          child: settings.mapPath == null
              ? const ColoredBox(color: Color(0xffdfe6dd))
              : Image.file(File(settings.mapPath!), fit: BoxFit.contain),
        ),
        Positioned(
          left: 12,
          right: 12,
          top: 30,
          child: Material(
            color: surface,
            borderRadius: BorderRadius.circular(28),
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(Icons.arrow_back, color: ink, size: 20),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      settings.place.name,
                      style: TextStyle(color: ink, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.close, color: ink, size: 20),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 370,
          bottom: 0,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    settings.place.name,
                    maxLines: 2,
                    style: TextStyle(
                      color: ink,
                      fontSize: 23,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    [
                      settings.place.rating,
                      settings.place.category,
                    ].where((s) => s.isNotEmpty).join(' · '),
                    style: TextStyle(color: ink, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    settings.place.address,
                    maxLines: 2,
                    style: TextStyle(color: ink, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (final action in settings.place.actions.take(4))
                        Column(
                          children: [
                            Icon(
                              placeActionIcon(action.kind),
                              color: const Color(0xff1a73e8),
                              size: 22,
                            ),
                            Text(
                              action.label,
                              style: const TextStyle(
                                color: Color(0xff1a73e8),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 16,
          top: 235,
          width: 100,
          height: 110,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                image(clip, 0),
                const Align(
                  alignment: Alignment.bottomCenter,
                  child: ColoredBox(
                    color: Colors.black54,
                    child: Padding(
                      padding: EdgeInsets.all(5),
                      child: Text(
                        'Street View',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ] else ...[
        if ((movement && overlayOnly) || (overlayOnly && scene.kind == 'back'))
          Positioned.fill(child: media()),
        if (settings.showControls) ...[
          Positioned(left: 12, top: 28, child: _control(Icons.arrow_back)),
          Positioned(right: 12, top: 28, child: _control(Icons.more_vert)),
          Positioned(
            right: 12,
            top: 80,
            child: _control(Icons.explore_outlined),
          ),
        ],
        if (settings.showArrows) ...[
          Positioned(
            left: 100,
            top: 430,
            child: _control(Icons.chevron_left, size: 44),
          ),
          Positioned(
            right: 100,
            top: 430,
            child: _control(Icons.chevron_right, size: 44),
          ),
        ],
        if (settings.showLocation)
          Positioned(
            left: 12,
            right: 12,
            bottom: 30,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      settings.place.address.isEmpty
                          ? settings.place.name
                          : settings.place.address,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (settings.date.isNotEmpty)
                      Text(
                        settings.date,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: ink, fontSize: 11),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
      Positioned(
        left: 12,
        bottom: 8,
        right: 12,
        child: Text(
          settings.attribution,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: map ? ink : Colors.white,
            fontSize: 10,
            shadows: const [Shadow(blurRadius: 2, color: Colors.black54)],
          ),
        ),
      ),
      if (ripple >= 0 && ripple < 1)
        Positioned(
          left: map
              ? 66
              : scene.kind == 'back'
              ? 32
              : settings.arrow == 'left'
              ? 130
              : 230,
          top: map
              ? 290
              : scene.kind == 'back'
              ? 48
              : 460,
          child: _Ripple(progress: ripple),
        ),
    ];
    return FittedBox(
      child: SizedBox(
        width: 360,
        height: 640,
        child: DefaultTextStyle(
          style: const TextStyle(fontFamily: 'Roboto'),
          child: Stack(clipBehavior: Clip.hardEdge, children: children),
        ),
      ),
    );
  }

  Widget _control(IconData icon, {double size = 24}) => DecoratedBox(
    decoration: const BoxDecoration(
      color: Colors.black45,
      shape: BoxShape.circle,
    ),
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Icon(icon, color: Colors.white, size: size),
    ),
  );
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
