import 'package:flutter/material.dart';
import '../model/feed.dart';

/// Original geometric wallpapers inspired by the references, not cropped photos.
class LauncherWallpaper extends CustomPainter {
  final HomeOs os;
  const LauncherWallpaper(this.os);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 360, size.height / 640);
    const bounds = Rect.fromLTWH(0, 0, 360, 640);
    switch (os) {
      case HomeOs.iphone:
        canvas.drawRect(
          bounds,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xffb6d2d2), Color(0xff3997ac), Color(0xff0b527b)],
            ).createShader(bounds),
        );
        final sand = Path()
          ..moveTo(360, 235)
          ..cubicTo(295, 384, 245, 416, 188, 506)
          ..cubicTo(136, 584, 190, 610, 153, 640)
          ..lineTo(360, 640)
          ..close();
        canvas.drawPath(
          sand,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0xffa4c6bc), Color(0xffc8bc9e), Color(0xffc39e82)],
            ).createShader(bounds),
        );
        final wave = Path()
          ..moveTo(-20, 172)
          ..cubicTo(132, 168, 132, 362, 255, 335)
          ..cubicTo(132, 437, 193, 572, 25, 640)
          ..lineTo(-20, 640)
          ..close();
        canvas.drawPath(
          wave,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomRight,
              colors: [Color(0xff3d9db2), Color(0xff084b78), Color(0xff102e57)],
            ).createShader(bounds),
        );
        for (var i = 0; i < 85; i++) {
          final t = i / 85;
          final p = Path()
            ..moveTo(-30, 210 + t * 400)
            ..cubicTo(
              180,
              190 + t * 420,
              55,
              415 + t * 210,
              390,
              360 + t * 330,
            );
          canvas.drawPath(
            p,
            Paint()
              ..color = Colors.white.withValues(alpha: i % 4 == 0 ? .16 : .045)
              ..style = PaintingStyle.stroke
              ..strokeWidth = i % 4 == 0 ? 1.1 : .5,
          );
        }
        break;
      case HomeOs.pixel:
        canvas.drawRect(
          bounds,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xff003f64), Color(0xff208caf), Color(0xffb9c4b8)],
            ).createShader(bounds),
        );
        const planet = Rect.fromLTWH(76, 123, 200, 200);
        canvas.save();
        canvas.clipPath(Path()..addOval(planet));
        canvas.drawRect(
          planet,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xffffc32b), Color(0xffff9a00), Color(0xfffa5926)],
            ).createShader(planet),
        );
        for (var i = 0; i < 14; i++) {
          final y = 143 + i * 13.0;
          canvas.drawPath(
            Path()
              ..moveTo(65, y)
              ..quadraticBezierTo(180, y - 18, 290, y + 6),
            Paint()
              ..color = Color(
                i.isEven ? 0xffffc12a : 0xfff87812,
              ).withValues(alpha: .25)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 8,
          );
        }
        canvas.restore();
        canvas.drawPath(
          Path()
            ..moveTo(0, 294)
            ..lineTo(360, 469)
            ..lineTo(360, 640)
            ..lineTo(0, 640)
            ..close(),
          Paint()
            ..shader = const LinearGradient(
              colors: [Color(0xfff21f12), Color(0xffff6b00)],
            ).createShader(bounds),
        );
        final dark = Path()
          ..moveTo(0, 451)
          ..lineTo(316, 304)
          ..quadraticBezierTo(333, 321, 299, 348)
          ..cubicTo(327, 373, 240, 390, 263, 414)
          ..cubicTo(293, 438, 174, 445, 203, 469)
          ..cubicTo(229, 490, 145, 518, 164, 540)
          ..lineTo(22, 640)
          ..lineTo(0, 640)
          ..close();
        canvas.drawPath(dark, Paint()..color = const Color(0xff00132c));
        circle(canvas, const Offset(316, 285), 9, const Color(0xff14223b));
        break;
      case HomeOs.oneUi:
        canvas.drawRect(
          bounds,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xff24407b), Color(0xff4c57a7), Color(0xff535baa)],
            ).createShader(bounds),
        );
        canvas.drawOval(
          const Rect.fromLTWH(80, 100, 300, 460),
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xff8486ce), Color(0xff626cba), Color(0xff434b99)],
            ).createShader(bounds),
        );
        canvas.drawOval(
          const Rect.fromLTWH(30, 210, 230, 245),
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xff8584c8), Color(0xff454d9c)],
            ).createShader(bounds),
        );
        break;
      case HomeOs.android:
        canvas.drawRect(bounds, Paint()..color = const Color(0xff315359));
        break;
    }
    canvas.restore();
  }

  void circle(Canvas canvas, Offset point, double radius, Color color) =>
      canvas.drawCircle(point, radius, Paint()..color = color);
  @override
  bool shouldRepaint(covariant LauncherWallpaper old) => os != old.os;
}
