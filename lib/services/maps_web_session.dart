import 'dart:async';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../model/maps_web_result.dart';

abstract interface class MapsLookupDriver {
  Future<void> initialize();
  Future<MapsWebSnapshot> lookup(String input, {String? expectedName});
  Future<MapsWebSnapshot> readPage();
  void cancel();
  void dispose();
}

class MapsWebSession implements MapsLookupDriver {
  final WebViewController controller;
  final void Function(String) onStatus;
  late final _script = rootBundle.loadString('assets/maps_dom.js');
  String? _loadError;
  int _generation = 0;
  bool _disposed = false;
  static const userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36';
  MapsWebSession(this.controller, {required this.onStatus});
  @override
  Future<void> initialize() async {
    await _script;
    if (_disposed) return;
    await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await controller.setUserAgent(userAgent);
    await controller.setNavigationDelegate(
      NavigationDelegate(
        onNavigationRequest: (r) {
          final uri = Uri.tryParse(r.url);
          if (uri != null && MapsWebUrls.allowedNavigation(uri)) {
            return NavigationDecision.navigate;
          }
          if (r.isMainFrame) {
            _loadError =
                'Google tried to open another app or a sign-in page. Try another search or edit the place manually.';
          }
          return NavigationDecision.prevent;
        },
        onWebResourceError: (e) {
          if (e.isForMainFrame == true) {
            _loadError =
                'Google Maps could not load. Check your connection and try again.';
          }
        },
      ),
    );
  }

  @override
  Future<MapsWebSnapshot> lookup(String input, {String? expectedName}) async {
    if (_disposed) throw const FormatException('Search closed.');
    final uri = MapsWebUrls.browserUri(MapsWebUrls.search(input));
    final token = ++_generation;
    // A loadRequest completes before the new document replaces the old one.
    // Mark the outgoing document so polling cannot import its previous result.
    try {
      await controller.runJavaScript(
        'window.__mockareelOutgoing = location.href',
      );
    } on PlatformException {
      // During navigation there may be no document to mark.
    }
    if (_disposed || token != _generation) {
      throw const FormatException('Search cancelled.');
    }
    _loadError = null;
    onStatus(
      expectedName == null
          ? 'Searching Google Maps…'
          : 'Reading place details…',
    );
    await controller.loadRequest(uri);
    final clock = Stopwatch()..start();
    String? stamp;
    var stable = 0;
    MapsWebSnapshot? latest;
    final deadline = Duration(seconds: expectedName == null ? 18 : 8);
    final script = await _script;
    Duration? firstReadable;
    while (clock.elapsed < deadline) {
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (_disposed || token != _generation) {
        throw const FormatException('Search cancelled.');
      }
      if (_loadError != null) throw FormatException(_loadError!);
      MapsWebSnapshot snapshot;
      try {
        snapshot = MapsWebSnapshot.decode(
          await controller
              .runJavaScriptReturningResult(
                'window.__mockareelOutgoing === location.href ? "{}" : $script',
              )
              .timeout(const Duration(seconds: 3)),
        );
      } on PlatformException {
        continue;
      } on TimeoutException {
        continue;
      } on FormatException {
        continue;
      }
      if (_disposed || token != _generation) {
        throw const FormatException('Search cancelled.');
      }
      if (snapshot.href.isEmpty || snapshot.href == 'about:blank') continue;
      if (snapshot.state == 'interaction') {
        throw const FormatException(
          'Google needs your interaction. Tap Show browser, complete the prompt, then tap Read page.',
        );
      }
      if (snapshot.state == 'empty') return snapshot;
      if (expectedName != null &&
          (snapshot.place == null ||
              snapshot.place!.name.toLowerCase() !=
                  expectedName.toLowerCase())) {
        continue;
      }
      if (snapshot.state != 'results' && snapshot.state != 'place') continue;
      latest = snapshot;
      firstReadable ??= clock.elapsed;
      final current =
          '${snapshot.results.map((p) => p.url).join('|')}:${snapshot.place?.name}:${snapshot.place?.rating}:${snapshot.place?.address}:${snapshot.place?.latitude}:${snapshot.place?.longitude}:${snapshot.place?.reviewCount}:${snapshot.reviews.length}';
      stable = stamp == current ? stable + 1 : 0;
      stamp = current;
      // Give card/details hydration a little time without waiting for continual
      // map tile traffic to become globally idle.
      if (stable >= 2 ||
          clock.elapsed - firstReadable >= const Duration(seconds: 3)) {
        return snapshot;
      }
    }
    if (latest != null) return latest;
    throw TimeoutException(
      'Google Maps took too long to return readable results. Try a more specific search, Show browser, or manual editing.',
    );
  }

  @override
  Future<MapsWebSnapshot> readPage() async {
    if (_disposed) {
      throw const FormatException('Search is not ready.');
    }
    return MapsWebSnapshot.decode(
      await controller.runJavaScriptReturningResult(await _script),
    );
  }

  @override
  void cancel() {
    _generation++;
    unawaited(
      controller
          .loadRequest(Uri.parse('about:blank'))
          .catchError((Object _) {}),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    cancel();
  }
}
