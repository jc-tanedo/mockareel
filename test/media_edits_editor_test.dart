import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockareel/model/project.dart';
import 'package:mockareel/services/media_edits.dart';
import 'package:mockareel/services/native_renderer.dart';
import 'package:mockareel/widgets/media_edits_editor.dart';
import 'package:mockareel/widgets/streetview_inspector.dart';
import 'support/memory_project_store.dart';

void main() {
  testWidgets(
    'map capture stays hidden until a location has been selected for that media',
    (tester) async {
      final clips = [
        for (var i = 0; i < 2; i++)
          ReelClip(id: '$i', path: 'photo.png', name: 'Photo', isVideo: false),
      ];
      final p = ReelProject(template: 'streetview', clips: clips);
      Future<void> show(int index) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StreetviewInspector(
                key: ValueKey(index),
                project: p,
                clip: clips[index],
                store: MemoryProjectStore(),
                onChanged: () {},
              ),
            ),
          ),
        ),
      );
      await show(0);
      expect(find.text('Capture map'), findsNothing);
      clips[0].streetview.place = PlaceDetails(
        name: 'Manually typed place',
        address: 'Manual address',
      );
      await show(0);
      expect(find.text('Capture map'), findsNothing);
      clips[0].streetview.locationSelected = true;
      await show(0);
      expect(find.text('Capture map'), findsOneWidget);
      await show(1);
      expect(find.text('Capture map'), findsNothing);
      clips[0].streetview = StreetviewMedia.fromJson(
        clips[0].streetview.toJson(),
      );
      await show(0);
      expect(find.text('Capture map'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'fisheye strength and draggable blur spots edit the source recipe',
    (tester) async {
      late Directory dir;
      late File photo;
      await tester.runAsync(() async {
        dir = await Directory.systemTemp.createTemp('effects-editor');
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawColor(Colors.blue, BlendMode.src);
        final picture = recorder.endRecording();
        final image = await picture.toImage(180, 300);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        photo = await File(
          '${dir.path}/source.png',
        ).writeAsBytes(png!.buffer.asUint8List());
        image.dispose();
        picture.dispose();
      });
      final clip = ReelClip(
        id: 'photo',
        path: photo.path,
        name: 'Photo',
        isVideo: false,
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        NativeRenderer.channel,
        (call) async {
          if (call.method == 'cancelMediaEdits') return null;
          final args = call.arguments as Map;
          await File(
            args['output'] as String,
          ).writeAsBytes(await photo.readAsBytes());
          return args['output'];
        },
      );
      addTearDown(() async {
        await EditedMedia.instance.cancel();
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          NativeRenderer.channel,
          null,
        );
        await dir.delete(recursive: true);
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, update) => ListView(
                children: [
                  MediaEditsEditor(clip: clip, onChanged: () => update(() {})),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Media effects'));
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump(const Duration(milliseconds: 30));
      }
      await tester.tap(find.text('Fisheye'));
      await tester.pump();
      expect(clip.edits.fisheye, true);
      tester.widget<Slider>(find.byType(Slider).first).onChanged!(.7);
      await tester.pump();
      expect(clip.edits.strength, .7);
      await tester.ensureVisible(find.text('Add blur spot (0/8)'));
      await tester.tap(find.text('Add blur spot (0/8)'));
      await tester.pump();
      expect(clip.edits.spots.length, 1);
      final semantics = tester.ensureSemantics();
      try {
        final spot = find.bySemanticsLabel('Blur spot 1');
        await tester.ensureVisible(spot);
        await tester.pump();
        expect(spot.hitTestable(), findsOneWidget);
        final drag = await tester.startGesture(tester.getCenter(spot));
        await drag.moveBy(const Offset(15, 0));
        await drag.moveBy(const Offset(25, 0));
        await drag.up();
        await tester.pump();
        expect(clip.edits.spots.single.x, greaterThan(.5));
        await tester.ensureVisible(find.byTooltip('Remove selected blur spot'));
        await tester.pump();
        await tester.tap(find.byTooltip('Remove selected blur spot'));
        await tester.pump();
        expect(clip.edits.spots, isEmpty);
        for (var i = 0; i < 40; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump(const Duration(milliseconds: 30));
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      } finally {
        semantics.dispose();
      }
    },
  );
}
