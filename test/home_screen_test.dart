import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockareel/model/feed.dart';
import 'package:mockareel/model/project.dart';
import 'package:mockareel/pages/feed_editor_page.dart';
import 'package:mockareel/widgets/feed_canvas.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/memory_project_store.dart';

void main() {
  test(
    'home presets and visibility migrate safely and round-trip independently',
    () {
      expect(FeedSettings.fromJson({}).homeOs, HomeOs.iphone);
      expect(
        FeedSettings.fromJson({'homeOs': 'future-os'}).homeOs,
        HomeOs.iphone,
      );
      for (final os in HomeOs.values) {
        final p = ReelProject(
          template: 'tiktok-feed',
          feed: FeedSettings(
            homeOs: os,
            showIcons: false,
            showClock: false,
            showStatus: false,
            showWidget: false,
          ),
        );
        final restored = ReelProject.fromJson(p.toJson());
        expect(restored.feed.homeOs, os);
        expect(restored.feed.showIcons, false);
        expect(restored.feed.showClock, false);
        expect(restored.feed.appLabels[3], 'TikTok');
      }
    },
  );
  testWidgets(
    'all home presets fit, and icon toggle removes grid and dock only',
    (tester) async {
      final p = ReelProject(
        template: 'tiktok-feed',
        feed: FeedSettings(opening: 'home'),
      );
      for (final os in HomeOs.values) {
        p.feed.homeOs = os;
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: SizedBox(
                width: 360,
                height: 640,
                child: FeedCanvas(project: p),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('home-app-3')), findsOneWidget);
        expect(find.byKey(const ValueKey('home-dock')), findsOneWidget);
        expect(tester.takeException(), isNull, reason: os.label);
        p.feed.showIcons = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: SizedBox(
                width: 360,
                height: 640,
                child: FeedCanvas(project: p),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('home-app-3')), findsNothing);
        expect(find.byKey(const ValueKey('home-dock')), findsNothing);
        expect(
          find.text(p.feed.widgetTitle),
          os == HomeOs.android ? findsOneWidget : findsNothing,
        );
        expect(find.textContaining(p.feed.time), findsWidgets);
        p.feed.showIcons = true;
      }
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'screenshot mode preserves media pixels without dimming or duplicate chrome',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      late File file;
      late Directory dir;
      await tester.runAsync(() async {
        dir = await Directory.systemTemp.createTemp('home-pixels-');
        file = File('${dir.path}/screen.png');
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawColor(const Color(0xff30ba80), BlendMode.src);
        final picture = recorder.endRecording();
        final image = await picture.toImage(360, 640);
        picture.dispose();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        await file.writeAsBytes(bytes!.buffer.asUint8List());
      });
      addTearDown(() => dir.delete(recursive: true));
      final p = ReelProject(
        template: 'tiktok-feed',
        feed: FeedSettings(
          opening: 'home',
          showIcons: false,
          showClock: false,
          showStatus: false,
          showWidget: false,
          homeMedia: ReelClip(
            id: 'home',
            path: file.path,
            name: 'Screenshot',
            isVideo: false,
          ),
        ),
      );
      final key = GlobalKey();
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
      await tester.runAsync(() async {
        await precacheImage(
          FileImage(file),
          tester.element(find.byType(FeedCanvas)),
        );
      });
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final image =
            await (key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage();
        try {
          final bytes = await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          for (final point in [
            const Offset(10, 10),
            const Offset(180, 320),
            const Offset(300, 560),
          ]) {
            final i = (point.dy.toInt() * 360 + point.dx.toInt()) * 4;
            expect(bytes!.buffer.asUint8List(i, 4), [48, 186, 128, 255]);
          }
        } finally {
          image.dispose();
        }
      });
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'OS and screenshot controls save from the editor without losing custom labels',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final p = ReelProject(
        template: 'tiktok-feed',
        feed: FeedSettings(
          opening: 'home',
          homeMedia: ReelClip(
            id: 'screen',
            path: 'missing.png',
            name: 'Screen',
            isVideo: false,
          ),
        ),
      );
      p.feed.appLabels[0] = 'My Gallery';
      final store = MemoryProjectStore();
      await store.save(p);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: FeedEditorPage(store: store, project: p),
        ),
      );
      await tester.pumpAndSettle();
      final picker = find.byType(DropdownButtonFormField<HomeOs>);
      await tester.scrollUntilVisible(
        picker,
        160,
        scrollable: find.byType(Scrollable).last,
      );
      await Scrollable.ensureVisible(tester.element(picker), alignment: .4);
      await tester.pumpAndSettle();
      await tester.tap(picker);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Samsung · One UI').last);
      await tester.pumpAndSettle();
      final toggle = find.widgetWithText(SwitchListTile, 'Show mock app icons');
      await Scrollable.ensureVisible(tester.element(toggle), alignment: .4);
      await tester.pumpAndSettle();
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(p.feed.showIcons, false);
      expect(p.feed.showClock, true);
      final clean = find.text('Use media without overlays');
      await Scrollable.ensureVisible(tester.element(clean), alignment: .4);
      await tester.pumpAndSettle();
      await tester.tap(clean);
      await tester.pump(const Duration(milliseconds: 800));
      final saved = await store.restore();
      expect(saved.feed.homeOs, HomeOs.oneUi);
      expect(saved.feed.showIcons, false);
      expect(saved.feed.showClock, false);
      expect(saved.feed.showStatus, false);
      expect(saved.feed.showWidget, false);
      expect(saved.feed.appLabels.first, 'My Gallery');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
