import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:mockareel/services/maps_web_header_session.dart';
import 'package:mockareel/model/project.dart';

class CaptureController implements WebViewController {
  final scripts = <String>[];
  int paintPolls = 0;
  bool ready = true;
  bool attributionReady = true;
  VoidCallback? onPoll;
  @override
  Future<void> loadRequest(
    Uri uri, {
    LoadRequestMethod method = LoadRequestMethod.get,
    Map<String, String> headers = const {},
    Uint8List? body,
  }) async {}
  @override
  Future<void> runJavaScript(String script) async => scripts.add(script);
  @override
  Future<Object> runJavaScriptReturningResult(String script) async {
    scripts.add(script);
    if (script.contains('mockareel-header-style')) {
      return '{"state":"${ready ? 'ready' : 'interaction'}", "attributionReady":$attributionReady}';
    }
    onPoll?.call();
    return ++paintPolls >= 2;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const channel = MethodChannel('dev.mockareel/map-snapshot');
  testWidgets(
    'loaded map with an unknown footer completes and captures the full viewport',
    (tester) async {
      final controller = CaptureController()..attributionReady = false;
      final session = MapsWebHeaderSession(controller);
      var copies = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        copies++;
        expect(
          controller.scripts.lastWhere(
            (s) => s.contains('mockareel-header-style'),
          ),
          startsWith('window.__mockareelHeaderCrop = null;'),
        );
        return Uint8List.fromList([7]);
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await tester.runAsync(() async {
        await session
            .load(PlaceDetails(name: 'Fixture'))
            .timeout(const Duration(seconds: 8));
        expect(await session.prepareCapture(), false);
        expect(await session.capture(const Rect.fromLTWH(0, 0, 100, 100)), [7]);
      });
      expect(copies, 1);
      session.dispose();
    },
  );
  testWidgets('cleanup must repaint before native map capture', (tester) async {
    final controller = CaptureController();
    final session = MapsWebHeaderSession(controller);
    var copies = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      expect(controller.paintPolls, 2);
      expect(controller.scripts.first, contains('MutationObserver'));
      expect(
        controller.scripts[1],
        contains('requestAnimationFrame(() => requestAnimationFrame'),
      );
      copies++;
      return Uint8List.fromList([1, 2, 3]);
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    await tester.runAsync(() async {
      expect(await session.capture(const Rect.fromLTWH(0, 0, 100, 100)), [
        1,
        2,
        3,
      ]);
    });
    expect(copies, 1);
    session.dispose();
  });
  testWidgets(
    'closing during repaint or encountering a Google prompt prevents capture',
    (tester) async {
      var copies = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        copies++;
        return Uint8List(1);
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await tester.runAsync(() async {
        final controller = CaptureController();
        final session = MapsWebHeaderSession(controller);
        controller.onPoll = session.dispose;
        await expectLater(
          session.capture(const Rect.fromLTWH(0, 0, 100, 100)),
          throwsFormatException,
        );
        final prompt = CaptureController()..ready = false;
        final blocked = MapsWebHeaderSession(prompt);
        await expectLater(
          blocked.capture(const Rect.fromLTWH(0, 0, 100, 100)),
          throwsFormatException,
        );
        blocked.dispose();
      });
      expect(copies, 0);
    },
  );
}
