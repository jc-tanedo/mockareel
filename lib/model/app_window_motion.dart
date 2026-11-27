import 'dart:math';
import 'home_apps.dart';
import 'm3_motion.dart';

class AppWindowFrame {
  final double progress,
      left,
      top,
      width,
      height,
      radius,
      opacity,
      backdropEffects,
      iconPressScale,
      iconRippleProgress;
  const AppWindowFrame(
    this.progress,
    this.left,
    this.top,
    this.width,
    this.height,
    this.radius,
    this.opacity, {
    double? backdropEffects,
    this.iconPressScale = 1.0,
    this.iconRippleProgress = 0.0,
  }) : backdropEffects = backdropEffects ?? progress;

  double get backdropScale => 1 + .05 * backdropEffects;
  double get backdropShade => .18 * backdropEffects;
}

/// Deterministic Material 3 Expressive window motion shared by preview and
/// export. Spatial springs drive container geometry while critically damped
/// Effects springs drive opacity, scrim and wallpaper zoom without overshoot.
abstract final class AppWindowMotion {
  static const launchSeconds = .55, closeSeconds = .45, iconTapSeconds = .14;

  static AppWindowFrame at({
    required HomeIconPosition icon,
    required bool opening,
    required double elapsed,
    required double hold,
  }) {
    final u = opening
        ? ((elapsed - hold) / launchSeconds).clamp(0.0, 1.0)
        : (1.0 - (elapsed / closeSeconds).clamp(0.0, 1.0));
    final spatial = opening
        ? M3Motion.slowSpatial.eval(u)
        : (1.0 - M3Motion.defaultSpatial.eval(1.0 - u));
    final opacity = opening
        ? M3Motion.fastEffects.eval((u / 0.22).clamp(0.0, 1.0))
        : M3Motion.fastEffects.eval((u / 0.30).clamp(0.0, 1.0));
    final backdrop = M3Motion.slowEffects.eval(u);
    final edge = ((spatial - .85) / .15).clamp(0.0, 1.0);
    final rounding = 1 - edge * edge * (3 - 2 * edge);

    var iconPressScale = 1.0;
    var iconRippleProgress = 0.0;
    if (opening && hold > 0) {
      final tapSpan = min(iconTapSeconds, hold);
      final tapStart = hold - tapSpan;
      if (elapsed >= tapStart && elapsed < hold) {
        final tapU = ((elapsed - tapStart) / tapSpan).clamp(0.0, 1.0);
        iconRippleProgress = tapU;
        iconPressScale =
            1.0 - 0.08 * M3Motion.fastSpatial.eval(tapU).clamp(0.0, 1.12);
      }
    }

    return AppWindowFrame(
      spatial,
      icon.left * (1 - spatial),
      icon.top * (1 - spatial),
      max(1.0, icon.size + (360 - icon.size) * spatial),
      max(1.0, icon.size + (640 - icon.size) * spatial),
      max(0.0, (icon.radius + (30 - icon.radius) * spatial) * rounding),
      opacity.clamp(0.0, 1.0),
      backdropEffects: backdrop.clamp(0.0, 1.0),
      iconPressScale: iconPressScale,
      iconRippleProgress: iconRippleProgress,
    );
  }

  static Map<String, dynamic> native({
    required HomeIconPosition icon,
    required bool opening,
    required double hold,
  }) => {
    'opening': opening,
    'hold': hold,
    'iconLeft': icon.left,
    'iconTop': icon.top,
    'iconSize': icon.size,
  };
}
