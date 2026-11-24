import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockareel/services/maps_web_session.dart';
import 'package:webview_flutter/webview_flutter.dart';

class _LoadingController implements WebViewController {
  final String url =
      'https://www.google.com/maps/place/Yomiuriland/data=!3d35.6253!4d139.51907?opaque=%FF';
  var reads = 0;

  @override
  Future<void> loadRequest(
    Uri uri, {
    LoadRequestMethod method = LoadRequestMethod.get,
    Map<String, String> headers = const {},
    Uint8List? body,
  }) async {}

  @override
  Future<void> runJavaScript(String script) async {}

  @override
  Future<Object> runJavaScriptReturningResult(String script) async {
    if (++reads == 1) return '{}';
    return jsonEncode({
      'state': 'place',
      'href': url,
      'place': {'name': 'Yomiuriland', 'url': url},
    });
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'readable listing imports its pin with no page-finished callback and an opaque query',
    () async {
      final controller = _LoadingController();
      final session = MapsWebSession(controller, onStatus: (_) {});
      addTearDown(session.dispose);
      final snapshot = await session
          .lookup(controller.url)
          .timeout(const Duration(seconds: 7));
      expect(snapshot.place?.name, 'Yomiuriland');
      expect(
        (snapshot.place?.latitude, snapshot.place?.longitude),
        (35.6253, 139.51907),
      );
    },
  );
}
