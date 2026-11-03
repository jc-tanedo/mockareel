import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../services/export_capture_frame.dart';

class OffscreenCaptureStage extends StatelessWidget {
  final GlobalKey captureKey;
  final Widget child;

  const OffscreenCaptureStage({
    super.key,
    required this.captureKey,
    required this.child,
  });

  static Future<Uint8List> capturePng(
    GlobalKey key, {
    double pixelRatio = 3.0,
    int settleFrames = 1,
  }) async {
    for (var i = 0; i < settleFrames; i++) {
      await exportCaptureFrame();
    }
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      return bytes!.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  @override
  Widget build(BuildContext context) => Positioned(
    left: 0,
    top: 0,
    width: 360,
    height: 640,
    child: ExcludeSemantics(
      child: IgnorePointer(
        child: MediaQuery.withNoTextScaling(
          child: RepaintBoundary(key: captureKey, child: child),
        ),
      ),
    ),
  );
}
