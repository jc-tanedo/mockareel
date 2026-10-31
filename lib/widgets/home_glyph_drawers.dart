import 'package:flutter/material.dart';
import '../model/feed.dart';
import 'home_glyph_comm.dart';
import 'home_glyph_content.dart';
import 'home_glyph_media.dart';

export 'home_glyph_comm.dart';
export 'home_glyph_content.dart';
export 'home_glyph_media.dart';

class HomeGlyphCanvas {
  final Canvas canvas;
  final HomeGlyph glyph;
  final HomeOs os;
  final String date;

  const HomeGlyphCanvas({
    required this.canvas,
    required this.glyph,
    required this.os,
    required this.date,
  });

  bool get pixel => os == HomeOs.pixel;
  bool get blueMessages => pixel || os == HomeOs.oneUi;

  void circle(double x, double y, double r, Color color) =>
      canvas.drawCircle(Offset(x, y), r, Paint()..color = color);

  void rect(
    double x,
    double y,
    double w,
    double h,
    Color color, [
    double r = 0,
  ]) => canvas.drawRRect(
    RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r)),
    Paint()..color = color,
  );

  void line(List<Offset> points, Color color, double width) {
    final p = Path()..addPolygon(points, false);
    canvas.drawPath(
      p,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void text(
    String value,
    double x,
    double y,
    double font,
    Color color, {
    FontWeight weight = FontWeight.w400,
  }) {
    final p = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          color: color,
          fontSize: font,
          fontWeight: weight,
          fontFamily: 'Roboto',
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: 96);
    p.paint(canvas, Offset(x - p.width / 2, y));
  }

  void gradient(Color top, Color bottom) => canvas.drawRect(
    const Rect.fromLTWH(0, 0, 100, 100),
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [top, bottom],
      ).createShader(const Rect.fromLTWH(0, 0, 100, 100)),
  );

  void note(Color color, double dx, double dy) {
    canvas.save();
    canvas.translate(dx, dy);
    final p = Path()
      ..moveTo(40, 25)
      ..lineTo(72, 19)
      ..lineTo(72, 65)
      ..cubicTo(72, 80, 49, 84, 49, 71)
      ..cubicTo(49, 61, 59, 59, 64, 61)
      ..lineTo(64, 36)
      ..lineTo(40, 42)
      ..lineTo(40, 74)
      ..cubicTo(40, 89, 18, 91, 18, 79)
      ..cubicTo(18, 69, 28, 66, 32, 68)
      ..lineTo(32, 27)
      ..close();
    canvas.drawPath(p, Paint()..color = color);
    canvas.restore();
  }

  void draw() {
    if (drawComm()) return;
    if (drawMedia()) return;
    drawContent();
  }
}
