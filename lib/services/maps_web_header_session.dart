import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../model/maps_web_result.dart';
import '../model/project.dart';
import 'maps_web_session.dart';
import '../model/map_capture_viewport.dart';

abstract interface class MapsHeaderDriver {
  Future<void> initialize();
  Future<void> load(PlaceDetails place);

  /// Returns whether the cropped viewport can retain Google's attribution.
  Future<bool> prepareCapture();
  Future<void> zoom(bool inward);
  Future<Uint8List> capture(Rect physicalBounds);
  void dispose();
}

class MapsWebHeaderSession implements MapsHeaderDriver {
  final WebViewController controller;
  final MapCaptureViewport viewport;
  late final _session = MapsWebSession(controller, onStatus: (_) {});
  static const _channel = MethodChannel('dev.mockareel/map-snapshot');
  late final Future<String> _asset = rootBundle.loadString(
    'assets/maps_header.js',
  );
  bool _cropped = true;
  Future<String> get _script async =>
      'window.__mockareelHeaderCrop = ${_cropped ? jsonEncode(viewport.toJson()) : 'null'};\n${await _asset}';
  int _generation = 0;
  bool _closed = false;
  MapsWebHeaderSession(
    this.controller, {
    this.viewport = const MapCaptureViewport(1.6),
  });
  @override
  Future<void> initialize() => _session.initialize();
  @override
  Future<void> load(PlaceDetails place) async {
    _cropped = true;
    final generation = ++_generation;
    await controller.loadRequest(MapsWebUrls.header(place));
    final script = await _script;
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
  Future<Map> _snapshot() async {
    Object state = await controller.runJavaScriptReturningResult(await _script);
    for (var i = 0; i < 2 && state is String; i++) {
      state = jsonDecode(state);
    }
    if (_closed) throw const FormatException('Map closed.');
    if (state is! Map || state['state'] != 'ready') {
      throw const FormatException(
        'Map is not ready to capture. Retry loading it.',
      );
    }
    return state;
  }

  @override
  Future<bool> prepareCapture() async {
    final state = await _snapshot();
    if (_cropped && state['attributionReady'] == false) {
      // Reset the footer CSS, then let the page show the complete WebView.
      // Its original credits remain visible even if Google's DOM has changed.
      _cropped = false;
      await controller.runJavaScript(await _script);
    }
    return _cropped;
  }

  @override
  Future<Uint8List> capture(Rect bounds) async {
    final generation = _generation;
    // Reapply cleanup and let the WebView paint it before native PixelCopy.
    // This also covers controls inserted since the last load/zoom poll.
    final state = await _snapshot();
    if (_cropped && state['attributionReady'] == false) {
      throw const FormatException(
        'Map attribution moved. Tap Use map again to refresh the capture area.',
      );
    }
    await controller.runJavaScript('''
window.__mockareelHeaderCaptureReady = false;
requestAnimationFrame(() => requestAnimationFrame(() => {
  window.__mockareelHeaderCaptureReady = true;
}));
''');
    var painted = false;
    for (var attempt = 0; attempt < 40; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (_closed || generation != _generation) {
        throw const FormatException('Map closed.');
      }
      final ready = await controller.runJavaScriptReturningResult(
        'window.__mockareelHeaderCaptureReady === true',
      );
      if (ready == true || ready == 'true') {
        painted = true;
        break;
      }
    }
    if (!painted) throw const FormatException('Map is not ready to capture.');
    if (_closed || generation != _generation) {
      throw const FormatException('Map closed.');
    }
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
