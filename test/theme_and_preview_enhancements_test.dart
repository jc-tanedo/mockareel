import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockareel/model/project.dart';
import 'package:mockareel/pages/settings_page.dart';
import 'package:mockareel/services/media_importer.dart';
import 'package:mockareel/theme/app_theme.dart';
import 'package:mockareel/widgets/reel_preview.dart';
import 'package:mockareel/widgets/skeleton_loader.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Color Schemes & SettingsPage', () {
    testWidgets('allows choosing from contrasting color schemes', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await AppThemeController.instance.load();

      await tester.pumpWidget(
        MaterialApp(theme: buildAppTheme(), home: const SettingsPage()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Electric Mint'), findsOneWidget);
      expect(find.text('Sunset Ember'), findsOneWidget);
      expect(find.text('Ocean Breeze'), findsOneWidget);
      expect(find.text('Cyber Violet'), findsOneWidget);
      expect(find.text('Solar Flare'), findsOneWidget);

      await tester.tap(find.text('Sunset Ember'));
      await tester.pumpAndSettle();

      expect(AppThemeController.instance.value, AppThemePreset.sunsetEmber);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app_theme_preset'), 'sunsetEmber');

      await tester.tap(find.text('Ocean Breeze'));
      await tester.pumpAndSettle();

      expect(AppThemeController.instance.value, AppThemePreset.oceanBreeze);
      expect(prefs.getString('app_theme_preset'), 'oceanBreeze');
    });
  });

  group('Skeleton loaders', () {
    testWidgets('renders search, details, and library skeletons', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(
            body: Column(
              children: [
                Expanded(child: LocationSearchSkeleton(count: 2)),
                Expanded(child: PlaceDetailsSkeleton()),
                Expanded(child: LibrarySkeleton()),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(SkeletonShimmer), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    });
  });

  group('Timeline preview autoplay & loop', () {
    testWidgets('autoplays on media addition and respects user pause', (
      tester,
    ) async {
      final clip1 = ReelClip(
        id: 'clip1',
        path: 'photo1.jpg',
        name: 'Photo 1',
        isVideo: false,
        duration: 2.0,
      );
      final clip2 = ReelClip(
        id: 'clip2',
        path: 'photo2.jpg',
        name: 'Photo 2',
        isVideo: false,
        duration: 2.0,
      );

      final emptyProject = ReelProject(clips: const []);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TimelinePreview(project: emptyProject)),
        ),
      );
      await tester.pump();

      // At start with no media, preview is idle
      expect(find.byTooltip('Play preview'), findsOneWidget);

      // Media gets selected / added
      final project = ReelProject(clips: [clip1]);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TimelinePreview(project: project)),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      // Autoplay activates
      expect(find.byTooltip('Pause preview'), findsOneWidget);

      // User explicitly pauses the preview
      await tester.tap(find.byTooltip('Pause preview'));
      await tester.pump();
      expect(find.byTooltip('Play preview'), findsOneWidget);

      // Add a second media clip while paused
      final updatedProject = ReelProject(clips: [clip1, clip2]);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TimelinePreview(project: updatedProject)),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      // Must respect user pause and NOT autoplay on additional media import
      expect(find.byTooltip('Play preview'), findsOneWidget);

      // User explicitly plays
      await tester.tap(find.byTooltip('Play preview'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.byTooltip('Pause preview'), findsOneWidget);

      // Cleanup
      await tester.tap(find.byTooltip('Pause preview'));
      await tester.pump();
    });

    testWidgets('loops smoothly across duration when playing', (tester) async {
      final clip = ReelClip(
        id: 'clip1',
        path: 'photo.jpg',
        name: 'Photo',
        isVideo: false,
        duration: 1.0,
      );
      final emptyProject = ReelProject(clips: const []);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TimelinePreview(project: emptyProject, loop: true),
          ),
        ),
      );
      await tester.pump();

      final project = ReelProject(clips: [clip]);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: TimelinePreview(project: project, loop: true)),
        ),
      );
      await tester.pump();

      // Let ticker advance past duration
      await tester.pump(const Duration(milliseconds: 1500));
      final canvas = tester.widget<ReelCanvas>(find.byType(ReelCanvas));

      // In loop mode, position wrapped around (0.5 < 1.0) and playback is
      // active
      expect(canvas.position, closeTo(0.5, 0.2));
      expect(canvas.playing, isTrue);
      expect(find.byTooltip('Pause preview'), findsOneWidget);

      // Cleanup
      await tester.tap(find.byTooltip('Pause preview'));
      await tester.pump();
    });
  });

  group('Media importer extensions', () {
    test('supports mp4 and audio extensions for audio selection', () {
      expect(MediaImporter.audioExtensions, contains('mp4'));
      expect(MediaImporter.audioExtensions, contains('aac'));
      expect(MediaImporter.audioExtensions, contains('m4a'));
      expect(MediaImporter.audioExtensions, contains('mp3'));
    });
  });
}
