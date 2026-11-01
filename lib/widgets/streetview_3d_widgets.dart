import 'dart:io';
import 'package:flutter/material.dart';
import '../model/project.dart';
import 'streetview_map_scene.dart';

/// Full-bleed opening aerial map scene for Streetview 3D.
class Streetview3dAerialScene extends StatelessWidget {
  final StreetviewMedia settings;
  final bool dark;
  final Widget? thumbnail;
  final VoidCallback? onStreetTap;

  const Streetview3dAerialScene({
    super.key,
    required this.settings,
    required this.dark,
    this.thumbnail,
    this.onStreetTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: ColoredBox(
            color: dark ? const Color(0xff15222e) : const Color(0xff233a54),
          ),
        ),
        if (settings.mapPath != null)
          Positioned.fill(
            child: Image.file(File(settings.mapPath!), fit: BoxFit.cover),
          ),
        // Top right close button
        Positioned(
          right: 14,
          top: 20,
          child: streetviewRoundButton(Icons.close, 'Close aerial view'),
        ),
        // Bottom left "Street" pill button
        Positioned(
          left: 14,
          bottom: 24,
          child: GestureDetector(
            onTap: onStreetTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xcc000000),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24, width: 0.5),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.directions_walk, color: Colors.white, size: 15),
                  SizedBox(width: 6),
                  Text(
                    'Street',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

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

/// Perspective-rendered 3D on-rails road chevrons and street name label.
class Streetview3dRailOverlay extends StatelessWidget {
  final StreetviewMedia settings;
  const Streetview3dRailOverlay({super.key, required this.settings});

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
    // Strip leading numbers if present (e.g. "296 Keilor Rd" -> "Keilor Rd")
    final cleaned = source.replaceFirst(RegExp(r'^\d+[\w-]*\s+'), '');
    return cleaned.split(',').first.trim();
  }

  @override
  Widget build(BuildContext context) {
    final roadName = resolveRoadName(settings);
    return Stack(
      children: [
        // Road surface canvas (chevrons and street name)
        Positioned.fill(
          child: CustomPaint(painter: _RailPainter(roadName: roadName)),
        ),
      ],
    );
  }
}

class _RailPainter extends CustomPainter {
  final String roadName;
  const _RailPainter({required this.roadName});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.88)
      ..style = PaintingStyle.fill;
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;

    void drawChevron(Offset center, double width, double height, bool forward) {
      final sign = forward ? -1.0 : 1.0;
      final path = Path()
        ..moveTo(center.dx - width / 2, center.dy + sign * height / 2)
        ..lineTo(center.dx, center.dy - sign * height / 2)
        ..lineTo(center.dx + width / 2, center.dy + sign * height / 2)
        ..lineTo(center.dx + width / 2 - 4, center.dy + sign * height / 2 + 3)
        ..lineTo(center.dx, center.dy - sign * height / 2 + 5)
        ..lineTo(center.dx - width / 2 + 4, center.dy + sign * height / 2 + 3)
        ..close();

      // Shadow shifted down slightly
      canvas.drawPath(path.shift(const Offset(0, 2)), shadowPaint);
      canvas.drawPath(path, paint);
    }

    // Midground forward chevron (∧)
    drawChevron(const Offset(180, 430), 38, 16, true);
    // Foreground backward chevron (∨)
    drawChevron(const Offset(180, 512), 48, 20, false);

    // Street name text in perspective on the road surface
    if (roadName.isNotEmpty) {
      final span = TextSpan(
        text: roadName,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.85),
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
          shadows: const [
            Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 1)),
          ],
        ),
      );
      final tp = TextPainter(text: span, textDirection: TextDirection.ltr)
        ..layout();

      canvas.save();
      // Translate to middle road position
      canvas.translate(180, 465);
      // Perspective tilt to lay flat on the road
      final matrix = Matrix4.identity()
        ..setEntry(3, 2, 0.002)
        ..rotateX(0.75);
      canvas.transform(matrix.storage);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_RailPainter oldDelegate) =>
      roadName != oldDelegate.roadName;
}
