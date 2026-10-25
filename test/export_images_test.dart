import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockareel/model/project.dart';
import 'package:mockareel/services/export_images.dart';
import 'package:mockareel/services/native_renderer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final gif = base64Decode(
    'R0lGODlhAgACAIEAAP8AAAAAAAAAAAAAACH/C05FVFNDQVBFMi4wAwEAAAAh+QQACgAAACwAAAAAAgACAAAIBgABCAQQEAAh+QQBCgABACwAAAAAAgACAIEAAP8AAAAAAAAAAAAIBgABCAQQEAA7',
  );
  testWidgets(
    'GIF magic is recognized even with a JPEG name; PNG preserves first frame and original',
    (tester) async {
      await tester.runAsync(() async {
        final dir = await Directory.systemTemp.createTemp('gif-export-test-');
        final original = File('${dir.path}/photo.jpg');
        await original.writeAsBytes(gif);
        final images = ExportImages();
        try {
          final path = await images.prepare(original.path);
          expect(path, endsWith('.png'));
          expect(await images.prepare(original.path), path);
          final data = await File(path).readAsBytes();
          expect(
            data.take(8),
            orderedEquals([137, 80, 78, 71, 13, 10, 26, 10]),
          );
          final codec = await ui.instantiateImageCodec(data);
          final frame = await codec.getNextFrame();
          final pixels = (await frame.image.toByteData())!.buffer.asUint8List();
          expect(pixels.take(4), orderedEquals([255, 0, 0, 255]));
          frame.image.dispose();
          codec.dispose();
          expect(await original.readAsBytes(), orderedEquals(gif));
          await images.dispose();
          expect(await File(path).exists(), isFalse);
        } finally {
          await images.dispose();
          await dir.delete(recursive: true);
        }
      });
    },
  );

  for (final feed in [false, true]) {
    testWidgets(
      '${feed ? 'FYP' : 'Maps'} hands PNGs to native export and cleans up after failure',
      (tester) async {
        await tester.runAsync(() async {
          final dir = await Directory.systemTemp.createTemp('gif-native-test-');
          final original = File('${dir.path}/photo.gif');
          await original.writeAsBytes(gif);
          String? prepared;
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            NativeRenderer.channel,
            (call) async {
              final request = call.arguments as Map;
              prepared = (request['clips'] as List).first['path'] as String;
              expect(prepared, isNot(original.path));
              expect(await File(prepared!).exists(), isTrue);
              expect((request['posters'] as List).single, prepared);
              expect((request['endPosters'] as List).single, prepared);
              throw PlatformException(code: 'TEST_FAILURE');
            },
          );
          final project = ReelProject(
            clips: [
              ReelClip(
                id: 'gif',
                path: original.path,
                name: 'photo.gif',
                isVideo: false,
                duration: 3.5,
              ),
            ],
          );
          try {
            final renderer = NativeRenderer();
            await expectLater(
              feed
                  ? renderer.exportFeed(
                      clips: project.clips.map((c) => c.toJson()).toList(),
                      overlays: ['overlay.png'],
                      frames: [[]],
                      transitions: [0],
                    )
                  : renderer.export(project, ['overlay.png']),
              throwsA(isA<PlatformException>()),
            );
            expect(prepared, isNotNull);
            expect(await File(prepared!).exists(), isFalse);
            expect(project.clips.single.path, original.path);
            expect(await original.readAsBytes(), orderedEquals(gif));
          } finally {
            tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
              NativeRenderer.channel,
              null,
            );
            await dir.delete(recursive: true);
          }
        });
      },
    );
  }
}
