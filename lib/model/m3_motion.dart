import 'dart:math';

/// Analytical spring curve matching Material 3 Expressive motion physics.
/// Spatial springs use damping < 1.0 for subtle bounce; Effects springs use
/// damping >= 1.0 for monotonic, zero-overshoot fades and color transitions.
class M3Spring {
  final double damping;
  final double stiffness;
  final double naturalSeconds;

  const M3Spring(this.damping, this.stiffness, this.naturalSeconds);

  double eval(double progress) {
    if (!progress.isFinite || progress <= 0) return 0;
    if (progress >= 1) return 1;
    final t = progress * naturalSeconds;
    final w0 = sqrt(stiffness);
    if (damping >= 1.0) {
      double crit(double s) => 1.0 - (1.0 + w0 * s) * exp(-w0 * s);
      return (crit(t) / crit(naturalSeconds)).clamp(0.0, 1.0);
    }
    final k = sqrt(1.0 - damping * damping);
    final wd = w0 * k;
    final raw =
        1.0 -
        exp(-damping * w0 * t) * (cos(wd * t) + (damping / k) * sin(wd * t));
    if (progress <= 0.90) return raw;
    // C1 smoothstep tail-settle over the last 10% guarantees x(1) == 1.0
    // with zero visual snap regardless of slight residual oscillation.
    final s = (progress - 0.90) / 0.10;
    final blend = s * s * (3.0 - 2.0 * s);
    return raw * (1.0 - blend) + blend;
  }

  double at(double elapsed, double duration) =>
      duration <= 0 ? 1.0 : eval((elapsed / duration).clamp(0.0, 1.0));
}

/// Shared Material 3 Expressive motion tokens and 60 fps quantization clock.
/// Mirrored bit-for-bit in Android `M3Motion.kt`.
abstract final class M3Motion {
  static const int exportFps = 60;

  static const fastSpatial = M3Spring(0.6, 800.0, 0.35);
  static const defaultSpatial = M3Spring(0.8, 380.0, 0.50);
  static const slowSpatial = M3Spring(0.8, 200.0, 0.65);

  static const fastEffects = M3Spring(1.0, 3800.0, 0.15);
  static const defaultEffects = M3Spring(1.0, 1600.0, 0.25);
  static const slowEffects = M3Spring(1.0, 800.0, 0.35);

  static double cameraEase(double t) {
    final u = t.isFinite ? t.clamp(0.0, 1.0) : 0.0;
    return u * u * (3.0 - 2.0 * u);
  }

  static double quantize(double elapsed, double duration) =>
      min(
        max(0, (elapsed * exportFps).round()),
        max(0, (duration * exportFps).ceil() - 1),
      ) /
      exportFps;

  static double lerp(double a, double b, double t) => a + (b - a) * t;

  static double fadeThroughOut(double u) =>
      (1.0 - fastEffects.eval((u / 0.35).clamp(0.0, 1.0))).clamp(0.0, 1.0);

  static double fadeThroughIn(double u) =>
      defaultEffects.eval(((u - 0.35) / 0.65).clamp(0.0, 1.0)).clamp(0.0, 1.0);
}
