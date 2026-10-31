import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import '../services/native_renderer.dart';

class ExportedVideoPage extends StatefulWidget {
  final String path;
  final NativeRenderer renderer;
  const ExportedVideoPage({
    super.key,
    required this.path,
    required this.renderer,
  });
  @override
  State<ExportedVideoPage> createState() => _ExportedVideoPageState();
}

class _ExportedVideoPageState extends State<ExportedVideoPage> {
  late final _controller = VideoPlayerController.file(File(widget.path));
  String? _error;
  bool _saved = false, _saving = false;
  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    try {
      await _controller.initialize();
      await _controller.setLooping(true);
      if (mounted) {
        setState(() {});
        await _controller.play();
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'The video was exported but playback could not start. You can still share or save it.',
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Your reel is ready')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: _error != null
                      ? Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  size: 40,
                                  color: colors.primary,
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  _error!,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colors.onSurfaceVariant,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : !_controller.value.isInitialized
                      ? const CircularProgressIndicator()
                      : GestureDetector(
                          onTap: () {
                            setState(() {
                              _controller.value.isPlaying
                                  ? _controller.pause()
                                  : _controller.play();
                            });
                          },
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: colors.outlineVariant.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: AspectRatio(
                                aspectRatio: _controller.value.aspectRatio,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    VideoPlayer(_controller),
                                    if (!_controller.value.isPlaying)
                                      Container(
                                        width: 56,
                                        height: 56,
                                        decoration: BoxDecoration(
                                          color: colors.surface.withValues(
                                            alpha: 0.75,
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.play_arrow_rounded,
                                          size: 34,
                                          color: colors.onSurface,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    try {
                      await SharePlus.instance.share(
                        ShareParams(
                          files: [XFile(widget.path, mimeType: 'video/mp4')],
                          subject: 'My Mockareel',
                        ),
                      );
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Could not open the share sheet. Try saving to gallery.',
                            ),
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Share video'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _saving || _saved
                      ? null
                      : () async {
                          setState(() => _saving = true);
                          try {
                            await widget.renderer.saveToGallery(widget.path);
                            if (mounted) setState(() => _saved = true);
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    e is PlatformException
                                        ? e.message ?? 'Save failed'
                                        : e.toString(),
                                  ),
                                ),
                              );
                            }
                          } finally {
                            if (mounted) setState(() => _saving = false);
                          }
                        },
                  icon: Icon(_saved ? Icons.check : Icons.save_alt),
                  label: Text(
                    _saved
                        ? 'Saved to Movies/Mockareel'
                        : _saving
                        ? 'Saving…'
                        : 'Save to gallery',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
