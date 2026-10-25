import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../model/maps_web_result.dart';
import '../model/project.dart';
import 'maps_web_session.dart';

abstract interface class MapsHeaderDriver {
  Future<void> initialize();
  Future<void> load(PlaceDetails place);
  Future<void> zoom(bool inward);
  Future<Uint8List> capture(Rect physicalBounds);
  void dispose();
}

class MapsWebHeaderSession implements MapsHeaderDriver {
  final WebViewController controller;
  late final _session = MapsWebSession(controller, onStatus: (_) {});
  static const _channel = MethodChannel('dev.mockareel/map-snapshot');
  int _generation = 0;
  bool _closed = false;
  MapsWebHeaderSession(this.controller);
  @override
  Future<void> initialize() => _session.initialize();
  @override
  Future<void> load(PlaceDetails place) async {
    final generation = ++_generation;
    await controller.loadRequest(MapsWebUrls.header(place));
    final script = await rootBundle.loadString('assets/maps_header.js');
    final timer = Stopwatch()..start();
    var stable = 0;
    while (timer.elapsed < const Duration(seconds: 35)) {
      await Future<void>.delayed(const Duration(milliseconds: 800));
      if (_closed || generation != _generation) {
        throw const FormatException('Map closed.');
      }
      try {
        Object data = await controller.runJavaScriptReturningResult(script);
        for (var i = 0; i < 2 && data is String; i++) {
          data = jsonDecode(data);
        }
        if (data is! Map) continue;
        if (data['state'] == 'interaction') {
          throw const FormatException(
            'Complete the Google prompt in the map, then tap Retry.',
          );
        }
        stable = data['state'] == 'ready' ? stable + 1 : 0;
        if (stable >= 3 && timer.elapsed > const Duration(seconds: 5)) return;
      } on PlatformException {
        /* Navigation briefly replaces the document. */
      }
    }
    throw const FormatException(
      'The map took too long to load. Check your connection and retry, or upload a map image.',
    );
  }

  @override
  Future<void> zoom(bool inward) => controller.runJavaScript(
    'document.querySelector(\'button[aria-label="Zoom ${inward ? 'in' : 'out'}"]\')?.click()',
  );
  @override
  Future<Uint8List> capture(Rect bounds) async {
    final bytes = await _channel
        .invokeMethod<Uint8List>('capture', {
          'left': bounds.left,
          'top': bounds.top,
          'width': bounds.width,
          'height': bounds.height,
        })
        .timeout(const Duration(seconds: 10));
    if (bytes == null || bytes.isEmpty) {
      throw const FormatException('No map image was returned.');
    }
    return bytes;
  }

  @override
  void dispose() {
    _closed = true;
    _generation++;
    _session.dispose();
  }
}
