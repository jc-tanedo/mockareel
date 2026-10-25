import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import '../model/project.dart';
import '../services/maps_web_header_session.dart';
import '../theme/app_theme.dart';

/// A visible, hardware-composited map viewport: PixelCopy includes GPU map
/// layers that a Flutter RepaintBoundary or software WebView.draw can omit.
class MapsWebHeaderPage extends StatefulWidget {
  final PlaceDetails place;
  final MapsHeaderDriver? driver;
  final Widget? browserOverride;
  const MapsWebHeaderPage({
    super.key,
    required this.place,
    this.driver,
    this.browserOverride,
  }) : assert(driver == null || browserOverride != null);
  @override
  State<MapsWebHeaderPage> createState() => _MapsWebHeaderPageState();
}

class _MapsWebHeaderPageState extends State<MapsWebHeaderPage> {
  final _frame = GlobalKey();
  WebViewController? _controller;
  MapsHeaderDriver? _driver;
  bool _ready = false, _busy = false;
  String _status = 'Loading Google Maps…';
  String? _error;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    if (widget.driver == null &&
        (kIsWeb || defaultTargetPlatform != TargetPlatform.android)) {
      setState(
        () => _error =
            'Map capture currently requires Android 8 or newer. You can upload a map image or use the optional Maps Static API.',
      );
      return;
    }
    try {
      if (widget.driver != null) {
        _driver = widget.driver;
      } else {
        _controller = WebViewController();
        _driver = MapsWebHeaderSession(_controller!);
      }
      await _driver!.initialize();
      if (!mounted) return;
      setState(() {});
      await _load();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'The map could not start. Update Android System WebView, retry, or upload a map image.',
        );
      }
    }
  }

  Future<void> _load() async {
    if (_driver == null || _busy) return;
    final generation = ++_generation;
    setState(() {
      _ready = false;
      _error = null;
      _status = 'Loading Google Maps…';
    });
    try {
      await _driver!.load(widget.place);
      if (mounted && generation == _generation) {
        setState(() {
          _ready = true;
          _status =
              'Pan or zoom to frame your map. Check that tiles have loaded.';
        });
      }
    } catch (e) {
      if (mounted && generation == _generation) {
        setState(
          () => _error = e is FormatException
              ? e.message
              : 'Could not load the map. Retry or upload a map image.',
        );
      }
    }
  }

  Future<void> _zoom(bool inward) async {
    if (!_ready || _busy) return;
    try {
      await _driver!.zoom(inward);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not zoom. Try pinching the map or reload it.',
        );
      }
    }
  }

  Future<void> _capture() async {
    if (!_ready || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Keep the entire viewport visible, including on shorter phones.
      await Scrollable.ensureVisible(_frame.currentContext!, alignment: .5);
      // Let the last pan/zoom frame settle before copying the native window.
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      final box = _frame.currentContext!.findRenderObject()! as RenderBox;
      final position = box.localToGlobal(Offset.zero);
      final dpr = View.of(context).devicePixelRatio;
      final bytes = await _driver!.capture(
        Rect.fromLTWH(
          position.dx * dpr,
          position.dy * dpr,
          box.size.width * dpr,
          box.size.height * dpr,
        ),
      );
      if (mounted) Navigator.pop(context, bytes);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not capture the map on this device. Retry, upload a map image, or use the optional Maps Static API.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _generation++;
    _driver?.dispose();
    super.dispose();
  }

  Widget _mapFrame() => AspectRatio(
    aspectRatio: 1000 / 625,
    child: ClipRect(
      key: _frame,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _controller == null && widget.browserOverride == null
              ? const ColoredBox(color: ink)
              : IgnorePointer(
                  ignoring: _busy,
                  child: FittedBox(
                    fit: BoxFit.fill,
                    child: SizedBox(
                      width: 1000,
                      height: 625,
                      child:
                          widget.browserOverride ??
                          WebViewWidget.fromPlatformCreationParams(
                            params: AndroidWebViewWidgetCreationParams(
                              controller: _controller!.platform,
                              displayWithHybridComposition: true,
                            ),
                          ),
                    ),
                  ),
                ),
          if (!_busy)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: null,
              child: IgnorePointer(
                child: AspectRatio(
                  aspectRatio: 360 / 94,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: mint.withValues(alpha: .8),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );

  List<Widget> _controls() => [
    const SizedBox(height: 8),
    Row(
      children: [
        IconButton(
          tooltip: 'Zoom out',
          onPressed: _ready && !_busy ? () => _zoom(false) : null,
          icon: const Icon(Icons.remove),
        ),
        IconButton(
          tooltip: 'Zoom in',
          onPressed: _ready && !_busy ? () => _zoom(true) : null,
          icon: const Icon(Icons.add),
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: _busy || _driver == null ? null : _load,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ],
    ),
    if (!_ready && _error == null) const LinearProgressIndicator(minHeight: 2),
    if (_error != null)
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(_error!, style: const TextStyle(color: Colors.white70)),
      ),
    const SizedBox(height: 12),
    const Text(
      'Keep the place inside the lower outlined area: this remains visible after the intro. The full map is revealed during the opening. The map is saved with your project for preview, export and backups. Google branding and attribution are retained. No API key needed.',
      style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.5),
    ),
  ];

  Widget _captureButton() => SizedBox(
    width: double.infinity,
    child: FilledButton.icon(
      onPressed: _ready && !_busy ? _capture : null,
      icon: Icon(_busy ? Icons.hourglass_top : Icons.check),
      label: Text(_busy ? 'Capturing map…' : 'Use map header'),
    ),
  );

  List<Widget> _heading() => [
    const Text(
      'KEY-FREE MAP HEADER',
      style: TextStyle(color: mint, fontSize: 10, letterSpacing: 1.4),
    ),
    const SizedBox(height: 10),
    Text(widget.place.name, style: Theme.of(context).textTheme.titleLarge),
    const SizedBox(height: 8),
    Text(_status, style: const TextStyle(color: Colors.white60, fontSize: 12)),
    const SizedBox(height: 16),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Frame map header')),
    body: SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 600 &&
              constraints.maxWidth > constraints.maxHeight) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(flex: 3, child: Center(child: _mapFrame())),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [..._heading(), ..._controls()],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _captureButton(),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }
          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: _busy ? const NeverScrollableScrollPhysics() : null,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ..._heading(),
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 680),
                          child: _mapFrame(),
                        ),
                      ),
                      ..._controls(),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: _captureButton(),
              ),
            ],
          );
        },
      ),
    ),
  );
}
