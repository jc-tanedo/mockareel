import 'dart:math';
import 'package:flutter/material.dart';
import '../model/m3_motion.dart';

/// Deterministic, frame-exact Material 3 clipped ink/sparkle ripple.
/// Driven purely by [progress] in [0, 1] so preview scrubbing and 60 fps
/// offscreen capture match without an active AnimationController.
class M3InkRipple extends StatelessWidget {
  final double progress;
  final BorderRadius borderRadius;
  final Color color;
  final bool softEdge;

  const M3InkRipple({
    super.key,
    required this.progress,
    this.borderRadius = BorderRadius.zero,
    this.color = Colors.white,
    this.softEdge = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!progress.isFinite || progress <= 0 || progress >= 1) {
      return const SizedBox.shrink();
    }
    final paint = CustomPaint(
      painter: _M3InkRipplePainter(
        progress: progress.clamp(0.0, 1.0),
        color: color,
        softEdge: softEdge,
      ),
      child: const SizedBox.expand(),
    );
    return softEdge
        ? paint
        : ClipRRect(borderRadius: borderRadius, child: paint);
  }
}

class _M3InkRipplePainter extends CustomPainter {
  final double progress;
  final Color color;
  final bool softEdge;

  const _M3InkRipplePainter({
    required this.progress,
    required this.color,
    required this.softEdge,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final center = size.center(Offset.zero);
    final maxR = sqrt(size.width * size.width + size.height * size.height) / 2;

    if (!softEdge) {
      final washIn = M3Motion.fastEffects.eval(
        (progress / 0.25).clamp(0.0, 1.0),
      );
      final washOut =
          1.0 -
          M3Motion.defaultEffects.eval(
            ((progress - 0.55) / 0.45).clamp(0.0, 1.0),
          );
      final washAlpha = (0.16 * washIn * washOut).clamp(0.0, 1.0);
      if (washAlpha > 0) {
        canvas.drawRect(
          Offset.zero & size,
          Paint()..color = color.withValues(alpha: washAlpha),
        );
      }
    }

    final radiusProgress = M3Motion.defaultSpatial
        .eval(progress)
        .clamp(0.0, 1.25);
    final radius = max(1.0, maxR * (0.18 + 1.0 * radiusProgress));
    final waveIn = M3Motion.fastEffects.eval((progress / 0.15).clamp(0.0, 1.0));
    final waveOut =
        1.0 -
        M3Motion.defaultEffects.eval(
          ((progress - 0.45) / 0.55).clamp(0.0, 1.0),
        );
    final waveAlpha = ((softEdge ? 0.50 : 0.36) * waveIn * waveOut).clamp(
      0.0,
      1.0,
    );
    if (waveAlpha <= 0) return;

    final rect = Rect.fromCircle(center: center, radius: radius);
    final shader = RadialGradient(
      colors: softEdge
          ? [
              color.withValues(alpha: waveAlpha),
              color.withValues(alpha: waveAlpha * 0.65),
              color.withValues(alpha: 0),
            ]
          : [
              color.withValues(alpha: waveAlpha * 0.35),
              color.withValues(alpha: waveAlpha),
              color.withValues(alpha: 0),
            ],
      stops: const [0.0, 0.72, 1.0],
    ).createShader(rect);
    canvas.drawCircle(center, radius, Paint()..shader = shader);

    // Subtle M3 InkSparkle shimmer flecks along the expanding wavefront.
    final sparkleAlpha = (waveAlpha * 0.7).clamp(0.0, 1.0);
    if (sparkleAlpha > 0.01) {
      final dotPaint = Paint()..color = color.withValues(alpha: sparkleAlpha);
      for (var i = 0; i < 16; i++) {
        final angle = i * (2 * pi / 16) + progress * 0.6;
        final jitter = 0.74 + 0.14 * sin(i * 2.7 + progress * 5.0);
        final r = radius * jitter;
        final dotSize = (i.isEven ? 1.5 : 1.0) * (1.0 - progress * 0.4);
        canvas.drawCircle(
          Offset(center.dx + cos(angle) * r, center.dy + sin(angle) * r),
          max(0.5, dotSize),
          dotPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_M3InkRipplePainter old) =>
      progress != old.progress ||
      color != old.color ||
      softEdge != old.softEdge;
}
