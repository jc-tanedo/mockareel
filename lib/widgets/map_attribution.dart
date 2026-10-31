import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// The same footer is previewed during framing and stamped after PixelCopy.
/// Attribution is user supplied and never affects WebView loading or cropping.
class MapAttributionPainter extends CustomPainter {
  final String credits;
  const MapAttributionPainter({this.credits = ''});

  static Future<Uint8List> apply(
    Uint8List source, {
    String credits = '',
  }) async {
    final codec = await ui.instantiateImageCodec(source);
    try {
      final frame = await codec.getNextFrame();
      try {
        final image = frame.image;
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawImage(image, Offset.zero, Paint());
        MapAttributionPainter(
          credits: credits,
        ).paint(canvas, Size(image.width.toDouble(), image.height.toDouble()));
        final picture = recorder.endRecording();
        try {
          final output = await picture.toImage(image.width, image.height);
          try {
            final png = await output.toByteData(format: ui.ImageByteFormat.png);
            if (png == null) {
              throw const FormatException('Could not add map attribution.');
            }
            return png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes);
          } finally {
            output.dispose();
          }
        } finally {
          picture.dispose();
        }
      } finally {
        frame.image.dispose();
      }
    } finally {
      codec.dispose();
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final text = credits.replaceAll(RegExp(r'\s+'), ' ').trim();
    final pad = size.width / 120;
    final brand = TextPainter(
      text: TextSpan(
        text: 'Google Maps',
        style: TextStyle(
          color: const Color(0xff303134),
          fontSize: size.width / 72,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final credit = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: const Color(0xff303134),
          fontSize: size.width / 90,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.right,
    )..layout(maxWidth: size.width - brand.width - pad * 4);
    final height =
        (credit.height > brand.height ? credit.height : brand.height) + pad * 2;
    final top = size.height - height;
    canvas.drawRect(
      Rect.fromLTWH(0, top, size.width, height),
      Paint()..color = const Color(0xf2ffffff),
    );
    brand.paint(canvas, Offset(pad, top + (height - brand.height) / 2));
    if (text.isNotEmpty) {
      credit.paint(
        canvas,
        Offset(
          size.width - pad - credit.width,
          top + (height - credit.height) / 2,
        ),
      );
    }
    brand.dispose();
    credit.dispose();
  }

  @override
  bool shouldRepaint(MapAttributionPainter old) => old.credits != credits;
}
