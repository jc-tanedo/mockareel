import 'package:mockareel/app.dart';
// Optional visual review: flutter test tool/render_feed_preview_test.dart
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockareel/model/project.dart';
import 'package:mockareel/model/feed.dart';
import 'package:mockareel/pages/feed_editor_page.dart';
import 'package:mockareel/widgets/feed_canvas.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../test/support/memory_project_store.dart';

void main() {
  testWidgets('render feed scenes, library and editor', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final output = Directory('/tmp/mockareel-feed-preview');
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
    final p = ReelProject(
      template: 'tiktok-feed',
      title: 'Tokyo on my feed',
      feed: FeedSettings(
        search: 'a little taste of Tokyo',
        closeToHome: true,
        widgetTitle: 'Collect moments, not things',
        widgetText: 'Find a new favorite today.',
      ),
      clips: List.generate(
        3,
        (i) => ReelClip(
          id: '$i',
          path: '/tmp/mockareel-reference-preview/source-$i.png',
          name: 'Tokyo ${i + 1}.jpg',
          isVideo: false,
          duration: 2,
          post: FeedPost(
            username: ['tokyo.diary', 'little.city.finds', 'afterhours'][i],
            title: [
              'You had me at sushi',
              'The next stop on your FYP',
              'A table worth finding',
            ][i],
            caption:
                'Saving a little Tokyo moment for later. 🍣 #tokyo #foodfinds #fyp',
            verified: i == 0,
          ),
        ),
      ),
    );
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.runAsync(() async {
      for (final c in p.clips) {
        await precacheImage(
          FileImage(File(c.path)),
          tester.element(find.byType(MaterialApp)),
        );
      }
    });
    await tester.pumpAndSettle();
    final key = GlobalKey();
    Future<void> capture(String name) async {
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final image =
            await (key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        try {
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '${output.path}/$name.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
        } finally {
          image.dispose();
        }
      });
    }

    for (final entry in [
      ('search', 1.4),
      ('loading', 2.4),
      ('post', 3.3),
      ('swipe', 4.95),
      ('close', 8.95),
      ('home', 9.7),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: RepaintBoundary(
              key: key,
              child: SizedBox(
                width: 360,
                height: 640,
                child: FeedCanvas(
                  project: p,
                  position: entry.$2,
                  posterOnly: true,
                ),
              ),
            ),
          ),
        ),
      );
      await capture(entry.$1);
    }
    p.feed.opening = 'home';
    for (final os in HomeOs.values) {
      p.feed.homeOs = os;
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: RepaintBoundary(
              key: key,
              child: SizedBox(
                width: 360,
                height: 640,
                child: FeedCanvas(project: p, posterOnly: true),
              ),
            ),
          ),
        ),
      );
      await capture('home-${os.name}');
    }
    p.feed.opening = 'search';
    p.feed.homeOs = HomeOs.iphone;
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    final store = MemoryProjectStore();
    await store.save(p);
    await store.save(
      ReelProject(
        title: 'A little Tokyo find',
        headerMode: 'photo',
        place: PlaceDetails(name: 'Kura Sushi', category: 'Sushi restaurant'),
        clips: [p.clips[0]],
      ),
    );
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MockareelApp(store: store),
      ),
    );
    await capture('library');
    await tester.tap(find.text('New project'));
    await capture('templates');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text(p.title));
    await capture('editor-sequence');
    for (final tab in ['Posts', 'Audio', 'Export']) {
      await tester.tap(find.text(tab).last);
      await capture('editor-${tab.toLowerCase()}');
    }
    expect(find.byType(FeedEditorPage), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
