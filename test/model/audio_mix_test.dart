import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockareel/model/audio_mix.dart';
import 'package:mockareel/model/project.dart';
import 'package:mockareel/widgets/audio_editor.dart';

void main() {
  test(
    'AudioMix computes fade-out gain, segment unrolling, and clip volume',
    () {
      expect(
        AudioMix.musicGain(
          position: 2,
          totalDuration: 10,
          volume: .8,
          fadeOutSeconds: 2,
        ),
        closeTo(.8, 1e-6),
      );
      expect(
        AudioMix.musicGain(
          position: 9,
          totalDuration: 10,
          volume: .8,
          fadeOutSeconds: 2,
        ),
        closeTo(.4, 1e-6),
      );
      expect(
        AudioMix.musicGain(
          position: 10,
          totalDuration: 10,
          volume: .8,
          fadeOutSeconds: 2,
        ),
        closeTo(0, 1e-6),
      );
      expect(
        AudioMix.musicGain(
          position: 1,
          totalDuration: 2,
          volume: 1,
          fadeOutSeconds: 5,
        ),
        closeTo(.5, 1e-6),
      );

      final looped = AudioMix.planMusicSegments(
        sourceMs: 5000,
        trimStartMs: 1000,
        reelMs: 10000,
        loop: true,
      );
      expect(looped.length, 3);
      expect(
        (looped[0].startMs, looped[0].endMs, looped[0].timelineOffsetMs),
        (1000, 5000, 0),
      );
      expect(
        (looped[1].startMs, looped[1].endMs, looped[1].timelineOffsetMs),
        (1000, 5000, 4000),
      );
      expect(
        (looped[2].startMs, looped[2].endMs, looped[2].timelineOffsetMs),
        (1000, 3000, 8000),
      );

      final single = AudioMix.planMusicSegments(
        sourceMs: 5000,
        trimStartMs: 1000,
        reelMs: 10000,
        loop: false,
      );
      expect(single.length, 1);
      expect(single.single.endMs, 5000);

      final project = ReelProject(
        clipAudioVolume: .65,
        clips: [
          ReelClip(id: 'v', path: 'v.mp4', name: 'V', isVideo: true),
          ReelClip(
            id: 'm',
            path: 'm.mp4',
            name: 'M',
            isVideo: true,
            muted: true,
          ),
          ReelClip(
            id: 'g',
            path: 'g.gif',
            name: 'G',
            isVideo: false,
            isGif: true,
          ),
          ReelClip(id: 'p', path: 'p.jpg', name: 'P', isVideo: false),
        ],
      );
      expect(
        AudioMix.clipVolume(project, project.clips[0]),
        closeTo(.65, 1e-6),
      );
      expect(AudioMix.clipVolume(project, project.clips[1]), 0);
      expect(AudioMix.clipVolume(project, project.clips[2]), 0);
      expect(AudioMix.clipVolume(project, project.clips[3]), 0);
    },
  );

  test('audio fields preserve legacy defaults and round-trip in JSON', () {
    final legacy = ReelProject.fromJson({
      'clips': [
        {'path': 'v.mp4', 'isVideo': true},
      ],
      'music': {'path': 'song.mp3', 'sourceDuration': 12},
    });
    expect(legacy.clipAudioVolume, 0);
    expect(legacy.clips.single.muted, false);
    expect(legacy.music!.fadeOutSeconds, 0);

    final updated = ReelProject(
      clipAudioVolume: .75,
      clips: [
        ReelClip(id: '1', path: 'v.mp4', name: 'V', isVideo: true, muted: true),
      ],
      music: MusicTrack(
        path: 'song.mp3',
        name: 'Song',
        sourceDuration: 15,
        fadeOutSeconds: 2.5,
      ),
    );
    final restored = ReelProject.fromJson(updated.toJson());
    expect(restored.clipAudioVolume, closeTo(.75, 1e-6));
    expect(restored.clips.single.muted, true);
    expect(restored.music!.fadeOutSeconds, closeTo(2.5, 1e-6));
  });

  testWidgets(
    'AudioEditor toggles original clip audio, per-clip mute, and music fade-out',
    (tester) async {
      final project = ReelProject(
        music: MusicTrack(path: 'song.mp3', name: 'Track', sourceDuration: 20),
        clips: [
          ReelClip(id: '1', path: 'a.mp4', name: 'A', isVideo: true),
          ReelClip(id: '2', path: 'b.mp4', name: 'B', isVideo: true),
        ],
      );
      var changes = 0;
      Future<void> pump() => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AudioEditor(
              project: project,
              importing: false,
              onPick: () {},
              onChanged: () => changes++,
            ),
          ),
        ),
      );

      await pump();
      expect(find.text('Fade out'), findsOneWidget);
      final clipAudioToggle = find.text('Keep original video audio');
      await tester.scrollUntilVisible(clipAudioToggle, 150);
      await tester.ensureVisible(clipAudioToggle);
      await tester.pump();
      await tester.tap(clipAudioToggle);
      await pump();
      expect(project.clipAudioVolume, greaterThan(0));
      expect(changes, 1);

      final clip2Chip = find.text('Clip 2');
      await tester.scrollUntilVisible(clip2Chip, 150);
      await tester.ensureVisible(clip2Chip);
      await tester.pump();
      await tester.tap(clip2Chip);
      await pump();
      expect(project.clips[0].muted, false);
      expect(project.clips[1].muted, true);
    },
  );
}
