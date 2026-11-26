import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockareel/widgets/map_attribution.dart';

void main() {
  testWidgets(
    'attribution is baked after cropping without changing map dimensions or upper pixels',
    (tester) async {
      await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawColor(const Color(0xff208040), BlendMode.src);
        final picture = recorder.endRecording();
        final original = await picture.toImage(720, 450);
        final png = await original.toByteData(format: ui.ImageByteFormat.png);
        final source = png!.buffer.asUint8List();
        final branded = await MapAttributionPainter.apply(source);
        final credited = await MapAttributionPainter.apply(
          source,
          credits: 'Map data: Example provider',
        );
        final codec = await ui.instantiateImageCodec(credited);
        final frame = await codec.getNextFrame();
        expect(frame.image.width, 720);
        expect(frame.image.height, 450);
        final pixels = await frame.image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        final sourcePixels = await original.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        expect(
          pixels!.buffer.asUint8List(0, 720 * 350 * 4),
          sourcePixels!.buffer.asUint8List(0, 720 * 350 * 4),
        );
        expect(credited, isNot(orderedEquals(source)));
        expect(credited, isNot(orderedEquals(branded)));
        // A footer has been drawn, rather than only storing metadata alongside PNG.
        const bottom = ((450 - 2) * 720 + 700) * 4;
        expect(pixels.getUint8(bottom), greaterThan(200));
        frame.image.dispose();
        codec.dispose();
        original.dispose();
        picture.dispose();
      });
    },
  );
  testWidgets(
    'manual multiline credits are normalized into the same saved caption',
    (tester) async {
      await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawColor(Colors.blue, BlendMode.src);
        final picture = recorder.endRecording();
        final image = await picture.toImage(360, 552);
        final source = (await image.toByteData(
          format: ui.ImageByteFormat.png,
        ))!.buffer.asUint8List();
        final a = await MapAttributionPainter.apply(
          source,
          credits: 'Map data © 2026\n\nExample provider',
        );
        final b = await MapAttributionPainter.apply(
          source,
          credits: 'Map data © 2026 Example provider',
        );
        expect(a, orderedEquals(b));
        image.dispose();
        picture.dispose();
      });
    },
  );
}
