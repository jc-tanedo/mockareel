import 'dart:math';
import 'package:flutter/material.dart';
import '../model/feed.dart';
import 'home_glyph_drawers.dart';

extension HomeGlyphMedia on HomeGlyphCanvas {
  bool drawMedia() {
    const white = Colors.white;
    switch (glyph) {
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
        return true;

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
        return true;

      case HomeGlyph.weather:
        gradient(const Color(0xff2181ff), const Color(0xff27d6f0));
        circle(37, 36, 20, const Color(0xffffdd2f));
        rect(23, 50, 61, 24, white, 12);
        circle(48, 49, 18, white);
        circle(66, 52, 15, white);
        return true;

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
        return true;

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
        return true;

      case HomeGlyph.music:
        gradient(white, white);
        note(const Color(0xfff44480), 8, 0);
        return true;

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
        return true;

      default:
        return false;
    }
  }
}
