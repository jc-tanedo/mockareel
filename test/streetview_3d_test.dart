import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockareel/model/project.dart';
import 'package:mockareel/model/streetview_timeline.dart';
import 'package:mockareel/pages/template_picker_page.dart';
import 'package:mockareel/pages/library_page.dart';
import 'package:mockareel/widgets/reel_preview.dart';
import 'package:mockareel/widgets/streetview_3d_widgets.dart';

void main() {
  late Directory dir;
  late String photo;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('streetview-3d-test');
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawColor(Colors.blueGrey, BlendMode.src);
    final picture = recorder.endRecording();
    final image = await picture.toImage(360, 640);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    photo = '${dir.path}/photo.png';
    await File(photo).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
    picture.dispose();
  });

  tearDownAll(() => dir.delete(recursive: true));

  test('streetview-3d project model serialization and properties', () {
    final p = ReelProject(
      template: 'streetview-3d',
      darkOutput: true,
      clips: [
        ReelClip(
          id: 'clip1',
          name: 'Clip 1',
          path: photo,
          duration: 3,
          streetview: StreetviewMedia(
            place: PlaceDetails(name: '296 Keilor Rd', address: '296 Keilor Rd, Essendon'),
            roadLabel: 'Keilor Rd',
            railStop: 'near',
            date: 'Dec 2025',
          ),
        ),
      ],
    );

    expect(p.isStreetview, isTrue);
    expect(p.isStreetview3d, isTrue);
    expect(p.isClassicStreetview, isFalse);
    expect(p.isFeed, isFalse);

    final json = p.toJson();
    expect(json['template'], 'streetview-3d');
    expect(json['clips'][0]['streetview']['roadLabel'], 'Keilor Rd');
    expect(json['clips'][0]['streetview']['railStop'], 'near');

    final restored = ReelProject.fromJson(json);
    expect(restored.template, 'streetview-3d');
    expect(restored.isStreetview, isTrue);
    expect(restored.isStreetview3d, isTrue);
    expect(restored.clips[0].streetview.roadLabel, 'Keilor Rd');
    expect(restored.clips[0].streetview.railStop, 'near');
  });

  test('Streetview3dRailOverlay extracts clean road label fallback', () {
    final settings1 = StreetviewMedia(
      place: PlaceDetails(name: '296 Keilor Rd'),
    );
    expect(Streetview3dRailOverlay.resolveRoadName(settings1), 'Keilor Rd');

    final settings2 = StreetviewMedia(
      streetviewTitle: '343 Keilor Rd, Melbourne',
    );
    expect(Streetview3dRailOverlay.resolveRoadName(settings2), 'Keilor Rd');

    final settings3 = StreetviewMedia(
      roadLabel: 'Custom Highway',
      streetviewTitle: '10 Main St',
    );
    expect(Streetview3dRailOverlay.resolveRoadName(settings3), 'Custom Highway');
  });

  testWidgets('Streetview 3D canvas renders aerial scene on opening map and compact sheet on media', (tester) async {
    final p = ReelProject(
      template: 'streetview-3d',
      clips: [
        ReelClip(
          id: 'c1',
          path: photo,
          name: 'C1',
          duration: 3,
          streetview: StreetviewMedia(
            place: PlaceDetails(name: '296 Keilor Rd'),
            mapPath: photo,
            date: '11 months ago',
          ),
        ),
      ],
    );

    Future<void> render(double time) => tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 360,
            height: 640,
            child: ReelCanvas(
              project: p,
              position: time,
              posterOnly: true,
            ),
          ),
        ),
      ),
    );

    // Opening map scene (position 0)
    await render(0);
    expect(find.byType(Streetview3dAerialScene), findsOneWidget);
    expect(find.text('Street'), findsOneWidget);
    expect(find.byIcon(Icons.directions_walk), findsOneWidget);

    // Media scene (position = openingMapSeconds + 0.5s = 2.5s)
    await render(2.5);
    expect(find.byType(Streetview3dPlaceSheet), findsOneWidget);
    expect(find.text('296 Keilor Rd'), findsOneWidget);
    expect(find.text('11 months ago'), findsOneWidget);
    expect(find.text('See more dates >'), findsOneWidget);
    expect(find.byType(Streetview3dRailOverlay), findsOneWidget);
  });

  testWidgets('Template picker displays Streetview 3D card', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TemplatePickerPage(),
      ),
    );

    expect(find.text('Streetview 3D'), findsOneWidget);
    expect(find.text('Aerial dive & on-rails road journey'), findsOneWidget);
  });
}
