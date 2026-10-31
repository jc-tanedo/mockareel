// Asset exporter: flutter test tool/generate_brand_assets_test.dart
// Geometry is shared between SVG, Android vectors, and raster launcher assets.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';

const brandInk = Color(0xffb1a6ff), brandGround = Color(0xff202023);

class _Mark {
  final path = Path()..fillType = PathFillType.evenOdd;
  final commands = StringBuffer();
  void m(double x, double y) {
    path.moveTo(x, y);
    commands.write('M$x,$y ');
  }

  void l(double x, double y) {
    path.lineTo(x, y);
    commands.write('L$x,$y ');
  }

  void c(double a, double b, double c, double d, double e, double f) {
    path.cubicTo(a, b, c, d, e, f);
    commands.write('C$a,$b $c,$d $e,$f ');
  }

  void q(double a, double b, double c, double d) {
    path.quadraticBezierTo(a, b, c, d);
    commands.write('Q$a,$b $c,$d ');
  }

  void close() {
    path.close();
    commands.write('Z ');
  }

  void hole(double x, double y, double r) {
    path.addOval(Rect.fromCircle(center: Offset(x, y), radius: r));
    commands.write(
      'M${x - r},$y a$r,$r 0 1,0 ${2 * r},0 a$r,$r 0 1,0 ${-2 * r},0 Z ',
    );
  }
}

_Mark _geometry() => _Mark()
  ..m(43.5, 51.5)
  ..c(35.5, 43.0, 26.0, 37.0, 16.5, 35.0)
  ..q(14.0, 35.0, 17.5, 40.0)
  ..c(21.0, 48.0, 24.5, 56.5, 26.0, 64.0)
  ..c(24.5, 71.5, 21.0, 80.0, 17.5, 88.0)
  ..q(14.0, 93.0, 16.5, 93.0)
  ..c(26.0, 91.0, 35.5, 85.0, 43.5, 76.5)
  ..c(49.2, 89.2, 61.2, 98.0, 75.0, 98.0)
  ..c(90.5, 98.0, 105.0, 86.5, 108.5, 69.5)
  ..c(106.0, 68.0, 102.5, 66.5, 100.5, 64.0)
  ..c(102.5, 61.5, 106.0, 60.0, 108.5, 58.5)
  ..c(105.0, 41.5, 90.5, 30.0, 75.0, 30.0)
  ..c(61.2, 30.0, 49.2, 38.8, 43.5, 51.5)
  ..close()
  ..hole(63.0, 52.0, 8.0)
  ..hole(87.0, 52.0, 8.0)
  ..hole(63.0, 76.0, 8.0)
  ..hole(87.0, 76.0, 8.0)
  ..hole(75.0, 64.0, 3.5)
  ..hole(99.0, 50.5, 2.5);

Future<void> png(
  String path,
  int size,
  void Function(Canvas, double) draw,
) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  draw(canvas, size.toDouble());
  final picture = recorder.endRecording();
  final image = await picture.toImage(size, size);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes!.buffer.asUint8List());
  image.dispose();
  picture.dispose();
}

void _drawMark(Canvas canvas, _Mark mark, Rect bounds, Color color) {
  canvas.save();
  // The glyph's optical center is (63,64); its silhouette is 94×68 units.
  final scale = bounds.width / 94;
  canvas.translate(
    bounds.center.dx - 63 * scale,
    bounds.center.dy - 64 * scale,
  );
  canvas.scale(scale);
  canvas.drawPath(
    mark.path,
    Paint()
      ..color = color
      ..isAntiAlias = true,
  );
  canvas.restore();
}

void main() {
  test('export the Mockareel brand assets', () async {
    final fontRoot = Platform.environment['FLUTTER_ROOT'];
    if (fontRoot != null) {
      final loader = FontLoader('Roboto');
      loader.addFont(
        File(
          '$fontRoot/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
        ).readAsBytes().then(ByteData.sublistView),
      );
      await loader.load();
    }
    final mark = _geometry();
    final brand = Directory('assets/brand');
    await brand.create(recursive: true);
    final d = mark.commands.toString().trim();
    for (final entry in [
      ('mockareel.svg', '#B1A6FF'),
      ('mockareel-monochrome.svg', 'currentColor'),
    ]) {
      await File('${brand.path}/${entry.$1}').writeAsString(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128" role="img" aria-label="Mockareel film reel fish"><path fill="${entry.$2}" fill-rule="evenodd" d="$d"/></svg>\n',
      );
    }
    for (final entry in [
      ('ic_launcher_foreground', '#FFB1A6FF'),
      ('ic_launcher_monochrome', '#FFFFFFFF'),
    ]) {
      await File(
        'android/app/src/main/res/drawable/${entry.$1}.xml',
      ).writeAsString('''<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="108dp" android:height="108dp" android:viewportWidth="108" android:viewportHeight="108">
    <group android:translateX="16.2" android:translateY="15.6" android:scaleX="0.6" android:scaleY="0.6">
        <path android:fillColor="${entry.$2}" android:fillType="evenOdd" android:pathData="$d" />
    </group>
</vector>
''');
    }
    for (final entry in [
      ('mdpi', 48),
      ('hdpi', 72),
      ('xhdpi', 96),
      ('xxhdpi', 144),
      ('xxxhdpi', 192),
    ]) {
      for (final round in [false, true]) {
        await png(
          'android/app/src/main/res/mipmap-${entry.$1}/ic_launcher${round ? '_round' : ''}.png',
          entry.$2,
          (canvas, size) {
            final paint = Paint()
              ..color = brandGround
              ..isAntiAlias = true;
            if (round) {
              canvas.drawCircle(Offset(size / 2, size / 2), size / 2, paint);
            } else {
              canvas.drawRRect(
                RRect.fromRectAndRadius(
                  Rect.fromLTWH(0, 0, size, size),
                  Radius.circular(size * .22),
                ),
                paint,
              );
            }
            _drawMark(
              canvas,
              mark,
              Rect.fromCenter(
                center: Offset(size / 2, size / 2),
                width: size * .76,
                height: size * .76,
              ),
              brandInk,
            );
          },
        );
      }
    }
    await png(
      '${brand.path}/mockareel-mark.png',
      1024,
      (canvas, size) => _drawMark(
        canvas,
        mark,
        Rect.fromLTWH(size * .1, size * .1, size * .8, size * .8),
        brandInk,
      ),
    );
    await png('${brand.path}/mockareel-icon.png', 1024, (canvas, size) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size, size),
          Radius.circular(size * .22),
        ),
        Paint()
          ..color = brandGround
          ..isAntiAlias = true,
      );
      _drawMark(
        canvas,
        mark,
        Rect.fromLTWH(size * .12, size * .12, size * .76, size * .76),
        brandInk,
      );
    });
    // A review sheet shows the app icon, a one-color glyph, and actual small sizes.
    await png('${brand.path}/icon-preview.png', 1024, (canvas, size) {
      canvas.drawColor(const Color(0xfff4f3f8), BlendMode.src);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(72, 100, 400, 400),
          const Radius.circular(88),
        ),
        Paint()
          ..color = brandGround
          ..isAntiAlias = true,
      );
      _drawMark(
        canvas,
        mark,
        const Rect.fromLTWH(120, 148, 304, 304),
        brandInk,
      );
      _drawMark(
        canvas,
        mark,
        const Rect.fromLTWH(560, 148, 304, 304),
        brandGround,
      );
      for (final entry in [
        (24.0, 128.0),
        (32.0, 248.0),
        (48.0, 400.0),
        (64.0, 580.0),
      ]) {
        _drawMark(
          canvas,
          mark,
          Rect.fromCenter(
            center: Offset(entry.$2, 680),
            width: entry.$1,
            height: entry.$1,
          ),
          brandGround,
        );
      }
      // Adaptive launcher's circular mask preview (108dp asset seen through 72dp).
      canvas.save();
      canvas.clipPath(Path()..addOval(const Rect.fromLTWH(744, 604, 128, 128)));
      canvas.drawColor(brandGround, BlendMode.src);
      _drawMark(
        canvas,
        mark,
        const Rect.fromLTWH(758, 618, 100, 100),
        brandInk,
      );
      canvas.restore();
      final label = TextPainter(
        text: const TextSpan(
          text: 'MOCKAREEL',
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 40,
            letterSpacing: 8,
            color: brandGround,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, Offset((size - label.width) / 2, 846));
    });
  });
}
