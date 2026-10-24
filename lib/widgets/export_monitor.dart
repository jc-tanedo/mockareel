import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum ExportPhase { preparing, encoding, finishing }

/// A shared export workspace. The scene preview uses still media, so it never
/// opens a competing video decoder while the native encoder is running.
class ExportMonitor extends StatefulWidget {
  final String title, status, format;
  final ExportPhase phase;
  final double? progress;
  final double position, duration;
  final Widget preview;
  final VoidCallback? onCancel;
  const ExportMonitor({
    super.key,
    required this.title,
    required this.status,
    required this.phase,
    required this.progress,
    required this.position,
    required this.duration,
    required this.preview,
    this.format = 'H.264 · 1080 × 1920 · 30 fps',
    this.onCancel,
  });

  @override
  State<ExportMonitor> createState() => _ExportMonitorState();
}

class _ExportMonitorState extends State<ExportMonitor> {
  final _clock = Stopwatch()..start();
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _clock.stop();
    super.dispose();
  }

  static String _time(double seconds) {
    final total = seconds.floor();
    return '${total ~/ 60}:${(total % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => Material(
    color: ink,
    child: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                const Icon(Icons.video_settings_rounded, color: mint, size: 22),
                const SizedBox(width: 10),
                Text('Export', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                const Text(
                  '1 JOB',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 700;
                final previewHeight = wide
                    ? (constraints.maxHeight - 64).clamp(160.0, 480.0)
                    : (constraints.maxHeight * .43).clamp(120.0, 310.0);
                final scene = Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: previewHeight,
                      child: AspectRatio(
                        aspectRatio: 9 / 16,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: ColoredBox(
                            color: Colors.black,
                            child: widget.preview,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'SCENE PREVIEW · ${_time(widget.position)} / ${_time(widget.duration)}',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                );
                final job = _job(context);
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: wide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(child: scene),
                                const SizedBox(width: 28),
                                Expanded(child: job),
                              ],
                            )
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                scene,
                                const SizedBox(height: 24),
                                job,
                              ],
                            ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );

  Widget _job(BuildContext context) {
    final value = widget.progress?.clamp(0.0, 1.0);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.movie_outlined,
                  color: Colors.white54,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.format,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          i < widget.phase.index
                              ? Icons.check_circle
                              : Icons.circle,
                          size: 8,
                          color: i <= widget.phase.index
                              ? mint
                              : Colors.white24,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            ['Prepare', 'Encode', 'Finish'][i],
                            style: TextStyle(
                              fontSize: 11,
                              color: i == widget.phase.index
                                  ? mint
                                  : Colors.white38,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 18),
            Text(
              widget.status,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 4,
                color: mint,
                backgroundColor: Colors.white10,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'Elapsed ${_time(_clock.elapsedMilliseconds / 1000)}',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
                const Spacer(),
                Text(
                  value == null ? 'Starting…' : '${(value * 100).floor()}%',
                  style: const TextStyle(
                    color: mint,
                    fontSize: 12,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Keep Mockareel open',
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ),
                TextButton.icon(
                  onPressed: widget.onCancel,
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Cancel export'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
