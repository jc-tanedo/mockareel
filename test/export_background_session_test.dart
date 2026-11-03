import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockareel/services/export_background_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'background session covers preparation and stops once on completion',
    () async {
      final calls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(ExportBackgroundSession.channel, (
        call,
      ) async {
        calls.add(call);
        return call.method == 'start' ? true : null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(
          ExportBackgroundSession.channel,
          null,
        ),
      );
      final session = ExportBackgroundSession();
      expect(await session.start('My reel'), isTrue);
      await session.update('Preparing frames…', .1);
      await session.update('Preparing frames…', .2);
      await session.update('Encoding…', .35);
      await session.finish(complete: true);
      await session.finish(complete: false);
      await session.update('Late update', .5);
      expect(calls.map((c) => c.method), [
        'start',
        'update',
        'update',
        'finish',
      ]);
      expect(calls.last.arguments, {'complete': true});
    },
  );
  test(
    'denied notification permission still retains and releases the session',
    () async {
      final calls = <String>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(ExportBackgroundSession.channel, (
        call,
      ) async {
        calls.add(call.method);
        return call.method == 'start' ? false : null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(
          ExportBackgroundSession.channel,
          null,
        ),
      );
      final session = ExportBackgroundSession();
      expect(await session.start('Reel'), isFalse);
      await session.finish(complete: false);
      expect(calls, ['start', 'finish']);
    },
  );
}
