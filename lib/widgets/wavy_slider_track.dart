import 'dart:math';
import 'package:flutter/material.dart';

/// A Material 3 Expressive wavy slider track shape inspired by Android 13/14+
/// media controls and dynamic playback seek bars.
class WavySliderTrackShape extends SliderTrackShape {
  final double waveLength;
  final double waveAmplitude;
  final double phase;
  final bool isWavy;

  const WavySliderTrackShape({
    this.waveLength = 20.0,
    this.waveAmplitude = 2.8,
    this.phase = 0.0,
    this.isWavy = true,
  });

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final trackHeight = sliderTheme.trackHeight ?? 4.0;
    final trackLeft = offset.dx + 12.0;
    final trackTop = offset.dy + (parentBox.size.height - trackHeight) / 2;
    final trackWidth = parentBox.size.width - 24.0;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 2,
  }) {
    final trackHeight = sliderTheme.trackHeight ?? 4.0;
    if (trackHeight <= 0) return;

    final trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );

    final canvas = context.canvas;
    final activeColor = isEnabled
        ? (sliderTheme.activeTrackColor ?? Colors.white)
        : (sliderTheme.disabledActiveTrackColor ?? Colors.white38);
    final inactiveColor = isEnabled
        ? (sliderTheme.inactiveTrackColor ?? Colors.white24)
        : (sliderTheme.disabledInactiveTrackColor ?? Colors.white12);

    final activePaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = trackHeight
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final inactivePaint = Paint()
      ..color = inactiveColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = trackHeight
      ..strokeCap = StrokeCap.round;

    final centerY = trackRect.center.dy;
    final activeEnd = thumbCenter.dx.clamp(trackRect.left, trackRect.right);

    // Draw active track (wavy if enabled and space permits)
    final activeSpan = activeEnd - trackRect.left;
    if (activeSpan > 0) {
      if (!isWavy || activeSpan < 8.0 || waveAmplitude <= 0) {
        canvas.drawLine(
          Offset(trackRect.left, centerY),
          Offset(activeEnd, centerY),
          activePaint,
        );
      } else {
        final path = Path();
        path.moveTo(trackRect.left, centerY);
        const step = 2.0;
        final steps = (activeSpan / step).ceil();
        for (var i = 1; i <= steps; i++) {
          final x = min(activeEnd, trackRect.left + i * step);
          final distFromEnds = min(x - trackRect.left, activeEnd - x);
          var env = (distFromEnds / 12.0).clamp(0.0, 1.0);
          env = env * env * (3.0 - 2.0 * env); // Smoothstep envelope
          final angle = (x - trackRect.left) * 2 * pi / waveLength - phase;
          final y = centerY + sin(angle) * waveAmplitude * env;
          path.lineTo(x, y);
        }
        canvas.drawPath(path, activePaint);
      }
    }

    // Draw inactive track (smooth straight line)
    if (activeEnd < trackRect.right) {
      canvas.drawLine(
        Offset(activeEnd, centerY),
        Offset(trackRect.right, centerY),
        inactivePaint,
      );
    }
  }
}
