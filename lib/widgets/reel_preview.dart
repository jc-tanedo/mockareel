import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../model/project.dart';

/// The same overlay is rasterized for native video export, so the typography,
/// captions, scene counter, and place details in the MP4 match the preview.
class PlaceOverlay extends StatelessWidget {
  final ReelProject project;
  final int index;
  const PlaceOverlay({super.key, required this.project, this.index = 0});
  @override
  Widget build(BuildContext context) => FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
          width: 360,
          height: 640,
          child: Theme(
              data: ThemeData.light(useMaterial3: true),
              child: DefaultTextStyle(
                  style: const TextStyle(
                      color: Color(0xff202124), fontFamily: 'Roboto'),
                  child: Stack(children: [
                    Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: 92,
                        child: Container(
                            color: Colors.white,
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                            child: Column(children: [
                              Container(
                                  height: 42,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  decoration: BoxDecoration(
                                      color: const Color(0xfff1f3f4),
                                      borderRadius: BorderRadius.circular(24)),
                                  child: Row(children: [
                                    const Icon(Icons.arrow_back,
                                        size: 21, color: Color(0xff5f6368)),
                                    const SizedBox(width: 12),
                                    Expanded(
                                        child: Text(
                                            project.place.name.isEmpty
                                                ? 'Your next discovery'
                                                : project.place.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style:
                                                const TextStyle(fontSize: 14))),
                                    const Icon(Icons.close,
                                        size: 20, color: Color(0xff5f6368))
                                  ])),
                              const SizedBox(height: 12),
                              const Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    Text('Overview',
                                        style: TextStyle(
                                            color: Color(0xff1967d2),
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12)),
                                    Text('Reviews',
                                        style: TextStyle(fontSize: 12)),
                                    Text('Photos',
                                        style: TextStyle(fontSize: 12)),
                                    Text('About',
                                        style: TextStyle(fontSize: 12)),
                                  ]),
                            ]))),
                    if (project.clips.isNotEmpty)
                      Positioned(
                          top: 108,
                          right: 14,
                          child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(20)),
                              child: Text(
                                  '${index + 1} / ${project.clips.length}',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 11)))),
                    if (index >= 0 &&
                        index < project.clips.length &&
                        project.clips[index].caption.isNotEmpty)
                      Positioned(
                          left: 18,
                          right: 18,
                          bottom: 258,
                          child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(10)),
                              child: Text(project.clips[index].caption,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600)))),
                    Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: 246,
                        child: Container(
                            padding: const EdgeInsets.fromLTRB(20, 19, 20, 10),
                            decoration: const BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(20))),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      project.place.name.isEmpty
                                          ? 'Your place name'
                                          : project.place.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 23,
                                          fontWeight: FontWeight.w500,
                                          height: 1.12)),
                                  const SizedBox(height: 8),
                                  Row(children: [
                                    Text(
                                        project.place.rating.isEmpty
                                            ? '—'
                                            : project.place.rating,
                                        style: const TextStyle(fontSize: 12)),
                                    const SizedBox(width: 5),
                                    ...List.generate(
                                        5,
                                        (i) => Icon(
                                            i <
                                                    (double.tryParse(project
                                                                .place
                                                                .rating) ??
                                                            0)
                                                        .round()
                                                ? Icons.star
                                                : Icons.star_border,
                                            size: 14,
                                            color: const Color(0xfffbbc04))),
                                    const SizedBox(width: 6),
                                    const Text('Google Maps',
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: Color(0xff70757a)))
                                  ]),
                                  const SizedBox(height: 6),
                                  Text(
                                      project.place.category.isEmpty
                                          ? 'A place worth sharing'
                                          : project.place.category,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xff70757a))),
                                  const SizedBox(height: 16),
                                  Row(children: [
                                    for (final action in [
                                      (Icons.directions, 'Directions'),
                                      (Icons.bookmark_border, 'Save'),
                                      (Icons.share_outlined, 'Share')
                                    ])
                                      Expanded(
                                          child: Container(
                                              margin: const EdgeInsets.only(
                                                  right: 6),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 9),
                                              decoration: BoxDecoration(
                                                  color: action.$2 ==
                                                          'Directions'
                                                      ? const Color(0xff1967d2)
                                                      : Colors.white,
                                                  border: Border.all(
                                                      color: const Color(
                                                          0xffdadce0)),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          22)),
                                              child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Icon(action.$1,
                                                        size: 15,
                                                        color: action.$2 ==
                                                                'Directions'
                                                            ? Colors.white
                                                            : const Color(
                                                                0xff1967d2)),
                                                    const SizedBox(width: 4),
                                                    Flexible(
                                                        child: Text(action.$2,
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style: TextStyle(
                                                                fontSize: 10,
                                                                color: action
                                                                            .$2 ==
                                                                        'Directions'
                                                                    ? Colors
                                                                        .white
                                                                    : const Color(
                                                                        0xff1967d2),
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600)))
                                                  ]))),
                                  ]),
                                  const SizedBox(height: 13),
                                  Row(children: [
                                    const Icon(Icons.location_on_outlined,
                                        size: 18, color: Color(0xff70757a)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                        child: Text(project.place.address,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: Color(0xff5f6368))))
                                  ]),
                                ]))),
                  ])))));
}

class MediaFrame extends StatefulWidget {
  final ReelClip clip;
  final double position;
  final bool playing;
  const MediaFrame(
      {super.key, required this.clip, this.position = 0, this.playing = false});
  @override
  State<MediaFrame> createState() => _MediaFrameState();
}

class _MediaFrameState extends State<MediaFrame> {
  VideoPlayerController? _video;
  String? _error;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    final previous = _video;
    _video = null;
    await previous?.dispose();
    _error = null;
    if (!widget.clip.isVideo) return;
    final controller = VideoPlayerController.file(File(widget.clip.path));
    try {
      await controller.initialize();
      if (!mounted || generation != _generation) {
        await controller.dispose();
        return;
      }
      _video = controller;
      await controller.setVolume(0);
      await _sync(force: true);
      if (mounted) setState(() {});
    } catch (_) {
      await controller.dispose();
      if (mounted && generation == _generation) {
        setState(() =>
            _error = 'This video could not be opened. Replace it to continue.');
      }
    }
  }

  Future<void> _sync({bool force = false}) async {
    final controller = _video;
    if (controller == null || !controller.value.isInitialized) return;
    final target = widget.clip.trimStart + widget.position;
    if (force ||
        (controller.value.position.inMilliseconds / 1000 - target).abs() > .4) {
      await controller.seekTo(Duration(milliseconds: (target * 1000).round()));
    }
    if (!mounted || controller != _video) return;
    if (widget.playing && !controller.value.isPlaying) {
      await controller.play();
    } else if (!widget.playing && controller.value.isPlaying) {
      await controller.pause();
    }
  }

  @override
  void didUpdateWidget(MediaFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clip.id != widget.clip.id) {
      _load();
    } else {
      _sync();
    }
  }

  @override
  void dispose() {
    _generation++;
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final error = Center(
        child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_error ?? 'Media is unavailable. Replace this clip.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70))));
    if (_error != null) return error;
    if (!widget.clip.isVideo) {
      return ClipRect(
          child: Transform.scale(
              scale: 1 +
                  .04 * (widget.position / widget.clip.duration).clamp(0, 1),
              child: Image.file(File(widget.clip.path),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (_, __, ___) => error)));
    }
    final controller = _video;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return ClipRect(
        child: SizedBox.expand(
            child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                    width: controller.value.size.width,
                    height: controller.value.size.height,
                    child: VideoPlayer(controller)))));
  }
}

class TimelinePreview extends StatefulWidget {
  final ReelProject project;
  final int selected;
  const TimelinePreview({super.key, required this.project, this.selected = 0});
  @override
  State<TimelinePreview> createState() => _TimelinePreviewState();
}

class _TimelinePreviewState extends State<TimelinePreview>
    with WidgetsBindingObserver {
  Timer? _timer;
  final _clock = Stopwatch();
  double _base = 0, _position = 0;
  bool get _playing => _timer != null;
  void _pause() {
    _timer?.cancel();
    _timer = null;
    _clock.stop();
    if (mounted) setState(() {});
  }

  void _play() {
    if (widget.project.clips.isEmpty) return;
    if (_position >= widget.project.duration - .03) _position = 0;
    _base = _position;
    _clock.reset();
    _clock.start();
    _timer = Timer.periodic(const Duration(milliseconds: 40), (_) {
      if (!mounted) return;
      setState(() => _position = min(
          widget.project.duration, _base + _clock.elapsedMilliseconds / 1000));
      if (_position >= widget.project.duration) _pause();
    });
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _position = widget.project.startOf(widget.selected);
  }

  @override
  void didUpdateWidget(TimelinePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected ||
        oldWidget.project.id != widget.project.id) {
      _pause();
      _position = widget.project.startOf(widget.selected);
    }
    _position = _position.clamp(0, widget.project.duration);
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
    final index = p.clipAt(_position);
    return Column(children: [
      Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: AspectRatio(
                  aspectRatio: 9 / 16,
                  child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Stack(fit: StackFit.expand, children: [
                        const ColoredBox(color: Color(0xff233c43)),
                        if (index >= 0)
                          MediaFrame(
                              clip: p.clips[index],
                              position: (_position - p.startOf(index))
                                  .clamp(0, p.clips[index].duration),
                              playing: _playing),
                        if (index < 0)
                          const Center(
                              child: Icon(Icons.add_photo_alternate_outlined,
                                  color: Colors.white54, size: 54)),
                        PlaceOverlay(project: p, index: max(0, index)),
                      ]))))),
      Row(children: [
        IconButton(
            tooltip: _playing ? 'Pause preview' : 'Play preview',
            onPressed:
                p.clips.isEmpty ? null : () => _playing ? _pause() : _play(),
            icon: Icon(
                _playing ? Icons.pause_circle_filled : Icons.play_circle_fill)),
        Expanded(
            child: Slider(
                value: min(_position, p.duration),
                max: max(.01, p.duration),
                onChangeStart: (_) => _pause(),
                onChanged: p.clips.isEmpty
                    ? null
                    : (v) => setState(() => _position = v))),
        Text(
            '${_position.toStringAsFixed(1)} / ${p.duration.toStringAsFixed(1)}s',
            style: const TextStyle(fontSize: 11)),
      ]),
    ]);
  }
}
