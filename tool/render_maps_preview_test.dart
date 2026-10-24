// Optional visual review using the supplied reference crops, not a native MP4 recording.
// flutter test tool/render_maps_preview_test.dart
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockareel/model/project.dart';
import 'package:mockareel/widgets/reel_preview.dart';

void main() {
  testWidgets(
    'render map header, sheet reveal, gallery motion and featured review',
    (tester) async {
      final out = Directory('/tmp/mockareel-maps-preview');
      final paths = <String>[];
      await tester.runAsync(() async {
        await out.create(recursive: true);
        final reference =
            Platform.environment['MOCKAREEL_MAPS_REFERENCE'] ??
            '/workspace/mockareel-maps-reference.mp4';
        final result = await Process.run('ffmpeg', [
          '-v',
          'error',
          '-i',
          reference,
          '-vf',
          'crop=1080:640:0:0',
          '-frames:v',
          '1',
          '-y',
          '${out.path}/map.png',
        ]);
        if (result.exitCode != 0) {
          throw StateError(
            'Could not crop the reference map: ${result.stderr}',
          );
        }
        paths.add('${out.path}/map.png');
        for (var i = 0; i < 3; i++) {
          paths.add('/tmp/mockareel-reference-preview/source-$i.png');
        }
        final sdk = Platform.environment['FLUTTER_ROOT'];
        if (sdk != null) {
          for (final font in [
            ('Roboto', 'Roboto-Regular.ttf'),
            ('MaterialIcons', 'MaterialIcons-Regular.otf'),
          ]) {
            final loader = FontLoader(font.$1)
              ..addFont(
                File(
                  '$sdk/bin/cache/artifacts/material_fonts/${font.$2}',
                ).readAsBytes().then(ByteData.sublistView),
              );
            await loader.load();
          }
        }
        await tester.pumpWidget(MaterialApp(home: Container()));
        for (final path in paths) {
          await precacheImage(
            FileImage(File(path)),
            tester.element(find.byType(Container).first),
          );
        }
      });
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final p = ReelProject(
        mapHeaderPath: paths.first,
        sheetIntroSeconds: .9,
        slideSeconds: .4,
        place: PlaceDetails(
          name: 'Rizal Park',
          category: 'Park',
          rating: '4.6',
          reviewCount: '30,667',
          hours: 'Open · Closes 9 PM',
          address: 'Ermita, Manila',
          website: 'https://rizalpark.com',
        ),
        review: FeaturedReview(
          author: 'Jose R.',
          text:
              'A peaceful afternoon in the city. A great place for a walk and a few photos.',
          rating: 5,
        ),
        clips: List.generate(
          3,
          (i) => ReelClip(
            id: '$i',
            path: paths[i + 1],
            name: 'Reference photo ${i + 1}',
            isVideo: false,
            duration: 2,
            cardWidth: .78,
          ),
        ),
      );
      final key = GlobalKey();
      for (var frame = 0; frame < 72; frame++) {
        await tester.pumpWidget(
          MaterialApp(
            home: RepaintBoundary(
              key: key,
              child: ReelCanvas(
                project: p,
                position: frame / 12,
                posterOnly: true,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final image =
              await (key.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '${out.path}/frame-${frame.toString().padLeft(3, '0')}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
