import 'dart:math';
import 'package:flutter/material.dart';
import '../model/feed.dart';
import 'home_glyph_drawers.dart';

extension HomeGlyphComm on HomeGlyphCanvas {
  bool drawComm() {
    const white = Colors.white;
    switch (glyph) {
      case HomeGlyph.messages:
        gradient(
          blueMessages ? white : const Color(0xff65ff57),
          blueMessages ? white : const Color(0xff00cc26),
        );
        final color = blueMessages ? const Color(0xff2787e3) : white;
        canvas.drawOval(
          const Rect.fromLTWH(16, 20, 68, 52),
          Paint()..color = color,
        );
        canvas.drawPath(
          Path()
            ..moveTo(28, 64)
            ..lineTo(22, 82)
            ..lineTo(47, 68)
            ..close(),
          Paint()..color = color,
        );
        if (blueMessages) {
          rect(30, 35, 40, 5, white, 2);
          rect(30, 47, 30, 5, white, 2);
        }
        return true;

      case HomeGlyph.phone:
        gradient(
          pixel ? white : const Color(0xff5dff6a),
          pixel ? white : const Color(0xff06c93a),
        );
        final phone = Path()
          ..moveTo(24, 19)
          ..lineTo(37, 17)
          ..lineTo(44, 37)
          ..lineTo(36, 44)
          ..quadraticBezierTo(42, 61, 58, 67)
          ..lineTo(66, 58)
          ..lineTo(85, 66)
          ..lineTo(82, 79)
          ..quadraticBezierTo(75, 90, 51, 75)
          ..quadraticBezierTo(20, 58, 19, 31)
          ..close();
        canvas.drawPath(
          phone,
          Paint()..color = pixel ? const Color(0xff377ddd) : white,
        );
        return true;

      case HomeGlyph.mail:
        gradient(const Color(0xff0c83ff), const Color(0xff23d7ee));
        rect(17, 29, 66, 46, white, 3);
        line(
          const [Offset(18, 30), Offset(50, 55), Offset(82, 30)],
          const Color(0xff15a9f8),
          3,
        );
        line(
          const [Offset(18, 74), Offset(38, 54)],
          const Color(0xff15a9f8),
          2,
        );
        line(
          const [Offset(82, 74), Offset(62, 54)],
          const Color(0xff15a9f8),
          2,
        );
        return true;

      case HomeGlyph.calendar:
        gradient(white, const Color(0xfff6f6f6));
        final weekday = date.split(',').first.trim();
        final day = RegExp(r'\b\d{1,2}\b').firstMatch(date)?.group(0) ?? '2';
        text(weekday, 50, 10, 14, const Color(0xffe7545b));
        text(day, 50, 31, 56, const Color(0xff242424), weight: FontWeight.w300);
        return true;

      case HomeGlyph.notes:
        gradient(white, const Color(0xfff6f6f6));
        rect(0, 0, 100, 30, const Color(0xffffd833));
        for (var y = 40.0; y < 96; y += 14) {
          line([Offset(0, y), Offset(100, y)], const Color(0xffd5d5d5), 1);
        }
        return true;

      case HomeGlyph.reminders:
        gradient(white, const Color(0xfff2f2f2));
        for (var i = 0; i < 4; i++) {
          final y = 22 + i * 19.0;
          circle(
            16,
            y,
            6,
            [
              Colors.orangeAccent,
              Colors.lightBlue,
              Colors.greenAccent,
              Colors.purpleAccent,
            ][i],
          );
          line(
            [Offset(29, y + 3), Offset(95, y + 3)],
            const Color(0xffcccccc),
            1,
          );
        }
        return true;

      case HomeGlyph.safari:
        gradient(white, white);
        circle(50, 50, 43, const Color(0xff1bb8f6));
        for (var i = 0; i < 36; i++) {
          final a = i * pi / 18;
          line(
            [
              Offset(50 + 35 * cos(a), 50 + 35 * sin(a)),
              Offset(50 + 40 * cos(a), 50 + 40 * sin(a)),
            ],
            white,
            1,
          );
        }
        canvas.drawPath(
          Path()
            ..moveTo(27, 74)
            ..lineTo(43, 43)
            ..lineTo(75, 24)
            ..lineTo(57, 57)
            ..close(),
          Paint()..color = white,
        );
        canvas.drawPath(
          Path()
            ..moveTo(43, 43)
            ..lineTo(75, 24)
            ..lineTo(57, 57)
            ..close(),
          Paint()..color = const Color(0xffec364c),
        );
        return true;

      case HomeGlyph.internet:
        gradient(const Color(0xff8d65ef), const Color(0xff5731c4));
        circle(50, 50, 24, white);
        canvas.save();
        canvas.translate(50, 50);
        canvas.rotate(-pi / 5);
        canvas.drawOval(
          const Rect.fromLTWH(-40, -14, 80, 28),
          Paint()
            ..color = white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4,
        );
        canvas.restore();
        return true;

      case HomeGlyph.clock:
        gradient(const Color(0xff161616), const Color(0xff050505));
        circle(50, 50, 43, white);
        for (var n = 1; n <= 12; n++) {
          final a = n * pi / 6;
          text('$n', 50 + 34 * sin(a), 45 - 34 * cos(a), 10, Colors.black);
        }
        line(const [Offset(50, 50), Offset(37, 24)], Colors.black, 3);
        line(const [Offset(50, 50), Offset(77, 40)], Colors.black, 2);
        line(const [Offset(50, 50), Offset(63, 80)], Colors.redAccent, 1);
        circle(50, 50, 3, Colors.black);
        return true;

      case HomeGlyph.settings:
        gradient(const Color(0xffe5e6e7), const Color(0xff9fa3a8));
        circle(50, 50, 39, const Color(0xff64676b));
        for (var i = 0; i < 24; i++) {
          final a = i * pi / 12;
          line(
            [
              Offset(50 + 29 * cos(a), 50 + 29 * sin(a)),
              Offset(50 + 38 * cos(a), 50 + 38 * sin(a)),
            ],
            const Color(0xffbfc3c7),
            3,
          );
        }
        circle(50, 50, 27, const Color(0xffd9dce0));
        circle(50, 50, 24, const Color(0xff777b80));
        for (var i = 0; i < 3; i++) {
          final a = i * 2 * pi / 3;
          line(
            [const Offset(50, 50), Offset(50 + 23 * cos(a), 50 + 23 * sin(a))],
            const Color(0xffd9dce0),
            5,
          );
        }
        circle(50, 50, 7, const Color(0xffd9dce0));
        return true;

      default:
        return false;
    }
  }
}
