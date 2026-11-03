import 'dart:math';
import 'package:flutter/material.dart';
import '../model/feed.dart';
import 'home_glyph_drawers.dart';

extension HomeGlyphContent on HomeGlyphCanvas {
  bool drawContent() {
    const white = Colors.white;
    switch (glyph) {
      case HomeGlyph.wallet:
        gradient(const Color(0xff121212), const Color(0xff090909));
        for (var i = 0; i < 4; i++) {
          rect(
            14,
            22 + i * 7,
            72,
            48,
            [
              const Color(0xff36a8ce),
              const Color(0xfff3cc48),
              const Color(0xff75c184),
              const Color(0xfffa795c),
            ][i],
            5,
          );
        }
        canvas.drawPath(
          Path()
            ..moveTo(14, 48)
            ..lineTo(37, 48)
            ..quadraticBezierTo(50, 68, 63, 48)
            ..lineTo(86, 48)
            ..lineTo(86, 80)
            ..lineTo(14, 80)
            ..close(),
          Paint()..color = const Color(0xffddd8cf),
        );
        return true;

      case HomeGlyph.stocks:
        gradient(const Color(0xff111416), Colors.black);
        for (var x = 12.0; x < 100; x += 18) {
          line([Offset(x, 0), Offset(x, 100)], Colors.white30, 1);
        }
        line(
          const [
            Offset(0, 62),
            Offset(15, 65),
            Offset(26, 60),
            Offset(35, 64),
            Offset(43, 52),
            Offset(50, 55),
            Offset(56, 42),
            Offset(62, 65),
            Offset(72, 33),
            Offset(80, 52),
            Offset(90, 47),
            Offset(100, 50),
          ],
          white,
          2,
        );
        line(
          const [Offset(72, 0), Offset(72, 100)],
          const Color(0xff1da3ef),
          1,
        );
        circle(72, 33, 3, const Color(0xff1da3ef));
        return true;

      case HomeGlyph.itunes:
        gradient(const Color(0xffe64cce), const Color(0xffc72dd0));
        circle(50, 50, 41, white);
        circle(50, 50, 38, const Color(0xffce3bd2));
        note(white, 5, 0);
        return true;

      case HomeGlyph.appStore:
        gradient(const Color(0xff1ecdfa), const Color(0xff0872f1));
        canvas.drawCircle(
          const Offset(50, 50),
          40,
          Paint()
            ..color = white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
        line(const [Offset(34, 73), Offset(60, 24)], white, 7);
        line(const [Offset(45, 25), Offset(71, 73)], white, 7);
        line(const [Offset(24, 61), Offset(77, 61)], white, 7);
        return true;

      case HomeGlyph.books:
        gradient(const Color(0xffffc313), const Color(0xffff8c00));
        canvas.drawPath(
          Path()
            ..moveTo(17, 27)
            ..quadraticBezierTo(35, 19, 48, 30)
            ..lineTo(48, 77)
            ..quadraticBezierTo(32, 66, 17, 74)
            ..close(),
          Paint()..color = white,
        );
        canvas.drawPath(
          Path()
            ..moveTo(53, 30)
            ..quadraticBezierTo(71, 19, 85, 27)
            ..lineTo(85, 74)
            ..quadraticBezierTo(69, 66, 53, 77)
            ..close(),
          Paint()..color = white,
        );
        return true;

      case HomeGlyph.news:
        gradient(const Color(0xffff6571), const Color(0xfffb274b));
        rect(18, 20, 64, 61, white, 3);
        for (var i = 0; i < 3; i++) {
          rect(23, 26 + i * 5, 23, 2, Colors.grey);
          rect(56, 26 + i * 5, 22, 2, Colors.grey);
        }
        circle(50, 31, 7, Colors.grey);
        rect(23, 50, 54, 24, const Color(0xff536c7c));
        for (var i = 0; i < 6; i++) {
          rect(
            25 + i * 8,
            58 - (i % 3) * 7,
            6,
            16 + (i % 3) * 7,
            const Color(0xff36434c),
          );
        }
        return true;

      case HomeGlyph.health:
        gradient(white, const Color(0xfff4f4f4));
        final heart = Path()
          ..moveTo(50, 75)
          ..cubicTo(2, 49, 22, 12, 50, 33)
          ..cubicTo(78, 12, 98, 49, 50, 75)
          ..close();
        canvas.drawPath(
          heart,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xffff7198), Color(0xffef234c)],
            ).createShader(const Rect.fromLTWH(20, 23, 60, 53)),
        );
        return true;

      case HomeGlyph.tiktok:
        gradient(const Color(0xff111111), Colors.black);
        final mark = Path()
          ..moveTo(48, 18)
          ..lineTo(62, 18)
          ..cubicTo(64, 31, 73, 35, 84, 35)
          ..lineTo(84, 49)
          ..cubicTo(75, 49, 68, 46, 62, 42)
          ..lineTo(62, 68)
          ..cubicTo(62, 95, 17, 95, 17, 68)
          ..cubicTo(17, 48, 37, 43, 47, 49)
          ..lineTo(47, 63)
          ..cubicTo(31, 55, 26, 69, 34, 75)
          ..cubicTo(41, 81, 48, 75, 48, 67)
          ..close();
        for (final layer in [
          (const Offset(-2, 2), const Color(0xff25f4ee)),
          (const Offset(2, -1), const Color(0xfffe2c55)),
          (Offset.zero, Colors.white),
        ]) {
          canvas.save();
          canvas.translate(layer.$1.dx, layer.$1.dy);
          canvas.drawPath(mark, Paint()..color = layer.$2);
          canvas.restore();
        }
        return true;

      case HomeGlyph.playStore:
        gradient(white, white);
        canvas.drawPath(
          Path()
            ..moveTo(28, 18)
            ..lineTo(28, 82)
            ..lineTo(61, 50)
            ..close(),
          Paint()..color = const Color(0xff3bc9e8),
        );
        canvas.drawPath(
          Path()
            ..moveTo(28, 18)
            ..lineTo(76, 43)
            ..lineTo(61, 50)
            ..close(),
          Paint()..color = const Color(0xff42ba78),
        );
        canvas.drawPath(
          Path()
            ..moveTo(28, 82)
            ..lineTo(76, 57)
            ..lineTo(61, 50)
            ..close(),
          Paint()..color = const Color(0xffef5859),
        );
        canvas.drawPath(
          Path()
            ..moveTo(61, 50)
            ..lineTo(76, 43)
            ..quadraticBezierTo(93, 50, 76, 57)
            ..close(),
          Paint()..color = const Color(0xfffed34b),
        );
        return true;

      case HomeGlyph.store:
        gradient(const Color(0xffff7c7b), const Color(0xffe63f85));
        rect(23, 34, 54, 45, white, 7);
        canvas.drawArc(
          const Rect.fromLTWH(34, 17, 32, 37),
          pi,
          pi,
          false,
          Paint()
            ..color = white
            ..strokeWidth = 6
            ..style = PaintingStyle.stroke,
        );
        return true;

      case HomeGlyph.folder:
        gradient(
          const Color(0xffd8e5ee).withValues(alpha: .85),
          const Color(0xffa1b6c9).withValues(alpha: .9),
        );
        const colors = [
          Color(0xff3d9ce9),
          Color(0xffef5d70),
          Color(0xfff4c54c),
          Color(0xff54b88a),
          Color(0xff8163c6),
          Color(0xff268eb0),
          Color(0xffdb8b43),
          Color(0xffe25f91),
          Color(0xff8296ab),
        ];
        for (var i = 0; i < 9; i++) {
          rect(14 + (i % 3) * 26, 14 + (i ~/ 3) * 26, 19, 19, colors[i], 5);
        }
        return true;

      default:
        return false;
    }
  }
}
