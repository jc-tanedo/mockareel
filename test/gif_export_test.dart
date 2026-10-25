import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockareel/model/project.dart';
import 'package:mockareel/services/gif_videos.dart';
import 'package:mockareel/services/native_renderer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final gif = base64Decode(
    'R0lGODlhAgACAIEAAP8AAAAAAAAAAAAAACH/C05FVFNDQVBFMi4wAwEAAAAh+QQACgAAACwAAAAAAgACAAAIBgABCAQQEAAh+QQBCgABACwAAAAAAgACAIEAAP8AAAAAAAAAAAAIBgABCAQQEAA7',
  );
  for (final feed in [false, true]) {
    testWidgets(
      '${feed ? 'FYP' : 'Maps'} hands animated GIF videos and posters to native export',
      (tester) async {
        await tester.runAsync(() async {
          final dir = await Directory.systemTemp.createTemp('gif-native-test-');
          final original = File('${dir.path}/photo.gif');
          await original.writeAsBytes(gif);
          String? prepared;
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            GifVideos.channel,
            (call) async {
              if (call.method == 'cancel') return null;
              final args = call.arguments as Map;
              await File(args['output'] as String).writeAsBytes([1, 2, 3]);
              return null;
            },
          );
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            NativeRenderer.channel,
            (call) async {
              if (call.method == 'thumbnail') {
                return '${(call.arguments as Map)['path']}.jpg';
              }
              final request = call.arguments as Map;
              prepared = (request['clips'] as List).first['path'] as String;
              expect(prepared, isNot(original.path));
              expect(await File(prepared!).exists(), isTrue);
              expect((request['posters'] as List).single, '$prepared.jpg');
              expect((request['endPosters'] as List).single, '$prepared.jpg');
              expect((request['clips'] as List).first['isVideo'], isTrue);
              expect((request['clips'] as List).first['trimStart'], 0.0);
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
            expect(await File(prepared!).exists(), isTrue);
            await File(prepared!).delete();
            expect(project.clips.single.path, original.path);
            expect(await original.readAsBytes(), orderedEquals(gif));
          } finally {
            tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
              NativeRenderer.channel,
              null,
            );
            tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
              GifVideos.channel,
              null,
            );
            await dir.delete(recursive: true);
          }
        });
      },
    );
  }
}
