import 'dart:math';
import 'package:flutter/material.dart';

/// Deterministic Material 3 Expressive wavy progress indicator shared by the
/// Maps card timeline (mirrored natively in Kotlin ScrollOverlay.kt) and the
/// Editor ExportMonitor.
class M3WavyProgressPainter extends CustomPainter {
  final double progress;
  final double phase;
  final Color color;
  final Color? trackColor;
  final double strokeWidth;
  final double waveLength;
  final double waveAmplitude;

  const M3WavyProgressPainter({
    required this.progress,
    this.phase = 0.0,
    required this.color,
    this.trackColor,
    this.strokeWidth = 3.0,
    this.waveLength = 14.0,
    this.waveAmplitude = 1.2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final clamped = progress.isFinite ? progress.clamp(0.0, 1.0) : 0.0;
    final inset = strokeWidth / 2;
    final left = inset;
    final right = max(left, size.width - inset);
    final centerY = size.height / 2;

    final inactivePaint = Paint()
      ..color = trackColor ?? color.withValues(alpha: 0.24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final activeEnd = left + (right - left) * clamped;
    if (activeEnd < right) {
      canvas.drawLine(
        Offset(max(left, activeEnd), centerY),
        Offset(right, centerY),
        inactivePaint,
      );
    }

    final activeSpan = activeEnd - left;
    if (activeSpan <= 0.5) return;

    final activePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (activeSpan < 6.0 || waveAmplitude <= 0) {
      canvas.drawLine(
        Offset(left, centerY),
        Offset(activeEnd, centerY),
        activePaint,
      );
      return;
    }

    final path = Path()..moveTo(left, centerY);
    const step = 2.0;
    final steps = (activeSpan / step).ceil();
    for (var i = 1; i <= steps; i++) {
      final x = min(activeEnd, left + i * step);
      final distFromEnds = min(x - left, activeEnd - x);
      var env = (distFromEnds / 8.0).clamp(0.0, 1.0);
      env = env * env * (3.0 - 2.0 * env);
      final angle = (x - left) * 2 * pi / waveLength - phase;
      final y = centerY + sin(angle) * waveAmplitude * env;
      path.lineTo(x, y);
    }
    canvas.drawPath(path, activePaint);
  }

  @override
  bool shouldRepaint(M3WavyProgressPainter old) =>
      progress != old.progress ||
      phase != old.phase ||
      color != old.color ||
      trackColor != old.trackColor ||
      strokeWidth != old.strokeWidth ||
      waveLength != old.waveLength ||
      waveAmplitude != old.waveAmplitude;
}

class M3WavyProgressBar extends StatelessWidget {
  final double progress;
  final double phase;
  final Color? color;
  final Color? trackColor;
  final double strokeWidth;
  final double waveLength;
  final double waveAmplitude;

  const M3WavyProgressBar({
    super.key,
    required this.progress,
    this.phase = 0.0,
    this.color,
    this.trackColor,
    this.strokeWidth = 4.0,
    this.waveLength = 18.0,
    this.waveAmplitude = 2.0,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final height = max(strokeWidth + waveAmplitude * 2 + 2, 10.0);
    return SizedBox(
      width: double.infinity,
      height: height,
      child: CustomPaint(
        painter: M3WavyProgressPainter(
          progress: progress,
          phase: phase,
          color: color ?? scheme.primary,
          trackColor: trackColor ?? scheme.surfaceContainerHighest,
          strokeWidth: strokeWidth,
          waveLength: waveLength,
          waveAmplitude: waveAmplitude,
        ),
      ),
    );
  }
}
