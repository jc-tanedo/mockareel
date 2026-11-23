import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

typedef GoogleOrbitResult = ({String? scene, String? reason});

/// Captures the camera orbit as rendered frames. The client key and streamed
/// tile payloads are never written into the project.
class GoogleOrbitCapturePage extends StatefulWidget {
  final String apiKey;
  final double latitude, longitude;
  const GoogleOrbitCapturePage({
    super.key,
    required this.apiKey,
    required this.latitude,
    required this.longitude,
  });
  @override
  State<GoogleOrbitCapturePage> createState() => _GoogleOrbitCapturePageState();
}

class _GoogleOrbitCapturePageState extends State<GoogleOrbitCapturePage> {
  WebViewController? controller;
  Timer? timeout;
  final payload = StringBuffer();
  int frames = 0;
  bool finished = false, started = false;
  void finish(String? data, {String? reason}) {
    if (!mounted || finished || ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    finished = true;
    timeout?.cancel();
    Navigator.pop<GoogleOrbitResult>(context, (
      scene: data,
      reason:
          reason ??
          (data == null ? 'Google 3D rendering was unavailable.' : null),
    ));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => start());
  }

  Future<void> start() async {
    try {
      final html = await rootBundle.loadString(
        'assets/streetview3d/google_orbit.html',
      );
      if (!mounted) return;
      final web = WebViewController();
      await web.setJavaScriptMode(JavaScriptMode.unrestricted);
      await web.addJavaScriptChannel(
        'OrbitCapture',
        onMessageReceived: (message) {
          if (!mounted || finished) return;
          final value = message.message;
          if (value == 'denied' || value == 'coverage') {
            finish(
              null,
              reason: value == 'denied'
                  ? 'Google rejected the tile request. Check the Map Tiles API key and billing.'
                  : 'Detailed Google 3D coverage was unavailable at this pin.',
            );
            return;
          }
          if (value == 'unavailable') {
            finish(null);
            return;
          }
          if (value.startsWith('part:')) {
            if (payload.length + value.length > 12000005) {
              finish(null);
              return;
            }
            payload.write(value.substring(5));
            return;
          }
          if (value == 'complete') {
            final json = payload.toString();
            finish(json.startsWith('{') ? json : null);
            return;
          }
          final progress = int.tryParse(value);
          if (progress != null) {
            setState(() => frames = progress.clamp(0, 24));
            return;
          }
          finish(null);
        },
      );
      const origin = 'https://mockareel.invalid/';
      await web.setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (r) =>
              r.url == origin ||
                  r.url == 'about:blank' ||
                  r.url.startsWith('data:text/html')
              ? NavigationDecision.navigate
              : NavigationDecision.prevent,
          onPageFinished: (_) async {
            if (!mounted || finished || started) return;
            started = true;
            try {
              await web.runJavaScript(
                'if(typeof captureOrbit==="function"){captureOrbit(${jsonEncode(widget.apiKey)},${widget.latitude},${widget.longitude})}else{OrbitCapture.postMessage("unavailable")}',
              );
            } catch (_) {
              finish(null);
            }
          },
        ),
      );
      if (!mounted) return;
      setState(() => controller = web);
      timeout = Timer(const Duration(seconds: 90), () => finish(null));
      await web.loadHtmlString(html, baseUrl: origin);
    } catch (_) {
      finish(null);
    }
  }

  @override
  void dispose() {
    timeout?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Google 3D coverage')),
    body: Column(
      children: [
        Expanded(
          child: controller == null
              ? const Center(child: CircularProgressIndicator())
              : WebViewWidget(controller: controller!),
        ),
        SafeArea(
          top: false,
          child: ListTile(
            title: Text(
              frames == 0
                  ? 'Checking this pin for detailed tiles…'
                  : 'Rendering orbit · $frames / 24',
            ),
            trailing: TextButton(
              onPressed: () => finish(null, reason: 'Open data selected.'),
              child: const Text('Use open data'),
            ),
          ),
        ),
      ],
    ),
  );
}
