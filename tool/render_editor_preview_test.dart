import 'package:mockareel/app.dart';
// Optional editor screenshots: flutter test tool/render_editor_preview_test.dart
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockareel/model/project.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../test/support/memory_project_store.dart';

void main() {
  testWidgets('render the mobile editor for visual review', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final output = Directory('/tmp/mockareel-editor-preview');
    await tester.runAsync(() async {
      await output.create(recursive: true);
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
    });
    // This executable Flutter test lives under tool/ for optional visual review.
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.runAsync(() async {
      for (var i = 0; i < 4; i++) {
        await precacheImage(
          FileImage(File('/tmp/mockareel-reference-preview/source-$i.png')),
          tester.element(find.byType(MaterialApp)),
        );
      }
    });
    await tester.pumpAndSettle();
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    final store = MemoryProjectStore();
    await store.save(
      ReelProject(
        title: 'Tokyo after hours',
        headerMode: 'photo',
        sheetIntroSeconds: 0,
        place: PlaceDetails(
          name: 'Kura Sushi Nishishinjuku',
          category: 'Conveyor belt sushi restaurant',
          rating: '3.9',
          reviewCount: '2,186',
          hours: 'Open · Closes 00:00',
          types: ['sushi_restaurant'],
          phone: '123',
          website: 'https://example.com',
        ),
        tags: [
          StoryTag(text: 'a little Tokyo find', size: 20, y: .29),
          StoryTag(
            text: 'save this spot',
            style: 'highlight',
            size: 16,
            y: .76,
            rotation: -.05,
          ),
        ],
        clips: List.generate(
          4,
          (i) => ReelClip(
            id: '$i',
            path: '/tmp/mockareel-reference-preview/source-$i.png',
            name: 'Tokyo ${i + 1}.jpg',
            isVideo: false,
            duration: 1.56,
          ),
        ),
      ),
    );
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MockareelApp(store: store, editorProject: await store.restore()),
      ),
    );
    await tester.pumpAndSettle();
    Future<void> capture(String name) async {
      await tester.runAsync(() async {
        final image =
            await (key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '${output.path}/$name.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    for (final tab in ['Place', 'Timeline', 'Text', 'Audio', 'Export']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
      await capture(tab.toLowerCase());
      if (tab == 'Place') {
        for (final tool in ['Look', 'Header', 'Buttons', 'Review']) {
          await tester.ensureVisible(find.text(tool));
          await tester.tap(find.text(tool));
          await tester.pumpAndSettle();
          await capture('place-${tool.toLowerCase()}');
        }
      }
      if (tab == 'Timeline') {
        for (final tool in ['Frame', 'Motion']) {
          await tester.tap(find.text(tool));
          await tester.pumpAndSettle();
          await capture('timeline-${tool.toLowerCase()}');
        }
      }
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
