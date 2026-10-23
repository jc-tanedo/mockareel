import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../model/project.dart';

/// Audio follows the reel clock, including scrubs and loops of the trimmed track.
class MusicPlayback extends StatefulWidget {
  final MusicTrack track;
  final double position;
  final bool playing;
  const MusicPlayback({
    super.key,
    required this.track,
    required this.position,
    required this.playing,
  });
  @override
  State<MusicPlayback> createState() => _MusicPlaybackState();
}

class _MusicPlaybackState extends State<MusicPlayback> {
  late final _controller = VideoPlayerController.file(
    File(widget.track.path),
    videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
  );
  bool _ready = false, _syncing = false, _again = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    unawaited(_open());
  }

  Future<void> _open() async {
    try {
      await _controller.initialize();
      if (!mounted) return;
      _ready = true;
      await _sync();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Music preview unavailable. Replace this audio file.',
        );
      }
    }
  }

  @override
  void didUpdateWidget(MusicPlayback oldWidget) {
    super.didUpdateWidget(oldWidget);
    unawaited(_sync());
  }

  Future<void> _sync() async {
    if (!_ready || !mounted) return;
    if (_syncing) {
      _again = true;
      return;
    }
    _syncing = true;
    try {
      do {
        _again = false;
        final m = widget.track;
        final remaining = m.sourceDuration - m.trimStart;
        if (remaining <= 0) {
          await _controller.pause();
          break;
        }
        final ended = !m.loop && widget.position >= remaining;
        final seconds =
            m.trimStart +
            (m.loop
                ? widget.position % remaining
                : widget.position.clamp(0, remaining));
        await _controller.setVolume(m.volume);
        if (!mounted) break;
        if ((_controller.value.position.inMilliseconds / 1000 - seconds).abs() >
                .25 ||
            !widget.playing) {
          await _controller.seekTo(
            Duration(milliseconds: (seconds * 1000).round()),
          );
        }
        if (!mounted) break;
        if (widget.playing && !ended) {
          await _controller.play();
        } else {
          await _controller.pause();
        }
      } while (_again && mounted);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Music preview unavailable. Replace this audio file.',
        );
      }
    } finally {
      _syncing = false;
    }
  }

  @override
  void dispose() {
    _ready = false;
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _error == null
      ? const SizedBox.shrink()
      : Text(
          _error!,
          style: const TextStyle(fontSize: 11, color: Colors.orangeAccent),
        );
}
