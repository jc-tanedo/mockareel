import 'package:mockareel/model/feed_timeline.dart';
import 'package:mockareel/app.dart';
import 'package:mockareel/pages/exported_video_page.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mockareel/model/project.dart';
import 'package:mockareel/model/feed.dart';
import 'package:mockareel/pages/feed_editor_page.dart';
import 'package:mockareel/services/native_renderer.dart';
import 'package:mockareel/services/project_store.dart';
import 'package:path_provider/path_provider.dart';
import 'video_fixture.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('mixed media → preview → MP4 → gallery → reopen backup', (
    tester,
  ) async {
    final root = Directory(
      '${(await getApplicationDocumentsDirectory()).path}/integration-${newId()}',
    );
    final store = ProjectStore(root: root);
    await store.initialize();
    Future<String> photo(String name, Color color) async {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawColor(color, BlendMode.src);
      final picture = recorder.endRecording();
      final image = await picture.toImage(720, 1280);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      picture.dispose();
      final file = File('${root.path}/media/$name.png');
      await file.writeAsBytes(png!.buffer.asUint8List());
      return file.path;
    }

    final red = await photo('red', const Color(0xffd72e2e));
    final green = await photo('green', const Color(0xff20a080));
    final video = File('${root.path}/media/video.mp4');
    await video.writeAsBytes(base64Decode(testVideoBase64));
    final renderer = NativeRenderer();
    final source = await renderer.inspect(video.path);
    expect(source['hasAudio'], true);
    expect(source['duration'], greaterThanOrEqualTo(3));
    final project = ReelProject(
      title: 'Export integration',
      headerMode: 'map',
      mapHeaderPath: green,
      review: FeaturedReview(
        author: 'Integration reviewer',
        text: 'A good place to visit.',
        rating: 4,
      ),
      music: MusicTrack(
        path: video.path,
        name: 'Fixture soundtrack',
        sourceDuration: (source['duration'] as num).toDouble(),
        trimStart: 2.2,
        volume: .4,
      ),
      tags: [
        StoryTag(text: 'A new find', x: .35, y: .3),
        StoryTag(text: 'Save this spot', y: .78, style: 'plain'),
      ],
      place: PlaceDetails(
        name: 'Mockareel Test Cafe',
        category: 'Coffee shop',
        rating: '4.7',
        address: 'Makati, Philippines',
      ),
      clips: [
        ReelClip(
          id: 'red',
          path: red,
          name: 'Red photo',
          isVideo: false,
          duration: .5,
          caption: 'Photo scene',
        ),
        ReelClip(
          id: 'video',
          path: video.path,
          name: 'Blue video',
          isVideo: true,
          duration: .75,
          trimStart: 1,
          sourceDuration: (source['duration'] as num).toDouble(),
          caption: 'Trimmed video',
        ),
        ReelClip(
          id: 'green',
          path: green,
          name: 'Green photo',
          isVideo: false,
          duration: .5,
          caption: 'Final scene',
        ),
      ],
    );
    await store.save(project);
    // Missing inputs must fail cleanly without leaving the renderer busy.
    final missing = ReelProject(
      clips: [
        ReelClip(
          id: 'missing',
          path: '/missing.mp4',
          name: 'Missing',
          isVideo: true,
        ),
      ],
    );
    await expectLater(
      renderer.export(missing, [red]),
      throwsA(isA<PlatformException>()),
    );
    await tester.pumpWidget(
      MockareelApp(store: store, editorProject: await store.restore()),
    );
    Future<void> waitFor(Finder finder, {int seconds = 120}) async {
      final deadline = DateTime.now().add(Duration(seconds: seconds));
      while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(finder, findsWidgets);
    }

    await waitFor(find.byTooltip('Save project'));
    await tester.tap(find.text('Timeline').last);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byTooltip('Play preview').last);
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.text('Export').last);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Render MP4'));
    await waitFor(find.text('Your reel is ready'), seconds: 240);
    final page = tester.widget<ExportedVideoPage>(
      find.byType(ExportedVideoPage),
    );
    final output = await renderer.inspect(page.path);
    expect(output['width'], 1080);
    expect(output['height'], 1920);
    expect(output['duration'] as num, closeTo(project.duration, .15));
    expect(output['hasAudio'], true);
    expect(output['size'] as num, greaterThan(10000));
    // Retain the result for host-side ffprobe and frame inspection.
    debugPrint('EXPORTED_TEST_PATH=${page.path}');
    await tester.tap(find.text('Save to gallery'));
    await waitFor(find.text('Saved to Movies/Mockareel'));
    final backup = await store.backup(project);
    final restored = await store.importBackup(backup);
    expect(restored.clips.map((c) => c.caption), [
      'Photo scene',
      'Trimmed video',
      'Final scene',
    ]);
    expect(restored.clips[1].trimStart, 1);
    expect(restored.music!.volume, .4);
    expect(restored.music!.trimStart, 2.2);
    expect(await File(restored.music!.path).exists(), true);
    expect(restored.tags.length, 2);
    expect(await File(restored.mapHeaderPath!).exists(), true);
    expect(restored.review.rating, 4);
    for (final c in restored.clips) {
      expect(await File(c.path).exists(), true);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    final feed = ReelProject(
      template: 'tiktok-feed',
      title: 'Feed export integration',
      slideSeconds: .2,
      feed: FeedSettings(
        search: 'test feed',
        typingSeconds: .5,
        loadingSeconds: .2,
        closeToHome: true,
        homeSeconds: .5,
        homeMedia: ReelClip(
          id: 'wallpaper',
          path: video.path,
          name: 'Looping wallpaper',
          isVideo: true,
          sourceDuration: (source['duration'] as num).toDouble(),
          duration: .5,
        ),
      ),
      clips: project.clips.map((c) => ReelClip.fromJson(c.toJson())).toList(),
      music: project.music,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: FeedEditorPage(store: store, project: feed),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Export').last);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Render MP4'));
    await waitFor(find.text('Your reel is ready'), seconds: 240);
    final feedPage = tester.widget<ExportedVideoPage>(
      find.byType(ExportedVideoPage),
    );
    final feedOutput = await renderer.inspect(feedPage.path);
    expect(feedOutput['width'], 1080);
    expect(feedOutput['height'], 1920);
    expect(
      feedOutput['duration'] as num,
      closeTo(FeedTimeline.duration(feed), .2),
    );
    expect(feedOutput['hasAudio'], true);
    debugPrint('EXPORTED_FEED_TEST_PATH=${feedPage.path}');
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(minutes: 8)));
}
