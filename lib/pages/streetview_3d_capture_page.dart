import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../model/project.dart';

/// Automated WebView Street View stepper that captures real Street View frames
/// along a route from [fromPlace] toward [toPlace].
class Streetview3dCapturePage extends StatefulWidget {
  final PlaceDetails fromPlace;
  final PlaceDetails toPlace;
  final int targetSteps;

  const Streetview3dCapturePage({
    super.key,
    required this.fromPlace,
    required this.toPlace,
    this.targetSteps = 12,
  });

  @override
  State<Streetview3dCapturePage> createState() =>
      _Streetview3dCapturePageState();
}

class _Streetview3dCapturePageState extends State<Streetview3dCapturePage> {
  final _boundaryKey = GlobalKey();
  late final WebViewController _controller;
  final List<String> _frames = [];
  bool _ready = false;
  bool _capturing = false;
  bool _cancelled = false;
  String _status = 'Loading Street View…';

  @override
  void initState() {
    super.initState();
    final lat = widget.fromPlace.latitude ?? 40.7580;
    final lng = widget.fromPlace.longitude ?? -73.9855;
    final heading = _bearingDegrees(
      lat,
      lng,
      widget.toPlace.latitude ?? lat + 0.002,
      widget.toPlace.longitude ?? lng,
    );
    final url =
        'https://www.google.com/maps/@?api=1&map_action=pano'
        '&viewpoint=$lat,$lng&heading=${heading.toStringAsFixed(1)}&pitch=0';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (!mounted || _ready) return;
            _ready = true;
            _startStepping();
          },
        ),
      )
      ..loadRequest(Uri.parse(url));
  }

  @override
  void dispose() {
    _cancelled = true;
    super.dispose();
  }

  double _bearingDegrees(double lat1, double lng1, double lat2, double lng2) {
    final phi1 = lat1 * pi / 180;
    final phi2 = lat2 * pi / 180;
    final dLambda = (lng2 - lng1) * pi / 180;
    final y = sin(dLambda) * cos(phi2);
    final x = cos(phi1) * sin(phi2) - sin(phi1) * cos(phi2) * cos(dLambda);
    return (atan2(y, x) * 180 / pi + 360) % 360;
  }

  Future<void> _startStepping() async {
    if (_capturing || _cancelled) return;
    setState(() {
      _capturing = true;
      _status = 'Preparing Street View…';
    });
    await Future<void>.delayed(const Duration(seconds: 3));
    if (_cancelled || !mounted) return;

    await _hideChrome();
    final dir = await getApplicationDocumentsDirectory();
    final stamp = DateTime.now().millisecondsSinceEpoch;

    for (var step = 0; step < widget.targetSteps; step++) {
      if (_cancelled || !mounted) return;
      setState(
        () => _status = 'Capturing step ${step + 1} of ${widget.targetSteps}…',
      );
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (_cancelled || !mounted) return;

      final path = '${dir.path}/sv3d_${stamp}_$step.png';
      final saved = await _captureFrame(path);
      if (saved) _frames.add(path);

      if (step + 1 < widget.targetSteps) {
        await _stepForward();
      }
    }

    if (mounted && !_cancelled) {
      Navigator.pop(context, List<String>.from(_frames));
    }
  }

  Future<void> _hideChrome() async {
    try {
      await _controller.runJavaScript('''
        (function() {
          var style = document.createElement('style');
          style.textContent =
            '#omnibox-container, #minimap, #titlecard, #image-header, ' +
            '.app-viewcard-strip, .scene-footer, button[jsaction*="close"] ' +
            '{ opacity: 0 !important; pointer-events: none !important; }';
          document.head.appendChild(style);
        })();
      ''');
    } catch (_) {}
  }

  Future<void> _stepForward() async {
    try {
      await _controller.runJavaScript('''
        (function() {
          var canvas = document.querySelector('canvas');
          if (!canvas) return;
          var rect = canvas.getBoundingClientRect();
          var x = rect.left + rect.width * 0.5;
          var y = rect.top + rect.height * 0.68;
          var evt = new MouseEvent('click', {
            bubbles: true, cancelable: true, clientX: x, clientY: y
          });
          canvas.dispatchEvent(evt);
        })();
      ''');
    } catch (_) {}
  }

  Future<bool> _captureFrame(String path) async {
    try {
      final boundary =
          _boundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return false;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) return false;
      await File(path).writeAsBytes(data.buffer.asUint8List());
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.targetSteps == 0
        ? 0.0
        : _frames.length / widget.targetSteps;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Capture Street View'),
        actions: [
          if (_frames.isNotEmpty)
            TextButton(
              onPressed: () {
                _cancelled = true;
                Navigator.pop(context, List<String>.from(_frames));
              },
              child: Text('Use ${_frames.length}'),
            ),
        ],
      ),
      body: Column(
        children: [
          LinearProgressIndicator(value: _capturing ? progress : null),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _status,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                Text('${_frames.length}/${widget.targetSteps}'),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 9 / 16,
                child: RepaintBoundary(
                  key: _boundaryKey,
                  child: WebViewWidget(controller: _controller),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
