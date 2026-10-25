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
  bool _syncing = false, _syncAgain = false, _forceSync = false;
  String get _gifStamp =>
      '${widget.clip.path}:${widget.clip.isGif}:${widget.clip.trimStart}:${widget.clip.duration}:${widget.clip.loopGif}';
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
      if (widget.clip.isGif && generation > 1) {
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
    _forceSync = _forceSync || force;
    _syncAgain = true;
    if (_syncing) return;
    _syncing = true;
    VideoPlayerController? active;
    try {
      do {
        _syncAgain = false;
        final controller = _video;
        active = controller;
        if (!mounted || controller == null || !controller.value.isInitialized) {
          break;
        }
        final generation = _generation;
        final forced = _forceSync;
        _forceSync = false;
        final clip = widget.clip;
        final play = widget.playing && widget.position < clip.duration;
        final last = clip.isGif
            ? ((clip.duration * 30).ceil() - 1) / 30
            : clip.duration - .001;
        final target =
            (clip.isGif ? 0 : clip.trimStart) +
            widget.position.clamp(0, last.clamp(0, clip.duration));
        // Seek at/before the last encoded GIF sample, not after it through
        // millisecond rounding. Compare in the same units as the native player.
        final desired = Duration(
          milliseconds: clip.isGif
              ? (target * 1000).floor()
              : (target * 1000).round(),
        );
        bool current() =>
            mounted && controller == _video && generation == _generation;
        // Pause before seeking a held frame. Serialize all operations so a late
        // play/seek cannot overtake the timeline's final pause.
        if (!play && (controller.value.isPlaying || forced)) {
          await controller.pause();
        }
        if (!current()) {
          _syncAgain = mounted;
          continue;
        }
        final delta =
            (controller.value.position.inMilliseconds - desired.inMilliseconds)
                .abs() /
            1000;
        final seek = forced || delta > (play ? .4 : .0005);
        if (seek) {
          await controller.seekTo(desired);
        }
        if (!current()) {
          _syncAgain = mounted;
          continue;
        }
        if (_syncAgain) continue;
        if (play && !controller.value.isPlaying) {
          await controller.play();
        } else if (!play && (controller.value.isPlaying || seek || forced)) {
          await controller.pause();
        }
      } while (_syncAgain && mounted);
    } catch (_) {
      if (mounted && active == _video) {
        setState(
          () => _error =
              'Preview playback could not update. Try restarting the preview.',
        );
      }
    } finally {
      _syncing = false;
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
