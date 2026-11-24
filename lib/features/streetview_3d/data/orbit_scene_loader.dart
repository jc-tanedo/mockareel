import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/painting.dart'
    show ImageConfiguration, ImageStreamListener, MemoryImage;
import '../model/orbit_scene.dart';

abstract final class OrbitSceneLoader {
  // Map assets are immutable. Hold a few decoded scenes for synchronous
  // first paint during frame-by-frame Android export.
  static final _cache = <String, OrbitScene>{};

  /// A scene whose atlas is ready for the first captured frame.
  static Future<OrbitScene> loadForExport(String path) async {
    final scene = await load(path);
    final bytes = scene.atlas;
    if (bytes == null) return scene;
    final image = MemoryImage(bytes);
    final done = Completer<void>();
    final stream = image.resolve(ImageConfiguration.empty);
    final listener = ImageStreamListener(
      (info, _) {
        info.dispose();
        if (!done.isCompleted) done.complete();
      },
      onError: (Object e, StackTrace? st) {
        if (!done.isCompleted) done.completeError(e, st);
      },
    );
    stream.addListener(listener);
    try {
      await done.future;
    } finally {
      stream.removeListener(listener);
    }
    return scene;
  }

  static OrbitScene? cached(String path) => _cache[path];
  static final _loading = <String, Future<OrbitScene>>{};
  static Future<OrbitScene> load(String path) {
    final hit = cached(path);
    if (hit != null) return Future.value(hit);
    return _loading.putIfAbsent(
      path,
      () => _read(path).whenComplete(() {
        _loading.remove(path);
      }),
    );
  }

  static Future<OrbitScene> _read(String path) async {
    final file = File(path);
    if (await file.length() > 12000000) {
      throw const FormatException('Map scene is too large.');
    }
    final scene = OrbitScene.decode(await file.readAsString());
    if (scene.atlas case final atlas?) {
      final buffer = await ImmutableBuffer.fromUint8List(atlas);
      try {
        final descriptor = await ImageDescriptor.encoded(buffer);
        try {
          if (descriptor.width != 2304 || descriptor.height != 2720) {
            throw const FormatException('Invalid orbit dimensions.');
          }
        } finally {
          descriptor.dispose();
        }
      } finally {
        buffer.dispose();
      }
    }
    if (_cache.length >= 4) _cache.remove(_cache.keys.first);
    return _cache[path] = scene;
  }
}
