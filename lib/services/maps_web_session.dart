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
  String? _script, _loadError;
  int _generation = 0;
  bool _started = false, _finished = false, _disposed = false;
  static const userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36';
  MapsWebSession(this.controller, {required this.onStatus});
  @override
  Future<void> initialize() async {
    _script = await rootBundle.loadString('assets/maps_dom.js');
    if (_disposed) return;
    await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await controller.setUserAgent(userAgent);
    await controller.setNavigationDelegate(
      NavigationDelegate(
        onNavigationRequest: (r) {
          final uri = Uri.tryParse(r.url);
          if (uri != null && MapsWebUrls.allowedNavigation(uri)) {
            final localized = MapsWebUrls.browserUri(uri);
            if (r.isMainFrame &&
                uri.queryParameters['hl'] != 'en' &&
                localized != uri) {
              // Keep the DOM labels predictable, including when a short link
              // redirects without an explicit language. Queue after the native
              // navigation decision has returned to avoid recursive navigation.
              unawaited(
                Future<void>(() async {
                  if (!_disposed) await controller.loadRequest(localized);
                }).catchError((Object _) {
                  _loadError = 'Google Maps could not load. Try again.';
                }),
              );
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          }
          if (r.isMainFrame) {
            _loadError =
                'Google tried to open another app or a sign-in page. Try another search or edit the place manually.';
          }
          return NavigationDecision.prevent;
        },
        onPageStarted: (_) {
          _started = true;
          _finished = false;
        },
        onPageFinished: (_) {
          if (_started) _finished = true;
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
    await controller.loadRequest(Uri.parse('about:blank'));
    if (_disposed || token != _generation) {
      throw const FormatException('Search cancelled.');
    }
    _started = false;
    _finished = false;
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
    while (clock.elapsed < const Duration(seconds: 35)) {
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (_disposed || token != _generation) {
        throw const FormatException('Search cancelled.');
      }
      if (_loadError != null) throw FormatException(_loadError!);
      if (!_started || !_finished) continue;
      MapsWebSnapshot snapshot;
      try {
        snapshot = MapsWebSnapshot.decode(
          await controller.runJavaScriptReturningResult(_script!),
        );
      } on PlatformException {
        continue;
      } on FormatException {
        continue;
      }
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
      final current =
          '${snapshot.results.map((p) => p.url).join('|')}:${snapshot.place?.name}:${snapshot.place?.rating}:${snapshot.place?.address}:${snapshot.place?.reviewCount}:${snapshot.reviews.length}';
      stable = stamp == current ? stable + 1 : 0;
      stamp = current;
      // Give card/details hydration a little time without waiting for continual
      // map tile traffic to become globally idle.
      if (stable >= 2 && clock.elapsed > const Duration(seconds: 4)) {
        return snapshot;
      }
    }
    if (latest != null) return latest;
    throw const FormatException(
      'Google Maps took too long to return readable results. Try a more specific search, Show browser, or manual editing.',
    );
  }

  @override
  Future<MapsWebSnapshot> readPage() async {
    if (_disposed || _script == null) {
      throw const FormatException('Search is not ready.');
    }
    return MapsWebSnapshot.decode(
      await controller.runJavaScriptReturningResult(_script!),
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
