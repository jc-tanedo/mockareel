import 'dart:math';
import 'm3_motion.dart';
import 'project.dart';
import 'streetview_layout.dart';

/// Camera coordinates are logical 360×640 pixels. The Android texture renderer
/// uses the same homography in normalized GL coordinates.
class StreetviewPose {
  final double scale, yaw, offsetX;
  const StreetviewPose(this.scale, this.yaw, this.offsetX);
  static const perspective = .0014;
  Point<double> project(double x, double y) {
    final centeredX = x - 180, centeredY = y - 320;
    final w = 1 - perspective * sin(yaw) * centeredX;
    return Point(
      180 + offsetX + scale * cos(yaw) * centeredX / w,
      320 + scale * centeredY / w,
    );
  }
}

abstract final class StreetviewMotion {
  static bool active(ReelClip c) =>
      (c.streetview.slowZoom && c.streetview.zoomAmount != 0) ||
      (c.streetview.slowPan && c.streetview.panAmount != 0) ||
      (c.streetview.turntable && c.streetview.turntableDegrees != 0);
  static double sample(double time, double duration) =>
      M3Motion.quantize(time, duration);
  static StreetviewPose at(ReelClip c, double seconds) {
    final s = c.streetview;
    final raw = (sample(seconds, c.duration) / max(.001, c.duration)).clamp(
      0.0,
      1.0,
    );
    final t = M3Motion.cameraEase(raw);
    final factor = s.turntableReverse ? (1.0 - 2.0 * t) : (2.0 * t - 1.0);
    final yaw = s.turntable ? s.turntableDegrees * pi / 180 * factor : 0.0;
    final offsetX = s.slowPan ? -s.panAmount * 360 * t : 0.0;
    final cover =
        (1 + (StreetviewPose.perspective * 180 * sin(yaw)).abs()) /
        cos(yaw).abs();
    final scale =
        (1 + (s.slowZoom ? s.zoomAmount * t : 0)) *
        cover *
        (1 + 2 * offsetX.abs() / 360);
    return StreetviewPose(scale, yaw, offsetX);
  }

  static Map<String, dynamic> native(ReelClip c) => {
    'zoom': c.streetview.slowZoom ? c.streetview.zoomAmount : 0.0,
    'pan': c.streetview.slowPan ? c.streetview.panAmount : 0.0,
    'turn': c.streetview.turntable ? c.streetview.turntableDegrees : 0.0,
    'turnReverse': c.streetview.turntable && c.streetview.turntableReverse,
  };
}

/// Deterministic M3 Container Transform geometry & decoupled fade choreography
/// shared by Streetview live preview, export cutouts, and Android OpenGL.
class StreetviewContainerState {
  final double left,
      top,
      width,
      height,
      radius,
      scrimAlpha,
      chromeOpacity,
      sheetOffset,
      borderAlpha;

  const StreetviewContainerState({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.radius,
    required this.scrimAlpha,
    required this.chromeOpacity,
    required this.sheetOffset,
    required this.borderAlpha,
  });
}

abstract final class StreetviewContainerMotion {
  static double backTapDuration(double duration) => min(0.18, duration * 0.35);

  static double arrowTapDuration(double duration) => min(0.18, duration * 0.32);

  static double backTapProgress(double elapsed, double duration) {
    final tapDur = backTapDuration(duration);
    return elapsed >= 0 && elapsed < tapDur
        ? (elapsed / max(.001, tapDur)).clamp(0.0, 1.0)
        : -1.0;
  }

  static StreetviewContainerState expandAt(double elapsed, double duration) {
    if (duration <= 0 || elapsed >= duration - 1e-9) {
      return const StreetviewContainerState(
        left: 0,
        top: 0,
        width: 360,
        height: 640,
        radius: 0,
        scrimAlpha: 0,
        chromeOpacity: 1,
        sheetOffset: 0,
        borderAlpha: 0,
      );
    }
    final q = M3Motion.quantize(elapsed, duration);
    final u = (q / max(.001, duration)).clamp(0.0, 1.0);
    final p = M3Motion.slowSpatial.eval(u);
    return StreetviewContainerState(
      left: M3Motion.lerp(StreetviewLayout.thumbnailLeft, 0.0, p),
      top: M3Motion.lerp(StreetviewLayout.thumbnailTop, 0.0, p),
      width: max(1.0, M3Motion.lerp(StreetviewLayout.thumbnailWidth, 360.0, p)),
      height: max(
        1.0,
        M3Motion.lerp(StreetviewLayout.thumbnailHeight, 640.0, p),
      ),
      radius: (12.0 * (1.0 - p)).clamp(0.0, 12.0),
      scrimAlpha:
          (0.34 * M3Motion.defaultEffects.eval((u / 0.55).clamp(0.0, 1.0)))
              .clamp(0.0, 1.0),
      chromeOpacity: M3Motion.fadeThroughIn(u),
      sheetOffset:
          18.0 *
          (1.0 -
              M3Motion.defaultSpatial.eval(
                ((u - 0.30) / 0.70).clamp(0.0, 1.0),
              )),
      borderAlpha:
          (1.0 - M3Motion.defaultEffects.eval((u / 0.75).clamp(0.0, 1.0)))
              .clamp(0.0, 1.0),
    );
  }

  static StreetviewContainerState shrinkAt(double elapsed, double duration) {
    final tapDur = backTapDuration(duration);
    final shrinkStart = tapDur * 0.65;
    final shrinkSpan = max(.001, duration - shrinkStart);
    final u = ((elapsed - shrinkStart) / shrinkSpan).clamp(0.0, 1.0);
    final p = M3Motion.slowSpatial.eval(u);
    return StreetviewContainerState(
      left: M3Motion.lerp(0.0, StreetviewLayout.thumbnailLeft, p),
      top: M3Motion.lerp(0.0, StreetviewLayout.thumbnailTop, p),
      width: max(1.0, M3Motion.lerp(360.0, StreetviewLayout.thumbnailWidth, p)),
      height: max(
        1.0,
        M3Motion.lerp(640.0, StreetviewLayout.thumbnailHeight, p),
      ),
      radius: (12.0 * p).clamp(0.0, 12.0),
      scrimAlpha: (0.34 * (1.0 - M3Motion.defaultEffects.eval(u))).clamp(
        0.0,
        1.0,
      ),
      chromeOpacity: M3Motion.fadeThroughOut(u),
      sheetOffset: 0,
      borderAlpha: M3Motion.defaultEffects.eval(u).clamp(0.0, 1.0),
    );
  }

  static Map<String, dynamic> nativeExpand(double duration) => {
    'duration': duration,
    'left': StreetviewLayout.thumbnailLeft,
    'top': StreetviewLayout.thumbnailTop,
    'width': StreetviewLayout.thumbnailWidth,
    'height': StreetviewLayout.thumbnailHeight,
  };
}
