import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockareel/model/project.dart';
import 'package:mockareel/model/streetview_timeline.dart';
import 'package:mockareel/model/streetview_layout.dart';
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
        p.streetview.endOnMap = true;
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
          await show(p.startOf(1) + .01);
          // An arrow transition arrives full screen, without restarting the
          // thumbnail expansion used when coming from a map.
          final incoming = find.byKey(const ValueKey('streetview-player-1'));
          expect(
            tester
                .widget<ClipRRect>(
                  find
                      .descendant(
                        of: incoming,
                        matching: find.byType(ClipRRect),
                      )
                      .first,
                )
                .borderRadius,
            BorderRadius.zero,
          );
          expect(player('1'), same(next));
          expect(next.value.isPlaying, true);
          await show(p.duration);
          expect(next.value.isPlaying, false);
          expect(next.value.position.inMilliseconds, 2999);
          final thumbnail = tester.widget<MediaFrame>(
            find.descendant(
              of: find.byKey(const ValueKey('streetview-player-1')),
              matching: find.byType(MediaFrame),
            ),
          );
          expect(thumbnail.clip.id, '1');
          expect(thumbnail.position, p.clips.last.duration);
          expect(find.byType(ClipPoster), findsNothing);
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
    'zoom out retains live surfaces and matching thumbnail bounds across maps',
    (tester) async {
      await tester.runAsync(() async {
        final previous = VideoPlayerPlatform.instance;
        final platform = PreviewVideoPlatform();
        VideoPlayerPlatform.instance = platform;
        final p = project(video: true);
        p.clips.first.streetview.transition = 'map';
        p.streetview.endOnMap = true;
        Future<void> show(double time) async {
          await tester.pumpWidget(
            MaterialApp(
              home: ReelCanvas(project: p, position: time, playing: true),
            ),
          );
          for (var attempt = 0; attempt < 200; attempt++) {
            await Future<void>.delayed(const Duration(milliseconds: 10));
            await tester.pump();
            if (find.byType(VideoPlayer).evaluate().length == 2) break;
          }
          expect(find.byType(VideoPlayer), findsNWidgets(2));
          expect(
            find.byType(ClipPoster),
            findsNothing,
            reason: 'Maps must reuse live media, without loading a new poster',
          );
        }

        Finder layer(int index) =>
            find.byKey(ValueKey('streetview-player-$index'));
        VideoPlayerController player(int index) => tester
            .widget<VideoPlayer>(
              find.descendant(
                of: layer(index),
                matching: find.byType(VideoPlayer),
              ),
            )
            .controller;
        Rect bounds(int index) {
          final positioned = tester.widget<Positioned>(layer(index));
          return Rect.fromLTWH(
            positioned.left!,
            positioned.top!,
            positioned.width!,
            positioned.height!,
          );
        }

        const thumbnail = Rect.fromLTWH(
          StreetviewLayout.thumbnailLeft,
          StreetviewLayout.thumbnailTop,
          StreetviewLayout.thumbnailWidth,
          StreetviewLayout.thumbnailHeight,
        );
        const full = Rect.fromLTWH(0, 0, 360, 640);
        try {
          await show(0);
          final first = player(0), second = player(1);
          expect(bounds(0), thumbnail);
          final seeks = platform.commands
              .where((c) => c.startsWith('seek:'))
              .length;
          await show(p.startOf(0));
          expect(bounds(0), thumbnail);
          expect(player(0), same(first));
          expect(
            platform.commands.where((c) => c.startsWith('seek:')).length,
            seeks,
          );
          await show(p.startOf(0) + .11);
          expect(bounds(0), full);

          final scenes = StreetviewTimeline.scenes(p);
          for (final back in scenes.where((s) => s.kind == 'back')) {
            final index = back.mediaIndex;
            await show(back.start + back.duration - .001);
            final shrunk = bounds(index);
            expect((shrunk.top - thumbnail.top).abs(), lessThan(1));
            expect((shrunk.height - thumbnail.height).abs(), lessThan(1));
            final held = player(index).value.position;
            await show(back.start + back.duration);
            final target = index == 0 ? 1 : index;
            expect(bounds(target), thumbnail);
            expect(
              player(index).value.position,
              held,
              reason:
                  'Outgoing and ending players must retain their final frame',
            );
            expect(player(0), same(first));
            expect(player(1), same(second));
            if (index == 0) {
              await show(p.startOf(1) - .001);
              expect(bounds(1), thumbnail);
              await show(p.startOf(1));
              expect(bounds(1), thumbnail);
              expect(player(1), same(second));
              await show(p.startOf(1) + .11);
              expect(bounds(1), full);
            }
          }
          await show(p.duration);
          expect(bounds(1), thumbnail);
          expect(second.value.isPlaying, isFalse);
          expect(platform.created, 2);
          expect(platform.disposed, isEmpty);
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
      expect(find.text('Place 0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
