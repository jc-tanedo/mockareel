import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockareel/model/project.dart';
import 'package:mockareel/model/streetview_timeline.dart';
import 'package:mockareel/widgets/media_frame.dart';
import 'package:mockareel/widgets/reel_preview.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'support/preview_video_platform.dart';

void main() {
  late Directory dir;
  late String photo;
  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('streetview-preview');
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawColor(Colors.teal, BlendMode.src);
    final picture = recorder.endRecording();
    final image = await picture.toImage(360, 640);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    photo = '${dir.path}/photo.png';
    await File(photo).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
    picture.dispose();
  });
  tearDownAll(() => dir.delete(recursive: true));
  ReelProject project({bool video = false}) => ReelProject(
    template: 'streetview',
    clips: [
      for (var i = 0; i < 2; i++)
        ReelClip(
          id: '$i',
          path: photo,
          name: '$i',
          isVideo: video,
          sourceDuration: 10,
          duration: 3,
          streetview: StreetviewMedia(
            place: PlaceDetails(name: 'Place $i', address: 'Address $i'),
            mapPath: photo,
          ),
        ),
    ],
  );
  testWidgets(
    'map screens and thumbnail use the destination media after reorder',
    (tester) async {
      final p = project();
      p.clips[0].streetview.transition = 'map';
      Future<void> show(double time) => tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 360,
              height: 640,
              child: ReelCanvas(project: p, position: time, posterOnly: true),
            ),
          ),
        ),
      );
      await show(0);
      expect(find.text('Place 0'), findsNWidgets(2));
      final later = StreetviewTimeline.scenes(
        p,
      ).where((s) => s.kind == 'map').last;
      await show(later.start);
      expect(find.text('Place 1'), findsNWidgets(2));
      final thumb = tester.widgetList<ClipPoster>(find.byType(ClipPoster)).last;
      expect(thumb.clip.id, '1');
      p.clips.insert(0, p.clips.removeLast());
      await show(0);
      expect(find.text('Place 1'), findsNWidgets(2));
      expect(
        tester.widgetList<ClipPoster>(find.byType(ClipPoster)).last.clip.id,
        '1',
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'video players preload through maps and remain stable through handoff and exact end',
    (tester) async {
      await tester.runAsync(() async {
        final previous = VideoPlayerPlatform.instance;
        final platform = PreviewVideoPlatform();
        VideoPlayerPlatform.instance = platform;
        final p = project(video: true);
        Future<void> show(double time) async {
          await tester.pumpWidget(
            MaterialApp(
              home: ReelCanvas(
                project: p,
                position: time,
                playing: true,
                posters: {
                  for (final c in p.clips) c.id: photo,
                  for (final c in p.clips) '${c.id}:end': photo,
                },
              ),
            ),
          );
          for (var i = 0; i < 30; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 10));
            await tester.pump();
            if (find.byType(VideoPlayer).evaluate().length == 2) break;
          }
        }

        VideoPlayerController player(String id) => tester
            .widget<VideoPlayer>(
              find.descendant(
                of: find.byKey(ValueKey('streetview-player-$id')),
                matching: find.byType(VideoPlayer),
              ),
            )
            .controller;
        try {
          await show(0);
          final first = player('0'), next = player('1');
          expect(first.value.isPlaying, false);
          expect(next.value.isPlaying, false);
          await show(p.startOf(0) + .5);
          expect(player('0'), same(first));
          expect(first.value.isPlaying, true);
          await show(p.startOf(1) - .1);
          expect(first.value.isPlaying, false);
          expect(next.value.isPlaying, false);
          await show(p.startOf(1) + .1);
          expect(player('1'), same(next));
          expect(next.value.isPlaying, true);
          await show(p.duration);
          expect(next.value.isPlaying, false);
          expect(platform.created, 2);
          expect(tester.takeException(), isNull);
        } finally {
          await tester.pumpWidget(const SizedBox());
          await Future<void>.delayed(Duration.zero);
          VideoPlayerPlatform.instance = previous;
        }
      });
    },
  );
  testWidgets(
    'media UI capture leaves video transparent and renders standalone output',
    (tester) async {
      final p = project();
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: RepaintBoundary(
              key: key,
              child: SizedBox(
                width: 360,
                height: 640,
                child: ReelCanvas(
                  project: p,
                  position: p.startOf(0),
                  overlayOnly: true,
                ),
              ),
            ),
          ),
        ),
      );
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final rgba = await image.toByteData();
        expect(
          rgba!.getUint8((320 * image.width + image.width ~/ 2) * 4 + 3),
          0,
        );
        image.dispose();
      });
      expect(find.text('Address 0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
