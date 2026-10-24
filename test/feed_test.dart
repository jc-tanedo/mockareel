import 'package:mockareel/model/feed_timeline.dart';
import 'package:mockareel/app.dart';
import 'package:mockareel/pages/maps_editor_page.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockareel/model/project.dart';
import 'package:mockareel/model/feed.dart';
import 'package:mockareel/pages/feed_editor_page.dart';
import 'package:mockareel/services/native_renderer.dart';
import 'package:mockareel/services/project_store.dart';
import 'package:mockareel/widgets/feed_canvas.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/memory_project_store.dart';

ReelProject sample() => ReelProject(
  template: 'tiktok-feed',
  title: 'Weekend feed',
  feed: FeedSettings(search: 'weekend inspiration', closeToHome: true),
  clips: [
    for (var i = 0; i < 2; i++)
      ReelClip(
        id: '$i',
        path: 'missing-$i.jpg',
        name: 'Photo $i',
        isVideo: false,
        duration: 3,
        post: FeedPost(
          username: 'poster$i',
          title: 'Title $i',
          caption: 'Caption $i',
        ),
      ),
  ],
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'feed scene boundaries include typed search, posts and closing; blank search skips',
    () {
      final p = sample();
      final scenes = FeedTimeline.scenes(p);
      expect(scenes.map((s) => s.kind), [
        'search',
        'post',
        'post',
        'home-close',
      ]);
      expect(FeedTimeline.at(p, 2.799).kind, 'search');
      expect(FeedTimeline.at(p, 2.8).postIndex, 0);
      expect(FeedTimeline.at(p, 5.8).postIndex, 1);
      expect(FeedTimeline.at(p, 8.8).kind, 'home-close');
      expect(FeedTimeline.duration(p), closeTo(11.16, .0001));
      expect(FeedTimeline.entry(p, 1, 0), 640);
      expect(FeedTimeline.entry(p, 1, p.slideSeconds), 0);
      p.feed.search = '  ';
      expect(FeedTimeline.scenes(p).first.kind, 'post');
      p.feed.opening = 'home';
      expect(FeedTimeline.scenes(p).first.kind, 'home-open');
      expect(FeedTimeline.postStart(p, 1), 5.46);
      final old = ReelProject.fromJson({'clips': []});
      expect(old.isFeed, false);
    },
  );
  test(
    'portable feed includes each profile photo, home video and all edited UI',
    () async {
      final dir = await Directory.systemTemp.createTemp('feed-backup-');
      addTearDown(() => dir.delete(recursive: true));
      final store = ProjectStore(root: Directory('${dir.path}/a'));
      await store.initialize();
      final p = sample();
      for (var i = 0; i < p.clips.length; i++) {
        final c = p.clips[i]; // Paths are replaced by owned fixture data below.
        final path = File('${dir.path}/photo-$i.jpg');
        await path.writeAsBytes([i, 2, 3]);
        p.clips[i] = ReelClip(
          id: c.id,
          path: path.path,
          name: c.name,
          isVideo: false,
          post: c.post,
        );
        final avatar = File('${dir.path}/avatar-$i.png');
        await avatar.writeAsBytes([9, i]);
        p.clips[i].post.avatarPath = avatar.path;
      }
      final home = File('${dir.path}/home.mp4');
      await home.writeAsBytes([5, 6, 7]);
      p.feed.homeMedia = ReelClip(
        id: 'home',
        path: home.path,
        name: 'Wallpaper',
        isVideo: true,
        sourceDuration: 2,
      );
      p.feed.appLabels[0] = 'Gallery';
      p.feed.appIcons[0] = 9;
      p.feed.showWidget = false;
      p.feed.homeOs = HomeOs.pixel;
      p.feed.homeApps[0].label = 'Work';
      p.feed.homeDock[2].glyph = HomeGlyph.tiktok;
      p.feed.moveLaunch(0);
      p.feed.weatherTemperature = '28°';
      p.feed.showIcons = false;
      p.feed.showClock = false;
      p.clips[1].post.verified = true;
      p.clips[1].post.likes = '1.2M';
      await store.save(p);
      final backup = await store.backup(p);
      final target = ProjectStore(root: Directory('${dir.path}/b'));
      await target.initialize();
      final restored = await target.importBackup(backup);
      for (var i = 0; i < 2; i++) {
        expect(await File(restored.clips[i].post.avatarPath!).readAsBytes(), [
          9,
          i,
        ]);
        expect(restored.clips[i].post.username, 'poster$i');
        expect(restored.clips[i].id, isNot(p.clips[i].id));
      }
      expect(restored.isFeed, true);
      expect(restored.feed.search, p.feed.search);
      expect(restored.feed.appLabels.first, 'Gallery');
      expect(restored.feed.appIcons.first, 9);
      expect(restored.feed.showWidget, false);
      expect(restored.feed.homeOs, HomeOs.pixel);
      expect(restored.feed.homeApps[4].label, 'Work');
      expect(restored.feed.homeDock[2].glyph, HomeGlyph.tiktok);
      expect(restored.feed.launchSlot, 0);
      expect(restored.feed.weatherTemperature, '28°');
      expect(restored.feed.showIcons, false);
      expect(restored.feed.showClock, false);
      expect(restored.clips[1].post.verified, true);
      expect(restored.clips[1].post.likes, '1.2M');
      expect(await File(restored.feed.homeMedia!.path).readAsBytes(), [
        5,
        6,
        7,
      ]);
    },
  );
  testWidgets(
    'library creates both template types and editor back saves into grid',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = MemoryProjectStore();
      await tester.pumpWidget(MockareelApp(store: store));
      await tester.pumpAndSettle();
      expect(find.text('Your projects'), findsOneWidget);
      await tester.tap(find.text('New project'));
      await tester.pumpAndSettle();
      expect(find.text('Maps place story'), findsOneWidget);
      await tester.tap(find.text('TikTok FYP scroll'));
      await tester.pumpAndSettle();
      expect(find.byType(FeedEditorPage), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Search query'),
        'My custom search',
      );
      await tester.pump(const Duration(milliseconds: 800));
      await tester.tap(find.byTooltip('Back to projects'));
      await tester.pumpAndSettle();
      expect(find.text('Untitled feed'), findsOneWidget);
      expect((await store.projects()).single.feed.search, 'My custom search');
      await tester.tap(find.text('Untitled feed'));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(TextFormField, 'My custom search'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Back to projects'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New project'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Maps place story'));
      await tester.pumpAndSettle();
      expect(find.byType(MapsEditorPage), findsOneWidget);
      await tester.tap(find.byTooltip('Back to projects'));
      await tester.pumpAndSettle();
      expect((await store.projects()).length, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'post edits remain independent, saved and usable at short and wide sizes',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = MemoryProjectStore();
      final p = sample();
      await store.save(p);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: FeedEditorPage(store: store, project: p),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Posts').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Username'),
        'changed',
      );
      await tester.pump(const Duration(milliseconds: 800));
      await tester.tap(find.text('Caption').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Post title'),
        'New headline',
      );
      await tester.pump(const Duration(milliseconds: 800));
      expect(p.clips.first.post.username, 'changed');
      expect(p.clips[1].post.username, 'poster1');
      expect((await store.restore()).clips.first.post.title, 'New headline');
      for (final size in [const Size(360, 640), const Size(844, 390)]) {
        tester.view.physicalSize = size;
        for (final label in ['Sequence', 'Posts', 'Audio', 'Export']) {
          await tester.tap(find.text(label).last);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '$size $label');
        }
      }
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'remove post stays visible, saves, supports undo and handles the last post',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = MemoryProjectStore();
      final p = sample();
      await store.save(p);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(useMaterial3: true),
          home: FeedEditorPage(store: store, project: p),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Posts').last);
      await tester.pumpAndSettle();
      for (final tool in ['Caption', 'Stats', 'Timing & frame', 'Identity']) {
        await tester.ensureVisible(find.text(tool).last);
        await tester.tap(find.text(tool).last);
        await tester.pumpAndSettle();
        expect(find.text('Remove post').hitTestable(), findsOneWidget);
      }
      final original = p.clips.first;
      await tester.tap(find.text('Remove post'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 800));
      expect(p.clips.length, 1);
      expect((await store.restore()).clips.single.id, p.clips.single.id);
      expect(find.widgetWithText(TextFormField, 'poster1'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 800));
      expect(p.clips.first, same(original));
      expect((await store.restore()).clips.length, 2);
      expect(find.widgetWithText(TextFormField, 'poster0'), findsOneWidget);
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.text('Remove post'));
        await tester.pumpAndSettle();
      }
      await tester.pump(const Duration(milliseconds: 800));
      expect(p.clips, isEmpty);
      expect((await store.restore()).clips, isEmpty);
      expect(find.text('One post per photo or video'), findsOneWidget);
      expect(find.text('Remove post'), findsNothing);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(p.clips.single.post.username, 'poster1');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'all output scenes including mid-swipe and app close fit the canvas',
    (tester) async {
      final p = sample();
      p.feed.widgetTitle = 'A long widget title that takes two lines';
      for (final time in [0.0, 1.0, 2.4, 2.8, 5.9, 6.3, 8.9, 9.5, 10.0]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: SizedBox(
                width: 360,
                height: 640,
                child: FeedCanvas(project: p, position: time, posterOnly: true),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'scene at $time');
      }
      p.feed.opening = 'home';
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 360,
            height: 640,
            child: FeedCanvas(project: p, position: 2.3, posterOnly: true),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  test(
    'native feed request preserves scene lengths, animated UI, crop and music',
    () async {
      Map? arguments;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(NativeRenderer.channel, (call) async {
            arguments = call.arguments as Map;
            return '/tmp/feed.mp4';
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(NativeRenderer.channel, null),
      );
      final p = sample();
      p.clips.first.zoom = 1.8;
      await NativeRenderer().exportFeed(
        clips: p.clips.map((c) => c.toJson()).toList(),
        overlays: ['a.png', 'b.png'],
        frames: [
          [],
          ['frame.png'],
        ],
        transitions: [0, .42],
        music: MusicTrack(path: 'song.mp3', name: 'song', sourceDuration: 20),
      );
      expect(arguments!['template'], 'tiktok-feed');
      expect((arguments!['clips'] as List).first['zoom'], 1.8);
      expect(arguments!['sceneFrames'], [
        [],
        ['frame.png'],
      ]);
      expect(arguments!['transitions'], [0, .42]);
      expect((arguments!['music'] as Map)['path'], 'song.mp3');
    },
  );
}
