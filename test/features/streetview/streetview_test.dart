import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockareel/model/project.dart';
import 'package:mockareel/model/streetview_timeline.dart';
import 'package:mockareel/services/project_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

ReelClip clip(String id, String address, {String transition = 'arrow'}) =>
    ReelClip(
      id: id,
      path: '$id.jpg',
      name: id,
      isVideo: false,
      duration: 3,
      streetview: StreetviewMedia(
        place: PlaceDetails(address: address),
        transition: transition,
      ),
    );
void main() {
  test('timeline counts maps, movements and back taps exactly once', () {
    final p = ReelProject(
      template: 'streetview',
      clips: [
        clip('a', 'A'),
        clip('b', 'B', transition: 'map'),
        clip('c', 'C'),
      ],
    );
    final scenes = StreetviewTimeline.scenes(p);
    expect(scenes.map((s) => s.kind), [
      'map',
      'media',
      'arrow',
      'media',
      'back',
      'map',
      'media',
    ]);
    expect(p.duration, closeTo(13.4, .000001));
    expect(p.startOf(0), 2);
    expect(p.startOf(1), 5.45);
    expect(StreetviewTimeline.at(p, 5).kind, 'arrow');
    expect(StreetviewTimeline.at(p, 5.45).mediaIndex, 1);
    expect(StreetviewTimeline.at(p, p.duration).kind, 'media');
    p.streetview.endOnMap = true;
    expect(p.duration, closeTo(15.35, .000001));
    expect(StreetviewTimeline.at(p, p.duration).kind, 'ending-map');
  });
  test(
    'locations and settings survive reordering, removal and JSON roundtrip',
    () {
      final p = ReelProject(
        template: 'streetview',
        darkOutput: true,
        streetview: StreetviewSettings(endOnMap: true),
        clips: [
          clip('a', 'A'),
          clip('b', 'B', transition: 'map'),
        ],
      );
      p.clips[1].streetview
        ..date = 'October 2026'
        ..panZoom = true
        ..showControls = false;
      p.clips.insert(0, p.clips.removeLast());
      final restored = ReelProject.fromJson(p.toJson());
      expect(restored.isStreetview, true);
      expect(restored.darkOutput, true);
      expect(restored.streetview.endOnMap, true);
      expect(restored.clips.first.id, 'b');
      expect(restored.clips.first.streetview.place.address, 'B');
      expect(restored.clips.first.streetview.transition, 'map');
      expect(restored.clips.first.streetview.panZoom, true);
      expect(restored.clips.first.streetview.showControls, false);
      restored.clips.removeLast();
      expect(restored.clips.single.streetview.date, 'October 2026');
    },
  );
  test('older template durations and identifiers retain their behavior', () {
    for (final template in ['maps-place', 'tiktok-feed', 'unknown']) {
      final p = ReelProject.fromJson({
        'template': template,
        'clips': [clip('a', 'A').toJson()],
      });
      expect(p.template, template == 'unknown' ? 'maps-place' : template);
      expect(p.duration, 3);
      expect(p.startOf(0), 0);
    }
    expect(
      StreetviewTimeline.scenes(ReelProject(template: 'streetview')),
      isEmpty,
    );
    final s = StreetviewMedia.fromJson({
      'transitionSeconds': double.nan,
      'arrow': 'bad',
    });
    expect(s.transitionSeconds, .45);
    expect(s.arrow, 'right');
  });
  test(
    'portable backup deduplicates and restores captured maps with media',
    () async {
      SharedPreferences.setMockInitialValues({});
      final dir = await Directory.systemTemp.createTemp('streetview-backup');
      addTearDown(() => dir.delete(recursive: true));
      final store = ProjectStore(root: Directory('${dir.path}/store'));
      await store.initialize();
      final media = await File(
        '${dir.path}/source.jpg',
      ).writeAsBytes([1, 2, 3]);
      final map = await File('${dir.path}/map.png').writeAsBytes([4, 5, 6]);
      final p = ReelProject(
        template: 'streetview',
        clips: [
          for (final id in ['a', 'b'])
            ReelClip(
              id: id,
              path: media.path,
              name: id,
              isVideo: false,
              streetview: StreetviewMedia(
                mapPath: map.path,
                place: PlaceDetails(address: id),
              ),
            ),
        ],
      );
      final backup = await store.backup(p);
      final restored = await store.importBackup(backup);
      expect(
        restored.clips.first.streetview.mapPath,
        restored.clips.last.streetview.mapPath,
      );
      expect(
        await File(restored.clips.first.streetview.mapPath!).readAsBytes(),
        [4, 5, 6],
      );
      expect(restored.clips.first.streetview.place.address, 'a');
      expect(restored.clips.last.streetview.place.address, 'b');
      expect(await File(restored.clips.first.path).readAsBytes(), [1, 2, 3]);
      await store.save(restored);
      expect((await store.projects()).first.isStreetview, true);
    },
  );
}
