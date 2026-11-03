import 'package:flutter/material.dart';
import 'export_monitor.dart';

class EditorExportOverlay extends StatelessWidget {
  final String title;
  final String status;
  final ExportPhase phase;
  final double? progress;
  final double position;
  final double duration;
  final String format;
  final Widget preview;
  final bool cancelled;
  final VoidCallback? onCancel;

  const EditorExportOverlay({
    super.key,
    required this.title,
    required this.status,
    required this.phase,
    required this.progress,
    required this.position,
    required this.duration,
    this.format = 'H.264 · 1080 × 1920 · 30 fps',
    required this.preview,
    required this.cancelled,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ExportMonitor(
        title: title,
        status: status,
        phase: phase,
        progress: progress,
        position: position,
        duration: duration,
        format: format,
        preview: IgnorePointer(child: preview),
        onCancel: cancelled || phase == ExportPhase.finishing ? null : onCancel,
      ),
    );
  }
}
