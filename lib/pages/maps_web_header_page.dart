import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import '../model/project.dart';
import '../services/maps_web_header_session.dart';
import '../model/map_capture_viewport.dart';
import '../widgets/map_attribution.dart';
import '../theme/app_theme.dart';

/// A visible, hardware-composited map viewport: PixelCopy includes GPU map
/// layers that a Flutter RepaintBoundary or software WebView.draw can omit.
class MapsWebHeaderPage extends StatefulWidget {
  final PlaceDetails place;
  final MapsHeaderDriver? driver;
  final Widget? browserOverride;
  final double aspectRatio;
  final bool showHeaderGuide;
  const MapsWebHeaderPage({
    super.key,
    required this.place,
    this.driver,
    this.browserOverride,
    this.aspectRatio = 1000 / 625,
    this.showHeaderGuide = true,
  }) : assert(driver == null || browserOverride != null),
       assert(aspectRatio > 0 && aspectRatio < 10);
  @override
  State<MapsWebHeaderPage> createState() => _MapsWebHeaderPageState();
}

class _MapsWebHeaderPageState extends State<MapsWebHeaderPage> {
  final _frame = GlobalKey();
  WebViewController? _controller;
  MapsHeaderDriver? _driver;
  bool _ready = false, _busy = false;
  String _credits = "";
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
      if (!mounted || generation != _generation) return;
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
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (!mounted) return;
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      // Let the last pan/zoom frame settle before copying the native window.
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      await Scrollable.ensureVisible(_frame.currentContext!, alignment: .5);
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
      final attributed = await MapAttributionPainter.apply(
        bytes,
        credits: _credits,
      );
      if (mounted) Navigator.pop(context, attributed);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is FormatException
              ? e.message
              : 'Could not capture the map on this device. Retry, upload a map image, or use the optional Maps Static API.',
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

  Widget _mapFrame() {
    final colors = Theme.of(context).colorScheme;
    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: ClipRect(
        key: _frame,
        child: Stack(
          key: const ValueKey('map-capture-viewport'),
          fit: StackFit.expand,
          children: [
            _controller == null && widget.browserOverride == null
                ? ColoredBox(color: colors.surface)
                : LayoutBuilder(
                    builder: (context, bounds) {
                      final viewport = MapCaptureViewport(widget.aspectRatio);
                      final browser = viewport.browser;
                      final scale = bounds.maxWidth / viewport.content.width;
                      return OverflowBox(
                        minWidth: browser.width * scale,
                        maxWidth: browser.width * scale,
                        minHeight: browser.height * scale,
                        maxHeight: browser.height * scale,
                        child: IgnorePointer(
                          ignoring: _busy,
                          child: FittedBox(
                            fit: BoxFit.fill,
                            child: SizedBox(
                              width: browser.width,
                              height: browser.height,
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
                      );
                    },
                  ),
            if (!_busy)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: MapAttributionPainter(credits: _credits),
                  ),
                ),
              ),
            if (!_busy && widget.showHeaderGuide)
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
  }

  List<Widget> _controls() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return [
      const SizedBox(height: 8),
      Row(
        children: [
          IconButton.filledTonal(
            tooltip: 'Zoom out',
            onPressed: _ready && !_busy ? () => _zoom(false) : null,
            icon: const Icon(Icons.remove),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
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
      const SizedBox(height: 8),
      TextFormField(
        enabled: !_busy,
        decoration: const InputDecoration(
          labelText: 'Map / imagery credits',
          hintText: 'Add source attribution text',
          helperText: 'Added beside Google Maps after the image is cropped.',
        ),
        maxLength: 300,
        minLines: 1,
        maxLines: 3,
        onChanged: (value) => setState(() => _credits = value),
      ),
      if (!_ready && _error == null)
        const LinearProgressIndicator(minHeight: 2),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            _error!,
            style: theme.textTheme.bodyMedium?.copyWith(color: colors.error),
          ),
        ),
      const SizedBox(height: 12),
      Text(
        widget.showHeaderGuide
            ? 'Keep the place inside the lower outlined area: this remains visible after the intro. The full map is revealed during the opening. The map is saved with your project for preview, export and backups. Google Maps and your entered credits are added after cropping. No API key needed.'
            : 'Frame the place inside the visible crop. Google Maps and your entered credits are added after capture. The image is saved for preview, export and backups. No API key needed.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: colors.onSurfaceVariant,
          height: 1.5,
        ),
      ),
    ];
  }

  Widget _captureButton() => SizedBox(
    width: double.infinity,
    child: FilledButton.icon(
      onPressed: _ready && !_busy ? _capture : null,
      icon: Icon(_busy ? Icons.hourglass_top : Icons.check),
      label: Text(
        _busy
            ? 'Capturing map…'
            : widget.showHeaderGuide
            ? 'Use map header'
            : 'Use map',
      ),
    ),
  );

  List<Widget> _heading() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return [
      Text(
        widget.showHeaderGuide ? 'KEY-FREE MAP HEADER' : 'KEY-FREE MAP',
        style: theme.textTheme.labelSmall?.copyWith(
          color: colors.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.4,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        widget.place.name,
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: colors.onSurface,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        _status,
        style: theme.textTheme.bodySmall?.copyWith(
          color: colors.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 16),
    ];
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.showHeaderGuide ? 'Frame map header' : 'Frame map'),
    ),
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
                          constraints: BoxConstraints(
                            maxWidth: min(
                              680,
                              max(1, constraints.maxHeight - 120) *
                                  widget.aspectRatio,
                            ),
                          ),
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
