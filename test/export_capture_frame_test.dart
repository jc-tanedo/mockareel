import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockareel/widgets/offscreen_capture_stage.dart';

void main() {
  for (final pauseDuringCapture in [false, true]) {
    testWidgets(
      'capture paints while paused (pause during wait: $pauseDuringCapture)',
      (tester) async {
        final binding = tester.binding;
        final key = GlobalKey();
        final color = ValueNotifier<Color>(Colors.red);
        addTearDown(() async {
          binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
          color.dispose();
        });
        await tester.pumpWidget(
          MaterialApp(
            home: Stack(
              children: [
                OffscreenCaptureStage(
                  captureKey: key,
                  child: ValueListenableBuilder<Color>(
                    valueListenable: color,
                    builder: (_, value, __) => ColoredBox(color: value),
                  ),
                ),
              ],
            ),
          ),
        );
        if (!pauseDuringCapture) {
          binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        }
        color.value = Colors.green;
        final pending = OffscreenCaptureStage.capturePng(key, pixelRatio: 1);
        if (pauseDuringCapture) {
          binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        }
        // No tester.pump: background capture must supply its own paint without vsync.
        await tester.runAsync(() async {
          final png = await pending.timeout(const Duration(seconds: 5));
          final codec = await ui.instantiateImageCodec(png);
          final frame = await codec.getNextFrame();
          final pixels = await frame.image.toByteData();
          expect(pixels!.getUint8(1), greaterThan(pixels.getUint8(0)));
          frame.image.dispose();
          codec.dispose();
        });
        expect(binding.framesEnabled, isFalse);
      },
    );
  }
}
