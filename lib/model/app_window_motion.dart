import 'dart:math';
import 'home_apps.dart';

class AppWindowFrame {
  final double progress, left, top, width, height, radius, opacity;
  const AppWindowFrame(
    this.progress,
    this.left,
    this.top,
    this.width,
    this.height,
    this.radius,
    this.opacity,
  );
  double get backdropScale => 1 + .05 * progress;
  double get backdropShade => .14 * progress;
}

/// Deterministic, critically damped window motion shared by preview and export.
/// Launch and dismissal have separate settling times; neither stretches the
/// app's contents or fades the window throughout its entire journey.
abstract final class AppWindowMotion {
  static const launchSeconds = .46, closeSeconds = .36;

  static double _spring(double seconds, double duration, double frequency) {
    if (seconds <= 0) return 0;
    if (seconds >= duration) return 1;
    double response(double t) => 1 - (1 + frequency * t) * exp(-frequency * t);
    return (response(seconds) / response(duration)).clamp(0, 1);
  }

  static AppWindowFrame at({
    required HomeIconPosition icon,
    required bool opening,
    required double elapsed,
    required double hold,
  }) {
    final p = opening
        ? _spring(elapsed - hold, launchSeconds, 20)
        : 1 - _spring(elapsed, closeSeconds, 24);
    final edge = ((p - .85) / .15).clamp(0.0, 1.0);
    final rounding = 1 - edge * edge * (3 - 2 * edge);
    return AppWindowFrame(
      p,
      icon.left * (1 - p),
      icon.top * (1 - p),
      icon.size + (360 - icon.size) * p,
      icon.size + (640 - icon.size) * p,
      (icon.radius + (30 - icon.radius) * p) * rounding,
      (p / .12).clamp(0, 1),
    );
  }
}
