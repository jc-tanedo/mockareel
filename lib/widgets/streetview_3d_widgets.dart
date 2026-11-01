import 'package:flutter/material.dart';
import '../model/project.dart';

export 'streetview_3d_scenes.dart';

/// Compact 3D Street View bottom sheet matching Google Maps 3D Immersive View.
class Streetview3dPlaceSheet extends StatelessWidget {
  final StreetviewMedia settings;
  final bool dark;

  const Streetview3dPlaceSheet({
    super.key,
    required this.settings,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final ink = dark ? Colors.white : const Color(0xff202124);
    final linkColor = dark ? const Color(0xff8ab4f8) : const Color(0xff1a73e8);
    final title = settings.streetviewTitle.isNotEmpty
        ? settings.streetviewTitle
        : settings.place.name.isEmpty
        ? (settings.place.address.isNotEmpty
              ? settings.place.address
              : 'Dropped pin')
        : settings.place.name;
    final dateSubtitle = settings.date.isNotEmpty
        ? settings.date
        : '11 months ago';
    final moreDates = settings.moreDatesLabel.isNotEmpty
        ? settings.moreDatesLabel
        : 'See more dates';

    return Container(
      height: 88,
      decoration: BoxDecoration(
        color: dark ? const Color(0xf016181c) : const Color(0xf5ffffff),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 32,
              height: 3,
              margin: const EdgeInsets.only(top: 8, bottom: 8),
              decoration: BoxDecoration(
                color: dark ? Colors.white24 : Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              dateSubtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: dark ? Colors.white70 : Colors.black54,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          Text(
                            ' · ',
                            style: TextStyle(
                              color: dark ? Colors.white70 : Colors.black54,
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            '$moreDates >',
                            style: TextStyle(
                              color: linkColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: dark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.share_outlined, size: 18, color: ink),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Solid translucent circular tap disc on road surface.
class Streetview3dTapDisc extends StatelessWidget {
  final double progress; // 0.0 .. 1.0 fade/expand progress
  final String railStop;

  const Streetview3dTapDisc({
    super.key,
    required this.progress,
    this.railStop = 'near',
  });

  @override
  Widget build(BuildContext context) {
    final alpha = (1.0 - progress).clamp(0.0, 1.0) * 0.52;
    final isFar = railStop == 'far';
    final center = isFar ? const Offset(185, 345) : const Offset(172, 448);
    final discW = isFar ? 58.0 : 74.0;
    final discH = discW * 0.74;

    return Positioned(
      left: center.dx - discW / 2,
      top: center.dy - discH / 2,
      child: Container(
        width: discW,
        height: discH,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: alpha),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.white.withValues(alpha: alpha * 0.6),
              blurRadius: 4,
            ),
          ],
        ),
      ),
    );
  }
}

/// Perspective-rendered 3D on-rails road chevrons, vertical outlined street name,
/// and underfoot camera rush animation.
class Streetview3dRailOverlay extends StatelessWidget {
  final StreetviewMedia settings;
  final double transitionProgress; // 0.0 at rest, 0.0..1.0 during forward rush

  const Streetview3dRailOverlay({
    super.key,
    required this.settings,
    this.transitionProgress = 0.0,
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
    final roadName = resolveRoadName(settings);
    final crossStreet = settings.crossStreetLabel.trim();
    final t = transitionProgress.clamp(0.0, 1.0);

    final isMoving = t > 0.0;
    final roadOpacity = !isMoving
        ? 1.0
        : t <= 0.45
        ? (1.0 - (t / 0.45) * (t / 0.45)).clamp(0.0, 1.0)
        : t >= 0.82
        ? ((t - 0.82) / 0.18).clamp(0.0, 1.0)
        : 0.0;

    final roadTranslateY = !isMoving
        ? 0.0
        : t <= 0.45
        ? Curves.easeIn.transform(t / 0.45) * 160.0
        : 0.0;
    final roadTranslateX = !isMoving
        ? 0.0
        : t <= 0.45
        ? Curves.easeIn.transform(t / 0.45) * 26.0
        : 0.0;
    final roadScale = !isMoving
        ? 1.0
        : t <= 0.45
        ? 1.0 + (t / 0.45) * 0.65
        : 1.0;

    final chevronsVisible = !isMoving || t >= 0.85;
    final chevronOpacity = !isMoving
        ? 1.0
        : t >= 0.85
        ? ((t - 0.85) / 0.15).clamp(0.0, 1.0)
        : 0.0;

    final Matrix4 roadPerspective = Matrix4.identity()
      ..setEntry(3, 2, 0.0026)
      ..rotateX(1.08);

    return Stack(
      children: [
        // 3D Extruded Chevrons
        if (chevronsVisible)
          Positioned.fill(
            child: Opacity(
              opacity: chevronOpacity,
              child: const CustomPaint(painter: _ExtrudedRoadChevronPainter()),
            ),
          ),
        // Optional outlined cross-street name
        if (crossStreet.isNotEmpty && chevronsVisible)
          Positioned(
            right: 18,
            top: 410,
            child: Opacity(
              opacity: chevronOpacity,
              child: _OutlinedLabel(text: crossStreet, fontSize: 15),
            ),
          ),
        // Giant vertical outlined road name along the lane
        if (roadName.isNotEmpty && roadOpacity > 0)
          Positioned(
            left: 175 + roadTranslateX,
            top: 360 + roadTranslateY,
            child: Opacity(
              opacity: roadOpacity,
              child: Transform.scale(
                scale: roadScale,
                child: Transform(
                  transform: roadPerspective,
                  alignment: Alignment.center,
                  child: RotatedBox(
                    quarterTurns: 3,
                    child: _OutlinedLabel(
                      text: roadName,
                      fontSize: 42,
                      letterSpacing: -0.8,
                      strokeWidth: 4.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _OutlinedLabel extends StatelessWidget {
  final String text;
  final double fontSize;
  final double letterSpacing;
  final double strokeWidth;

  const _OutlinedLabel({
    required this.text,
    this.fontSize = 15,
    this.letterSpacing = 0.0,
    this.strokeWidth = 3.5,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Text(
          text,
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            letterSpacing: letterSpacing,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth
              ..strokeCap = StrokeCap.round
              ..strokeJoin = StrokeJoin.round
              ..color = const Color(0xdd1b1b1b),
          ),
        ),
        Text(
          text,
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            letterSpacing: letterSpacing,
            color: const Color(0xf5ffffff),
          ),
        ),
      ],
    );
  }
}

/// Custom painter for authentic 3D extruded road chevrons with drop shadow,
/// dark slate-gray bottom bevel, and crisp white top face.
class _ExtrudedRoadChevronPainter extends CustomPainter {
  const _ExtrudedRoadChevronPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final shadowPaint = Paint()
      ..color = const Color(0x66000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5);
    final bevelPaint = Paint()
      ..color = const Color(0xff686a70)
      ..style = PaintingStyle.fill;
    final facePaint = Paint()
      ..color = const Color(0xfff5f6f8)
      ..style = PaintingStyle.fill;

    void drawChevron({
      required Offset center,
      required double width,
      required double height,
      required double armThickness,
      required double bevelDepth,
      required bool forward,
    }) {
      final sign = forward ? -1.0 : 1.0;
      final apexY = center.dy - sign * height / 2;
      final wingY = center.dy + sign * height / 2;
      final notchY = apexY + sign * armThickness * 1.15;
      final leftWingX = center.dx - width / 2;
      final rightWingX = center.dx + width / 2;
      final innerLeftX = leftWingX + armThickness * 0.75;
      final innerRightX = rightWingX - armThickness * 0.75;

      final topFace = Path()
        ..moveTo(leftWingX, wingY)
        ..lineTo(center.dx, apexY)
        ..lineTo(rightWingX, wingY)
        ..lineTo(innerRightX, wingY)
        ..lineTo(center.dx, notchY)
        ..lineTo(innerLeftX, wingY)
        ..close();

      canvas.drawPath(topFace.shift(Offset(0, bevelDepth + 1.5)), shadowPaint);

      final bevelPath = Path();
      if (!forward) {
        bevelPath
          ..moveTo(leftWingX, wingY)
          ..lineTo(center.dx, apexY)
          ..lineTo(rightWingX, wingY)
          ..lineTo(rightWingX, wingY + bevelDepth)
          ..lineTo(center.dx, apexY + bevelDepth)
          ..lineTo(leftWingX, wingY + bevelDepth)
          ..close();
      } else {
        bevelPath
          ..moveTo(innerLeftX, wingY)
          ..lineTo(center.dx, notchY)
          ..lineTo(innerRightX, wingY)
          ..lineTo(innerRightX, wingY + bevelDepth)
          ..lineTo(center.dx, notchY + bevelDepth)
          ..lineTo(innerLeftX, wingY + bevelDepth)
          ..close();
      }
      canvas.drawPath(bevelPath, bevelPaint);
      canvas.drawPath(topFace, facePaint);
    }

    // Midground forward chevron (∧) at (172, 448)
    drawChevron(
      center: const Offset(172, 448),
      width: 58,
      height: 14,
      armThickness: 6.5,
      bevelDepth: 3.0,
      forward: true,
    );

    // Foreground backward chevron (∨) at (162, 538)
    drawChevron(
      center: const Offset(162, 538),
      width: 86,
      height: 28,
      armThickness: 12,
      bevelDepth: 5.0,
      forward: false,
    );
  }

  @override
  bool shouldRepaint(_ExtrudedRoadChevronPainter oldDelegate) => false;
}
