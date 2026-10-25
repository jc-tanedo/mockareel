import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockareel/model/project.dart';
import 'package:mockareel/model/template_layout.dart';
import 'package:mockareel/services/gif_videos.dart';
import 'package:mockareel/widgets/media_frame.dart';
import 'package:mockareel/widgets/reel_preview.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'support/gif_fixture.dart';
import 'support/preview_video_platform.dart';

void main() {
  testWidgets(
    'Maps GIF players persist from preload through slide and outgoing hold',
    (tester) async {
      await tester.runAsync(() async {
        final old = VideoPlayerPlatform.instance;
        final platform = PreviewVideoPlatform();
        VideoPlayerPlatform.instance = platform;
        final dir = await Directory.systemTemp.createTemp(
          'maps-gif-continuity-',
        );
        final file = File('${dir.path}/source.gif');
        await file.writeAsBytes(timedGifFixture);
        final clips = [
          for (var i = 0; i < 4; i++)
            ReelClip(
              id: 'gif-$i',
              path: file.path,
              name: 'GIF $i',
              isVideo: false,
              isGif: true,
              sourceDuration: .6,
              duration: 3,
            ),
        ];
        final project = ReelProject(clips: clips);
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          GifVideos.channel,
          (call) async {
            if (call.method == 'cancel') return null;
            await File(
              (call.arguments as Map)['output'] as String,
            ).writeAsBytes([1, 2, 3]);
            return null;
          },
        );
        String? cache;
        Future<void> show(double time) async {
          await tester.pumpWidget(
            MaterialApp(
              home: ReelCanvas(project: project, position: time, playing: true),
            ),
          );
          for (var attempt = 0; attempt < 50; attempt++) {
            await Future<void>.delayed(const Duration(milliseconds: 10));
            await tester.pump();
            if (find.byType(VideoPlayer).evaluate().length ==
                find.byType(MediaFrame).evaluate().length) {
              break;
            }
          }
          await tester.pump();
        }

        VideoPlayerController player(int i) => tester
            .widget<VideoPlayer>(
              find.descendant(
                of: find.byKey(ValueKey('gallery-gif-$i')),
                matching: find.byType(VideoPlayer),
              ),
            )
            .controller;
        try {
          cache = await GifVideos.instance.video(clips.first);
          await show(0);
          final upcoming = player(1), first = player(0);
          expect(upcoming.value.isPlaying, isFalse);
          expect(platform.created, 2);
          final start = project.startOf(1),
              slide = TemplateLayout.transitionDuration(project, 1);
          await show(start + .01);
          expect(player(1), same(upcoming));
          expect(player(0), same(first));
          expect(first.value.isPlaying, isFalse);
          expect(upcoming.value.isPlaying, isTrue);
          final count = platform.created;
          int heldCommands() => platform.commands
              .where((command) => command.split(':')[1] == '${first.playerId}')
              .length;
          final commands = heldCommands();
          expect(first.value.position.inMilliseconds, 2966);
          await show(start + slide + .01);
          expect(
            heldCommands(),
            commands,
            reason: 'Held cards must not repeatedly seek or pause',
          );
          expect(player(1), same(upcoming));
          expect(player(0), same(first));
          expect(platform.created, count);
          final next = player(2);
          await show(project.startOf(2) + .01);
          expect(player(1), same(upcoming));
          expect(player(2), same(next));
          expect(upcoming.value.isPlaying, isFalse);
          expect(next.value.isPlaying, isTrue);
          expect(platform.created, lessThanOrEqualTo(4));
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox());
          await Future<void>.delayed(Duration.zero);
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            GifVideos.channel,
            null,
          );
          VideoPlayerPlatform.instance = old;
          if (cache != null && await File(cache).exists()) {
            await File(cache).delete();
          }
          await dir.delete(recursive: true);
        }
      });
    },
  );
  testWidgets('preview final pause wins over a late native play command', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final old = VideoPlayerPlatform.instance;
      final platform = PreviewVideoPlatform();
      VideoPlayerPlatform.instance = platform;
      final clip = ReelClip(
        id: 'gif',
        path: 'source.gif',
        name: 'GIF',
        isVideo: false,
        isGif: true,
        sourceDuration: 1,
        duration: 1,
      );
      Future<void> show(double position, bool playing) async {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaFrame(
              clip: clip,
              position: position,
              playing: playing,
              gifVideoBuilder: (_) async => 'prepared.mp4',
            ),
          ),
        );
        await Future<void>.delayed(Duration.zero);
        await tester.pump();
        await tester.pump();
      }

      try {
        await show(0, false);
        final controller = tester
            .widget<VideoPlayer>(find.byType(VideoPlayer))
            .controller;
        final started = Completer<void>(), gate = Completer<void>();
        platform.playBarrier = () {
          if (!started.isCompleted) started.complete();
          return gate.future;
        };
        await show(.1, true);
        await started.future;
        await show(1, true);
        gate.complete();
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
        expect(controller.value.isPlaying, isFalse);
        expect(
          platform.nativePlaying.values.every((playing) => !playing),
          isTrue,
        );
        expect(platform.commands.last, startsWith('pause:'));
        expect(controller.value.position.inMilliseconds, 966);
        final count = platform.commands.length;
        await Future<void>.delayed(const Duration(milliseconds: 120));
        await tester.pump();
        expect(platform.commands.length, count);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await Future<void>.delayed(Duration.zero);
        VideoPlayerPlatform.instance = old;
      }
    });
  });
  testWidgets('Maps timeline stops all media at its end and stays paused', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final old = VideoPlayerPlatform.instance;
      final platform = PreviewVideoPlatform();
      VideoPlayerPlatform.instance = platform;
      final project = ReelProject(
        clips: [
          ReelClip(
            id: 'video',
            path: 'video.mp4',
            name: 'Video',
            isVideo: true,
            sourceDuration: 30,
            duration: 2,
          ),
        ],
      );
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: TimelinePreview(project: project)),
          ),
        );
        await Future<void>.delayed(Duration.zero);
        await tester.pump();
        await tester.pump();
        await tester.tap(find.byTooltip('Play preview'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 3));
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
        final canvas = tester.widget<ReelCanvas>(find.byType(ReelCanvas));
        final controller = tester
            .widget<VideoPlayer>(find.byType(VideoPlayer))
            .controller;
        expect(canvas.position, 2);
        expect(canvas.playing, isFalse);
        expect(controller.value.isPlaying, isFalse);
        expect(
          platform.nativePlaying.values.every((playing) => !playing),
          isTrue,
        );
        expect(find.byTooltip('Play preview'), findsOneWidget);
        final count = platform.commands.length;
        await tester.pump(const Duration(seconds: 2));
        await Future<void>.delayed(Duration.zero);
        expect(platform.commands.length, count);
        expect(controller.value.isPlaying, isFalse);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await Future<void>.delayed(Duration.zero);
        VideoPlayerPlatform.instance = old;
      }
    });
  });
}
