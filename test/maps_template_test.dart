import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mockareel/model/project.dart';
import 'package:mockareel/model/template_layout.dart';
import 'package:mockareel/services/static_map.dart';
import 'package:mockareel/services/project_store.dart';
import 'package:mockareel/widgets/template_content_editor.dart';
import 'package:mockareel/widgets/place_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'static maps use the exact retrieved coordinates and retain the requested zoom',
    () async {
      final service = StaticMapService(
        client: MockClient((r) async {
          expect(r.url.host, 'maps.googleapis.com');
          expect(r.url.queryParameters['center'], '14.58,120.98');
          expect(r.url.queryParameters['markers'], 'color:red|14.58,120.98');
          expect(r.url.queryParameters['zoom'], '17');
          expect(r.url.queryParameters['size'], '640x400');
          return http.Response.bytes(
            [1, 2, 3],
            200,
            headers: {'content-type': 'image/png'},
          );
        }),
      );
      expect(
        await service.load(
          PlaceDetails(latitude: 14.58, longitude: 120.98),
          'test-key',
          zoom: 17,
        ),
        [1, 2, 3],
      );
      service.dispose();
    },
  );
  test(
    'map failures never expose the key, including transport errors containing the URL',
    () async {
      for (final transport in [false, true]) {
        final service = StaticMapService(
          client: MockClient((r) async {
            if (transport) {
              throw http.ClientException('failed secret-key', r.url);
            }
            return http.Response('secret-key', 403);
          }),
        );
        await expectLater(
          service.load(PlaceDetails(name: 'Rizal Park'), 'secret-key'),
          throwsA(
            predicate(
              (e) =>
                  !e.toString().contains('secret-key') &&
                  e.toString().contains('map image'),
            ),
          ),
        );
        service.dispose();
      }
    },
  );
  test(
    'opening reveal eases upward and settles without changing the horizontal timeline',
    () {
      final p = ReelProject(
        sheetIntroSeconds: 1,
        clips: [
          ReelClip(
            id: 'one',
            path: 'photo',
            name: 'One',
            isVideo: false,
            duration: 2,
          ),
        ],
      );
      expect(TemplateLayout.sheetOffset(p, 0), 130);
      expect(TemplateLayout.sheetOffset(p, .5), closeTo(16.25, .0001));
      expect(TemplateLayout.sheetOffset(p, 1), 0);
      expect(TemplateLayout.sheetOffset(p, 10), 0);
      expect(p.duration, 2);
      p.sheetIntroSeconds = 0;
      expect(TemplateLayout.sheetOffset(p, 0), 0);
      final legacy = ReelProject.fromJson({'clips': []});
      expect(legacy.headerMode, 'photo');
      expect(legacy.sheetIntroSeconds, 0);
    },
  );
  test(
    'map headers and optional reviews survive backup onto another device',
    () async {
      SharedPreferences.setMockInitialValues({});
      final root = await Directory.systemTemp.createTemp('mockareel-map-');
      addTearDown(() => root.delete(recursive: true));
      final first = ProjectStore(root: Directory('${root.path}/one'));
      final second = ProjectStore(root: Directory('${root.path}/two'));
      await first.initialize();
      await second.initialize();
      final map = File('${root.path}/map.png');
      await map.writeAsBytes([9, 2, 8]);
      final p = ReelProject(
        mapHeaderPath: await first.retainMedia(map.path, 'map.png'),
        mapSource: 'upload',
        mapZoom: 17,
        sheetIntroSeconds: 1.2,
        review: FeaturedReview(
          author: 'Jose R.',
          text: 'A lovely spot.',
          rating: 4,
        ),
        place: PlaceDetails(latitude: 14.58, longitude: 120.98),
      );
      final restored = await second.importBackup(await first.backup(p));
      await Directory('${root.path}/one').delete(recursive: true);
      await map.delete();
      expect(await File(restored.mapHeaderPath!).readAsBytes(), [9, 2, 8]);
      expect(restored.headerMode, 'map');
      expect(restored.mapZoom, 17);
      expect(restored.sheetIntroSeconds, 1.2);
      expect(restored.place.latitude, 14.58);
      expect(restored.review.author, 'Jose R.');
      expect(restored.review.rating, 4);
      expect(restored.review.visible, true);
      restored.review.enabled = false;
      expect(ReelProject.fromJson(restored.toJson()).review.visible, false);
    },
  );
  testWidgets('featured review appears only with text and when enabled', (
    tester,
  ) async {
    final p = ReelProject(sheetIntroSeconds: 0);
    Future<void> draw() async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 360,
              height: 640,
              child: PlaceOverlay(project: p),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await draw();
    expect(find.text('Featured review'), findsNothing);
    p.review.text = 'A lovely spot.';
    p.review.author = 'Jose R.';
    await draw();
    expect(find.text('A lovely spot.'), findsOneWidget);
    expect(find.text('Jose R.'), findsOneWidget);
    p.review.enabled = false;
    await draw();
    expect(find.text('A lovely spot.'), findsNothing);
    p.review.enabled = true;
    p.review.text = '   ';
    await draw();
    expect(find.text('Jose R.'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'review fields and map source controls fit a narrow phone and edit the model',
    (tester) async {
      tester.view.physicalSize = const Size(360, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final p = ReelProject();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (context, setState) => TemplateContentEditor(
                  project: p,
                  loading: false,
                  onChanged: () => setState(() {}),
                  onLoadMap: () {},
                  onUploadMap: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Featured review (optional)'));
      await tester.pumpAndSettle();
      final text = find.widgetWithText(TextFormField, 'Featured review text');
      await tester.ensureVisible(text);
      await tester.enterText(text, 'Great place');
      await tester.pumpAndSettle();
      expect(p.review.visible, true);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
