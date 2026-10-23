import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockareel/model/project.dart';
import 'package:mockareel/services/project_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('trim and duration stay within a video, including subsecond clips', () {
    final clip = ReelClip(
      id: 'x',
      path: 'x.mp4',
      name: 'x',
      isVideo: true,
      sourceDuration: 2,
      duration: 9,
      trimStart: 12,
    );
    expect(clip.duration, 2);
    expect(clip.trimStart, 0);
    clip.duration = .5;
    clip.trimStart = 12;
    clip.normalize();
    expect(clip.trimStart, 1.5);
    final short = ReelClip(
      id: 'y',
      path: 'y',
      name: 'y',
      isVideo: true,
      sourceDuration: .2,
    );
    expect(short.duration, .2);
  });
  test('timeline switches at exact scene boundaries and clamps at the end', () {
    final p = ReelProject(
      clips: [
        for (final d in [1.0, 2.0, 3.0])
          ReelClip(id: '$d', path: 'x', name: 'x', isVideo: false, duration: d),
      ],
    );
    expect(p.clipAt(.99), 0);
    expect(p.clipAt(1), 1);
    expect(p.clipAt(3), 2);
    expect(p.clipAt(6), 2);
    expect(p.startOf(2), 3);
  });
  test(
    'owned media and portable project survive removal of original picker file',
    () async {
      SharedPreferences.setMockInitialValues({});
      final root = await Directory.systemTemp.createTemp('mockareel-storage-');
      addTearDown(() => root.delete(recursive: true));
      final store = ProjectStore(root: Directory('${root.path}/first'));
      await store.initialize();
      final source = File('${root.path}/picker.jpg');
      await source.writeAsBytes([1, 2, 3, 4]);
      final retained = await store.retainMedia(source.path, 'picker.jpg');
      await source.delete();
      final p = ReelProject(
        title: 'Cafe reel',
        place: PlaceDetails(name: 'My cafe', address: 'Makati'),
        clips: [
          ReelClip(
            id: 'clip',
            path: retained,
            name: 'picker.jpg',
            isVideo: false,
            duration: 4,
            caption: 'A great discovery',
          ),
        ],
      );
      await store.save(p);
      expect(
        await File((await store.restore()).clips.single.path).readAsBytes(),
        [1, 2, 3, 4],
      );
      final backup = await store.backup(p);
      final second = ProjectStore(root: Directory('${root.path}/second'));
      await second.initialize();
      final imported = await second.importBackup(backup);
      await Directory('${root.path}/first/media').delete(recursive: true);
      expect(imported.id, isNot(p.id));
      expect(imported.place.name, 'My cafe');
      expect(imported.clips.single.caption, 'A great discovery');
      expect(imported.clips.single.duration, 4);
      expect(await File(imported.clips.single.path).readAsBytes(), [
        1,
        2,
        3,
        4,
      ]);
      expect((await second.restore()).title, 'Cafe reel');
    },
  );
}
