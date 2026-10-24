import 'dart:math';
import 'package:flutter/material.dart';
import '../model/feed.dart';

/// Vector artwork stays crisp in a 1080p export; no screenshot tiles are bundled.
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
    final blueMessages = pixel || os == HomeOs.oneUi;
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
        break;
      case HomeGlyph.calendar:
        gradient(white, const Color(0xfff6f6f6));
        final weekday = date.split(',').first.trim();
        final day = RegExp(r'\b\d{1,2}\b').firstMatch(date)?.group(0) ?? '2';
        text(weekday, 50, 10, 14, const Color(0xffe7545b));
        text(day, 50, 31, 56, const Color(0xff242424), weight: FontWeight.w300);
        break;
      case HomeGlyph.photos:
      case HomeGlyph.gallery:
        gradient(
          glyph == HomeGlyph.gallery ? const Color(0xfff4598a) : white,
          glyph == HomeGlyph.gallery ? const Color(0xffd9336b) : white,
        );
        const colors = [
          Color(0xffffc916),
          Color(0xfff68a24),
          Color(0xffed494b),
          Color(0xffdf3683),
          Color(0xff96539e),
          Color(0xff3c81d1),
          Color(0xff42b0ba),
          Color(0xff80c339),
        ];
        for (var i = 0; i < 8; i++) {
          canvas.save();
          canvas.translate(50, 50);
          canvas.rotate(i * pi / 4);
          canvas.drawOval(
            const Rect.fromLTWH(-12, -41, 24, 43),
            Paint()
              ..color = glyph == HomeGlyph.gallery
                  ? white
                  : colors[i].withValues(alpha: .78),
          );
          canvas.restore();
        }
        break;
      case HomeGlyph.camera:
        gradient(
          pixel ? white : const Color(0xfff2f3f4),
          pixel ? white : const Color(0xffb9bcc0),
        );
        final c = pixel ? const Color(0xff397dc3) : const Color(0xff323336);
        rect(15, 29, 70, 47, c, 5);
        rect(29, 20, 30, 20, c, 5);
        circle(50, 52, 20, const Color(0xffb1b5b7));
        circle(50, 52, 16, const Color(0xff161a20));
        circle(50, 52, 10, const Color(0xff2c4051));
        circle(76, 35, 3, const Color(0xffebd66c));
        break;
      case HomeGlyph.weather:
        gradient(const Color(0xff2181ff), const Color(0xff27d6f0));
        circle(37, 36, 20, const Color(0xffffdd2f));
        rect(23, 50, 61, 24, white, 12);
        circle(48, 49, 18, white);
        circle(66, 52, 15, white);
        break;
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
        break;
      case HomeGlyph.maps:
        gradient(const Color(0xffd0e4bc), const Color(0xfff7f1d5));
        rect(0, 0, 67, 19, const Color(0xff79c93d));
        rect(78, 0, 12, 100, white);
        rect(0, 20, 100, 17, white);
        rect(0, 25, 100, 7, const Color(0xff57caff));
        line(
          const [Offset(3, 91), Offset(42, 59), Offset(58, 46), Offset(57, 1)],
          white,
          16,
        );
        line(
          const [Offset(3, 91), Offset(42, 59), Offset(58, 46), Offset(57, 1)],
          const Color(0xfff8c928),
          8,
        );
        rect(20, 42, 40, 30, white, 5);
        rect(23, 44, 34, 7, Colors.redAccent, 2);
        text(
          '280',
          40,
          52,
          20,
          const Color(0xff185eb7),
          weight: FontWeight.w600,
        );
        circle(77, 68, 10, const Color(0xff2482ed));
        line(
          const [
            Offset(77, 62),
            Offset(73, 72),
            Offset(77, 69),
            Offset(81, 72),
            Offset(77, 62),
          ],
          white,
          2,
        );
        break;
      case HomeGlyph.videos:
        gradient(const Color(0xff42e6d4), const Color(0xff16bff1));
        rect(0, 0, 100, 31, const Color(0xff141819));
        for (var x = -16.0; x < 100; x += 35) {
          canvas.drawPath(
            Path()
              ..moveTo(x, 0)
              ..lineTo(x + 18, 0)
              ..lineTo(x + 37, 16)
              ..lineTo(x + 18, 31)
              ..lineTo(x, 31)
              ..lineTo(x + 18, 16)
              ..close(),
            Paint()..color = white,
          );
        }
        break;
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
        break;
      case HomeGlyph.notes:
        gradient(white, const Color(0xfff6f6f6));
        rect(0, 0, 100, 30, const Color(0xffffd833));
        for (var y = 40.0; y < 96; y += 14) {
          line([Offset(0, y), Offset(100, y)], const Color(0xffd5d5d5), 1);
        }
        break;
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
        break;
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
        break;
      case HomeGlyph.itunes:
        gradient(const Color(0xffe64cce), const Color(0xffc72dd0));
        circle(50, 50, 41, white);
        circle(50, 50, 38, const Color(0xffce3bd2));
        note(white, 5, 0);
        break;
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
        break;
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
        break;
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
        break;
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
        break;
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
        break;
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
        break;
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
        break;
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
        break;
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
        break;
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
        break;
      case HomeGlyph.music:
        gradient(white, white);
        note(const Color(0xfff44480), 8, 0);
        break;
      case HomeGlyph.chrome:
        gradient(white, white);
        for (var i = 0; i < 3; i++) {
          canvas.drawArc(
            const Rect.fromLTWH(8, 8, 84, 84),
            -pi / 2 + i * 2 * pi / 3,
            2 * pi / 3,
            true,
            Paint()
              ..color = [
                const Color(0xffe84435),
                const Color(0xfff7ca43),
                const Color(0xff38aa58),
              ][i],
          );
        }
        circle(50, 50, 23, white);
        circle(50, 50, 19, const Color(0xff3e8dee));
        break;
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
        break;
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
        break;
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
        break;
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AppIconPainter old) =>
      glyph != old.glyph || os != old.os || date != old.date;
}
