import 'package:flutter/material.dart';
import '../model/feed.dart';
import 'home_glyph_drawers.dart';

export 'home_glyph_drawers.dart';

/// Vector artwork stays crisp in a 1080p export; no screenshot tiles are
/// bundled.
class HomeAppIcon extends StatelessWidget {
  final HomeGlyph glyph;
  final HomeOs os;
  final String date;
  const HomeAppIcon({
    super.key,
    required this.glyph,
    required this.os,
    this.date = 'Monday, February 2',
  });

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _AppIconPainter(glyph, os, date),
    child: const SizedBox.expand(),
  );
}

class _AppIconPainter extends CustomPainter {
  final HomeGlyph glyph;
  final HomeOs os;
  final String date;
  _AppIconPainter(this.glyph, this.os, this.date);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final pixel = os == HomeOs.pixel;
    final radius = pixel
        ? 50.0
        : os == HomeOs.oneUi
        ? 27.0
        : 24.0;
    canvas.clipRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 100, 100),
        Radius.circular(radius),
      ),
    );

    HomeGlyphCanvas(
      canvas: canvas,
      glyph: glyph,
      os: os,
      date: date,
    ).draw();

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AppIconPainter old) =>
      glyph != old.glyph || os != old.os || date != old.date;
}
