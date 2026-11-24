import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockareel/features/streetview_3d/data/orbit_scene_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('orbit-loader-');
  });
  tearDown(() => root.delete(recursive: true));

  Future<File> writeScene(String name) =>
      File('${root.path}/$name').writeAsString(
        jsonEncode({'shapes': [], 'grid': List.filled(625, 0), 'credit': name}),
      );

  test(
    'concurrent reads share a load and the four newest scenes stay cached',
    () async {
      final first = await writeScene('first');
      final pending = OrbitSceneLoader.load(first.path);
      expect(OrbitSceneLoader.load(first.path), same(pending));
      final scene = await pending;
      expect(OrbitSceneLoader.cached(first.path), same(scene));
      for (var i = 0; i < 4; ++i) {
        final file = await writeScene('scene-$i');
        await OrbitSceneLoader.load(file.path);
      }
      expect(OrbitSceneLoader.cached(first.path), isNull);
      for (var i = 0; i < 4; ++i) {
        expect(
          OrbitSceneLoader.cached('${root.path}/scene-$i')?.credit,
          'scene-$i',
        );
      }
    },
  );

  test(
    'a rejected capture can be replaced and loaded at the same path',
    () async {
      final file = await File('${root.path}/retry').writeAsString(
        jsonEncode({
          'provider': 'google-3d',
          'credit': 'fixture',
          // Valid 1x1 JPEG. Captures require a 2304x2720 atlas.
          'atlas':
              '/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkS'
              'Ew8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/wAALCAAB'
              'AAEBAREA/8QAFAABAAAAAAAAAAAAAAAAAAAACP/EABQQAQAAAAAAAAAAAAAAAAAAAAD/'
              '2gAIAQEAAD8AP7//2Q==',
        }),
      );
      await expectLater(
        OrbitSceneLoader.load(file.path),
        throwsFormatException,
      );
      expect(OrbitSceneLoader.cached(file.path), isNull);
      await writeScene('retry');
      final scene = await OrbitSceneLoader.loadForExport(file.path);
      expect(OrbitSceneLoader.cached(file.path), same(scene));
    },
  );
}
