import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../model/project.dart';
import '../services/native_renderer.dart';
import '../services/gif_videos.dart';

class MediaFrame extends StatefulWidget {
  final ReelClip clip;
  final double position;
  final bool playing;
  final Future<String> Function(ReelClip)? gifVideoBuilder;
  const MediaFrame({
    super.key,
    required this.clip,
    this.position = 0,
    this.playing = false,
    this.gifVideoBuilder,
  });
  @override
  State<MediaFrame> createState() => _MediaFrameState();
}

class _MediaFrameState extends State<MediaFrame> {
  VideoPlayerController? _video;
  String? _error;
  int _generation = 0;
  String _loadedStamp = '';
  String get _gifStamp =>
      '${widget.clip.path}:${widget.clip.trimStart}:${widget.clip.duration}:${widget.clip.loopGif}';
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    _loadedStamp = _gifStamp;
    final previous = _video;
    _video = null;
    await previous?.dispose();
    _error = null;
    if (!widget.clip.isTimed) return;
    VideoPlayerController? controller;
    try {
      if (widget.clip.isGif) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        if (!mounted || generation != _generation) return;
      }
      final source = widget.clip.isGif
          ? await (widget.gifVideoBuilder?.call(widget.clip) ??
                GifVideos.instance.video(widget.clip))
          : widget.clip.path;
      if (!mounted || generation != _generation) return;
      controller = VideoPlayerController.file(
        File(source),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
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
      await controller?.dispose();
      if (mounted && generation == _generation) {
        setState(
          () => _error =
              'This animation could not be opened. Try a shorter duration or replace it.',
        );
      }
    }
  }

  Future<void> _sync({bool force = false}) async {
    final controller = _video;
    if (controller == null || !controller.value.isInitialized) return;
    final target =
        (widget.clip.isGif ? 0 : widget.clip.trimStart) +
        widget.position.clamp(0, widget.clip.duration - .001);
    if (force ||
        !widget.playing ||
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
    if (oldWidget.clip.id != widget.clip.id ||
        (widget.clip.isGif && _loadedStamp != _gifStamp)) {
      _load();
    } else {
      _sync(force: oldWidget.playing != widget.playing);
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
        child: Text(
          _error ?? 'Media is unavailable. Replace this clip.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70),
        ),
      ),
    );
    if (_error != null) return error;
    if (!widget.clip.isTimed) {
      return ClipRect(
        child: Transform.scale(
          scale: widget.clip.zoom,
          alignment: Alignment(widget.clip.panX, 0),
          child: Image.file(
            File(widget.clip.path),
            fit: BoxFit.cover,
            alignment: Alignment(widget.clip.panX, 0),
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, __, ___) => error,
          ),
        ),
      );
    }
    final controller = _video;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return ClipRect(
      child: SizedBox.expand(
        child: Transform.scale(
          scale: widget.clip.zoom,
          alignment: Alignment(widget.clip.panX, 0),
          child: FittedBox(
            fit: BoxFit.cover,
            alignment: Alignment(widget.clip.panX, 0),
            child: SizedBox(
              width: controller.value.size.width,
              height: controller.value.size.height,
              child: VideoPlayer(controller),
            ),
          ),
        ),
      ),
    );
  }
}

class ClipPoster extends StatefulWidget {
  final ReelClip clip;
  final double position;
  final bool applyCrop;
  final String? resolvedPath;
  const ClipPoster({
    super.key,
    required this.clip,
    this.position = 0,
    this.applyCrop = true,
    this.resolvedPath,
  });
  @override
  State<ClipPoster> createState() => _ClipPosterState();
}

class _ClipPosterState extends State<ClipPoster> {
  late Future<String> _path;
  String _stamp = '';
  String get _currentStamp =>
      '${widget.clip.path}:${widget.clip.trimStart}:${widget.position}:${widget.resolvedPath}:${widget.clip.isGif}:${widget.clip.duration}:${widget.clip.loopGif}';
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _stamp = _currentStamp;
    final stamp = _stamp;
    _path = () async {
      if (widget.resolvedPath != null) return widget.resolvedPath!;
      if (widget.clip.isGif) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        if (!mounted || stamp != _stamp) return widget.clip.path;
      }
      return widget.clip.isTimed
          ? await NativeRenderer().poster(
              widget.clip,
              position: widget.position,
            )
          : widget.clip.path;
    }();
  }

  @override
  void didUpdateWidget(ClipPoster old) {
    super.didUpdateWidget(old);
    if (_stamp != _currentStamp) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<String>(
    future: _path,
    builder: (context, snapshot) {
      final fallback = ColoredBox(
        color: const Color(0xffd9e3e3),
        child: Center(
          child: Icon(
            widget.clip.isTimed
                ? Icons.videocam_outlined
                : Icons.image_outlined,
            color: const Color(0xff7a9294),
          ),
        ),
      );
      if (!snapshot.hasData) return fallback;
      final pan = widget.applyCrop ? widget.clip.panX : 0.0;
      return ClipRect(
        child: Transform.scale(
          scale: widget.applyCrop ? widget.clip.zoom : 1,
          alignment: Alignment(pan, 0),
          child: Image.file(
            File(snapshot.data!),
            fit: BoxFit.cover,
            alignment: Alignment(pan, 0),
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, __, ___) => fallback,
          ),
        ),
      );
    },
  );
}
