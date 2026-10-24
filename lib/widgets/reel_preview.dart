import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../model/project.dart';
import '../model/feed.dart';
import 'feed_canvas.dart';
import '../model/template_layout.dart';
import 'media_frame.dart';
import 'place_overlay.dart';
import 'music_playback.dart';
import 'output_palette.dart';
export 'place_overlay.dart';

class TimelinePreview extends StatefulWidget {
  final ReelProject project;
  final int selected;
  final double maxHeight;
  final bool startAtBeginning;
  const TimelinePreview({
    super.key,
    required this.project,
    this.selected = 0,
    this.startAtBeginning = false,
    this.maxHeight = 420,
  });
  @override
  State<TimelinePreview> createState() => _TimelinePreviewState();
}

class _TimelinePreviewState extends State<TimelinePreview>
    with WidgetsBindingObserver {
  Timer? _timer;
  final _clock = Stopwatch();
  double _base = 0, _position = 0;
  bool get _playing => _timer != null;
  double get _duration => widget.project.isFeed
      ? FeedTimeline.duration(widget.project)
      : widget.project.duration;
  double get _selectedStart => widget.startAtBeginning
      ? 0
      : widget.project.isFeed
      ? FeedTimeline.postStart(widget.project, widget.selected) +
            (widget.project.clips.isEmpty
                ? 0
                : FeedTimeline.transition(widget.project, widget.selected))
      : widget.project.startOf(widget.selected) +
            TemplateLayout.transitionDuration(widget.project, widget.selected);
  void _pause() {
    _timer?.cancel();
    _timer = null;
    _clock.stop();
    if (mounted) setState(() {});
  }

  void _play() {
    if (widget.project.clips.isEmpty) return;
    if (_position >= _duration - .03) _position = 0;
    _base = _position;
    _clock.reset();
    _clock.start();
    _timer = Timer.periodic(const Duration(milliseconds: 40), (_) {
      if (!mounted) return;
      setState(
        () => _position = min(
          _duration,
          _base + _clock.elapsedMilliseconds / 1000,
        ),
      );
      if (_position >= _duration) _pause();
    });
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _position = _selectedStart;
  }

  @override
  void didUpdateWidget(TimelinePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected ||
        oldWidget.project.id != widget.project.id) {
      _pause();
      _position = _selectedStart;
    }
    _position = _position.clamp(0, _duration);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _pause();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.project;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (p.music != null)
          MusicPlayback(
            key: ValueKey(p.music!.path),
            track: p.music!,
            position: _position,
            playing: _playing,
          ),
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: widget.maxHeight),
            child: AspectRatio(
              aspectRatio: 9 / 16,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: ReelCanvas(
                  project: p,
                  position: _position,
                  playing: _playing,
                ),
              ),
            ),
          ),
        ),
        Row(
          children: [
            IconButton(
              tooltip: 'Restart preview',
              visualDensity: VisualDensity.compact,
              onPressed: p.clips.isEmpty
                  ? null
                  : () {
                      _pause();
                      setState(() => _position = 0);
                    },
              icon: const Icon(Icons.replay, size: 18),
            ),
            IconButton(
              tooltip: _playing ? 'Pause preview' : 'Play preview',
              onPressed: p.clips.isEmpty
                  ? null
                  : () => _playing ? _pause() : _play(),
              icon: Icon(
                _playing ? Icons.pause_circle_filled : Icons.play_circle_fill,
              ),
            ),
            Expanded(
              child: Slider(
                value: min(_position, _duration),
                max: max(.01, _duration),
                onChangeStart: (_) => _pause(),
                onChanged: p.clips.isEmpty
                    ? null
                    : (v) => setState(() => _position = v),
              ),
            ),
            Text(
              '${_position.toStringAsFixed(1)} / ${_duration.toStringAsFixed(1)}s',
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ],
    );
  }
}

class ReelCanvas extends StatelessWidget {
  final ReelProject project;
  final double position;
  final bool playing, overlayOnly, posterOnly, showTags, animateIntro;
  final String? heroPath;
  final Map<String, String> posters;
  const ReelCanvas({
    super.key,
    required this.project,
    this.position = 0,
    this.playing = false,
    this.overlayOnly = false,
    this.posterOnly = false,
    this.showTags = true,
    this.animateIntro = true,
    this.heroPath,
    this.posters = const {},
  });
  @override
  Widget build(BuildContext context) {
    if (project.isFeed) {
      return FeedCanvas(
        project: project,
        position: position,
        playing: playing,
        overlayOnly: overlayOnly,
        posterOnly: posterOnly,
        posters: posters,
      );
    }
    final index = project.clipAt(position);
    final sheetOffset = animateIntro
        ? TemplateLayout.sheetOffset(project, position)
        : 0.0;
    final starts = TemplateLayout.starts(project);
    final offset = TemplateLayout.offset(project, position);
    final visible = <Widget>[];
    if (!overlayOnly) {
      for (var i = max(0, index - 1); i < project.clips.length; i++) {
        final clip = project.clips[i];
        final x = starts[i] - offset,
            width = clip.cardWidth * TemplateLayout.galleryWidth;
        if (x >= TemplateLayout.galleryWidth) break;
        if (x + width <= 0) continue;
        final height = clip.cardHeight * TemplateLayout.galleryHeight;
        visible.add(
          Positioned(
            left: x,
            top: (TemplateLayout.galleryHeight - height) / 2,
            width: width,
            height: height,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(TemplateLayout.radius),
              child: i == index && !posterOnly
                  ? MediaFrame(
                      key: ValueKey('playing-${clip.id}'),
                      clip: clip,
                      position: (position - project.startOf(i)).clamp(
                        0,
                        clip.duration,
                      ),
                      playing: playing,
                    )
                  : ClipPoster(
                      key: ValueKey('poster-${clip.id}-${i < index}'),
                      clip: clip,
                      position: i < index ? clip.duration : 0,
                      resolvedPath: posters[clip.id],
                    ),
            ),
          ),
        );
      }
    }
    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: 360,
        height: 640,
        child: Stack(
          children: [
            if (!overlayOnly)
              Positioned(
                left: TemplateLayout.galleryLeft,
                top: TemplateLayout.galleryTop + sheetOffset,
                width: TemplateLayout.galleryWidth,
                height: TemplateLayout.galleryHeight,
                child: ClipRect(
                  child: ColoredBox(
                    color: OutputPalette(dark: project.darkOutput).surface,
                    child: Stack(
                      children: visible.isEmpty
                          ? [
                              const Center(
                                child: Icon(
                                  Icons.add_photo_alternate_outlined,
                                  size: 50,
                                  color: Color(0xff7a9294),
                                ),
                              ),
                            ]
                          : visible,
                    ),
                  ),
                ),
              ),
            Positioned.fill(
              child: PlaceOverlay(
                project: project,
                index: max(0, index),
                heroPath: heroPath,
                showTags: showTags,
                sheetOffset: sheetOffset,
              ),
            ),
            if (!overlayOnly && index >= 0)
              Positioned(
                left: TemplateLayout.galleryLeft,
                top:
                    TemplateLayout.galleryTop +
                    sheetOffset +
                    TemplateLayout.galleryHeight -
                    3,
                width: TemplateLayout.galleryWidth,
                height: 3,
                child: ClipRect(
                  child: Stack(
                    children: [
                      Positioned(
                        left: starts[index] - offset,
                        top: 0,
                        width:
                            project.clips[index].cardWidth *
                            TemplateLayout.galleryWidth *
                            ((position - project.startOf(index)) /
                                    project.clips[index].duration)
                                .clamp(0, 1),
                        height: 3,
                        child: ColoredBox(
                          color: OutputPalette(
                            dark: project.darkOutput,
                          ).progress,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
