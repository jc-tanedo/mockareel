import 'dart:math';

import 'package:flutter/material.dart';
import '../model/project.dart';
import '../model/streetview_3d_camera.dart';

/// World-space 3D road graphics (extruded chevrons, tap disc, road & cross-street
/// labels, and floating 3D POI pins) projected through [Camera3D].
class Streetview3dWorldOverlay extends StatelessWidget {
  final StreetviewMedia settings;
  final Camera3D camera;
  final double tapDiscProgress; // < 0 when inactive, 0..1 during tap
  final bool showChevrons;

  const Streetview3dWorldOverlay({
    super.key,
    required this.settings,
    this.camera = Camera3D.streetRest,
    this.tapDiscProgress = -1.0,
    this.showChevrons = true,
  });

  static String resolveRoadName(StreetviewMedia settings) {
    if (settings.roadLabel.trim().isNotEmpty) {
      return settings.roadLabel.trim();
    }
    final source = settings.streetviewTitle.isNotEmpty
        ? settings.streetviewTitle
        : settings.place.name.isNotEmpty
        ? settings.place.name
        : settings.place.address;
    if (source.isEmpty) return '';
    final cleaned = source.replaceFirst(RegExp(r'^\d+[\w-]*\s+'), '');
    return cleaned.split(',').first.trim();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _WorldOverlayPainter(
        settings: settings,
        roadName: resolveRoadName(settings),
        camera: camera,
        tapDiscProgress: tapDiscProgress,
        showChevrons: showChevrons,
      ),
    );
  }
}

class _WorldOverlayPainter extends CustomPainter {
  final StreetviewMedia settings;
  final String roadName;
  final Camera3D camera;
  final double tapDiscProgress;
  final bool showChevrons;

  const _WorldOverlayPainter({
    required this.settings,
    required this.roadName,
    required this.camera,
    required this.tapDiscProgress,
    required this.showChevrons,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (settings.showArrows) {
      if (tapDiscProgress >= 0 && tapDiscProgress < 1.0) {
        _paintTapDisc(canvas, size);
      }
      if (showChevrons) {
        _paintExtrudedChevron(
          canvas,
          size,
          center: const Vec3(-0.35, 0.04, 2.6),
          halfW: 0.72,
          halfD: 0.34,
          arm: 0.24,
          forward: false,
          yaw: 0,
        );
        final dirYaw = settings.railDirection == 'left'
            ? -0.65
            : settings.railDirection == 'right'
            ? 0.65
            : 0.0;
        _paintExtrudedChevron(
          canvas,
          size,
          center: const Vec3(-0.15, 0.04, 5.8),
          halfW: 0.68,
          halfD: 0.36,
          arm: 0.22,
          forward: true,
          yaw: dirYaw,
        );
      }
      _paintRoadLabel(canvas, size);
      if (settings.crossStreetLabel.trim().isNotEmpty && showChevrons) {
        _paintCrossStreet(canvas, size, settings.crossStreetLabel.trim());
      }
    }
    if (settings.showPoiPins && settings.poiLabels.isNotEmpty) {
      _paintPoiPins(canvas, size);
    }
  }

  void _paintTapDisc(Canvas canvas, Size size) {
    final alpha = (1.0 - tapDiscProgress).clamp(0.0, 1.0) * 0.52;
    final z = settings.railStop == 'far' ? 12.5 : 5.8;
    const r = 0.95;
    final path = Path();
    var valid = 0;
    for (var i = 0; i < 24; i++) {
      final a = (i / 24) * 2 * pi;
      final pt = camera.project(
        Vec3(-0.15 + cos(a) * r, 0.03, z + sin(a) * r),
        size,
      );
      if (pt == null) continue;
      if (valid == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
      valid++;
    }
    if (valid < 3) return;
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );
  }

  void _paintExtrudedChevron(
    Canvas canvas,
    Size size, {
    required Vec3 center,
    required double halfW,
    required double halfD,
    required double arm,
    required bool forward,
    required double yaw,
  }) {
    final s = forward ? 1.0 : -1.0;
    final localPts = <Vec3>[
      Vec3(-halfW, 0, -s * halfD),
      Vec3(0, 0, s * halfD),
      Vec3(halfW, 0, -s * halfD),
      Vec3(halfW - arm, 0, -s * halfD),
      Vec3(0, 0, s * (halfD - arm * 1.35)),
      Vec3(-halfW + arm, 0, -s * halfD),
    ];

    final cosY = cos(yaw);
    final sinY = sin(yaw);
    Vec3 toWorld(Vec3 p, double yOffset) {
      final rx = p.x * cosY + p.z * sinY;
      final rz = -p.x * sinY + p.z * cosY;
      return Vec3(center.x + rx, center.y + yOffset, center.z + rz);
    }

    final top2d = <Offset>[];
    final bot2d = <Offset>[];
    for (final p in localPts) {
      final t = camera.project(toWorld(p, 0.12), size);
      final b = camera.project(toWorld(p, 0.0), size);
      if (t == null || b == null) return;
      top2d.add(t);
      bot2d.add(b);
    }

    final topPath = Path()..addPolygon(top2d, true);
    final shadowPath = Path()..addPolygon(bot2d, true);
    canvas.drawPath(
      shadowPath.shift(const Offset(0, 2.5)),
      Paint()
        ..color = const Color(0x66000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0),
    );

    final bevelPaint = Paint()..color = const Color(0xff686a70);
    for (var i = 0; i < top2d.length; i++) {
      final next = (i + 1) % top2d.length;
      final side = Path()
        ..moveTo(top2d[i].dx, top2d[i].dy)
        ..lineTo(top2d[next].dx, top2d[next].dy)
        ..lineTo(bot2d[next].dx, bot2d[next].dy)
        ..lineTo(bot2d[i].dx, bot2d[i].dy)
        ..close();
      canvas.drawPath(side, bevelPaint);
    }
    canvas.drawPath(topPath, Paint()..color = const Color(0xfff5f6f8));
  }

  void _paintRoadLabel(Canvas canvas, Size size) {
    if (roadName.isEmpty) return;
    const anchor = Vec3(0.55, 0.02, 6.2);
    const farAnchor = Vec3(0.55, 0.02, 11.0);
    final pNear = camera.project(anchor, size);
    final pFar = camera.project(farAnchor, size);
    if (pNear == null || pFar == null) return;

    final scale = (camera.scaleAt(anchor, size) / 48.0).clamp(0.4, 3.2);
    final angle = atan2(pFar.dy - pNear.dy, pFar.dx - pNear.dx);

    canvas.save();
    canvas.translate(pNear.dx, pNear.dy);
    canvas.rotate(angle);
    canvas.scale(scale, scale * 0.72);
    _drawOutlinedText(canvas, roadName, 34, strokeWidth: 4.0);
    canvas.restore();
  }

  void _paintCrossStreet(Canvas canvas, Size size, String label) {
    const anchor = Vec3(3.2, 0.02, 9.5);
    final pt = camera.project(anchor, size);
    if (pt == null) return;
    final scale = (camera.scaleAt(anchor, size) / 48.0).clamp(0.5, 1.8);
    canvas.save();
    canvas.translate(pt.dx, pt.dy);
    canvas.scale(scale);
    _drawOutlinedText(canvas, label, 15, strokeWidth: 3.0);
    canvas.restore();
  }

  void _paintPoiPins(Canvas canvas, Size size) {
    const anchors = [
      Vec3(-4.8, 2.4, 11.0),
      Vec3(4.9, 2.6, 15.5),
      Vec3(-5.2, 2.5, 21.0),
    ];
    const badgeColors = [
      Color(0xffea8600),
      Color(0xff1a73e8),
      Color(0xff00897b),
    ];
    for (var i = 0; i < min(settings.poiLabels.length, anchors.length); i++) {
      final label = settings.poiLabels[i];
      if (label.isEmpty) continue;
      final w = anchors[i];
      final top = camera.project(w, size);
      final ground = camera.project(Vec3(w.x, 0, w.z), size);
      if (top == null || ground == null) continue;
      final scale = (camera.scaleAt(w, size) / 36.0).clamp(0.45, 1.4);

      canvas.drawLine(
        ground,
        top,
        Paint()
          ..color = Colors.white70
          ..strokeWidth = 1.5 * scale,
      );
      canvas.drawCircle(
        top,
        9 * scale,
        Paint()..color = badgeColors[i % badgeColors.length],
      );
      canvas.drawCircle(
        top,
        9 * scale,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 * scale,
      );
      canvas.save();
      canvas.translate(top.dx, top.dy - 14 * scale);
      canvas.scale(scale);
      _drawOutlinedText(canvas, label, 12, strokeWidth: 2.8, centered: true);
      canvas.restore();
    }
  }

  void _drawOutlinedText(
    Canvas canvas,
    String text,
    double fontSize, {
    double strokeWidth = 3.5,
    bool centered = false,
  }) {
    final stroke = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Roboto',
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth
            ..strokeJoin = StrokeJoin.round
            ..color = const Color(0xdd1b1b1b),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final fill = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Roboto',
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          color: const Color(0xf5ffffff),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final offset = centered
        ? Offset(-fill.width * 0.5, -fill.height)
        : Offset(0, -fill.height * 0.5);
    stroke.paint(canvas, offset);
    fill.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(_WorldOverlayPainter oldDelegate) =>
      camera.pos != oldDelegate.camera.pos ||
      camera.pitch != oldDelegate.camera.pitch ||
      camera.yaw != oldDelegate.camera.yaw ||
      tapDiscProgress != oldDelegate.tapDiscProgress ||
      showChevrons != oldDelegate.showChevrons ||
      roadName != oldDelegate.roadName;
}
