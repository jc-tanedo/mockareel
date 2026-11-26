import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:mockareel/model/ids.dart';
import 'package:mockareel/model/reel_clip.dart';
import 'package:mockareel/services/native_renderer.dart';

class PhotoWalk {
  static const _channel = MethodChannel('dev.mockareel/photo-depth');
  static Future<({List<String> layers, Uint8List depth})> prepare(
    ReelClip clip,
    Directory root,
  ) async {
    final path = await NativeRenderer().poster(clip);
    final buffer = await ui.ImmutableBuffer.fromFilePath(path);
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    try {
      final scale = min(1.0, 1440 / max(descriptor.width, descriptor.height));
      final codec = await descriptor.instantiateCodec(
        targetWidth: max(1, (descriptor.width * scale).round()),
        targetHeight: max(1, (descriptor.height * scale).round()),
      );
      try {
        final image = (await codec.getNextFrame()).image;
        try {
          final rgba = await image.toByteData(
            format: ui.ImageByteFormat.rawStraightRgba,
          );
          final result = await _channel
              .invokeMapMethod<String, dynamic>('layers', {
                'width': image.width,
                'height': image.height,
                'rgba': rgba!.buffer.asUint8List(
                  rgba.offsetInBytes,
                  rgba.lengthInBytes,
                ),
              });
          final layers = (result?['layers'] as List?)?.cast<Uint8List>();
          final depth = result?['depth'];
          if (layers == null ||
              layers.length != 3 ||
              depth is! Uint8List ||
              depth.length != 1024) {
            throw const FormatException('Incomplete photo layers.');
          }
          final files = <File>[];
          try {
            for (final bytes in layers) {
              final file = File('${root.path}/media/walk-${newId()}.png');
              files.add(file);
              await file.writeAsBytes(bytes, flush: true);
            }
            return (layers: files.map((f) => f.path).toList(), depth: depth);
          } catch (_) {
            for (final file in files) {
              if (await file.exists()) await file.delete();
            }
            rethrow;
          }
        } finally {
          image.dispose();
        }
      } finally {
        codec.dispose();
      }
    } finally {
      descriptor.dispose();
      buffer.dispose();
    }
  }
}
