import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockareel/model/feed.dart';
import 'package:mockareel/model/project.dart';
import 'package:mockareel/widgets/home_apps_editor.dart';
import 'package:mockareel/widgets/home_app_icon.dart';
import 'package:mockareel/widgets/reel_preview.dart';

void main() {
  test(
    'reference layouts store independent app grids, docks and launch targets',
    () {
      final s = FeedSettings(homeOs: HomeOs.iphone);
      expect(s.homeApps.length, 20);
      expect(s.homeDock.map((a) => a.label), [
        'Phone',
        'Safari',
        'Mail',
        'Music',
      ]);
      s.homeApps[0].label = 'My texts';
      s.homeDock[1].label = 'Browser';
      s.moveLaunch(3);
      expect(s.homeApps[3].glyph, HomeGlyph.tiktok);
      expect(s.launchIcon.left, 276);
      expect(s.launchIcon.top, 28);
      expect(s.launchIcon.size, 68);
      expect(s.homeApps[18].glyph, HomeGlyph.camera);
      s.homeOs = HomeOs.pixel;
      expect(s.homeApps.length, 5);
      expect(s.homeDock.length, 5);
      expect(s.launchSlot, 4);
      s.weatherTemperature = '27°';
      s.homeOs = HomeOs.oneUi;
      expect(s.homeApps.length, 4);
      s.briefTitle = 'Daily brief';
      final restored = FeedSettings.fromJson(s.toJson());
      restored.homeOs = HomeOs.iphone;
      expect(restored.homeApps.first.label, 'My texts');
      expect(restored.homeDock[1].label, 'Browser');
      expect(restored.launchSlot, 3);
      expect(restored.homeApps[18].glyph, HomeGlyph.camera);
      restored.homeOs = HomeOs.oneUi;
      expect(restored.briefTitle, 'Daily brief');
      expect(restored.weatherTemperature, '27°');
    },
  );
  test(
    'old customized eight-slot projects migrate their label and icon edits',
    () {
      final restored = FeedSettings.fromJson({
        'homeOs': 'iphone',
        'appLabels': [
          'My Gallery',
          'Camera',
          'Notes',
          'TikTok',
          'Weather',
          'Music',
          'Messages',
          'Settings',
        ],
        'appIcons': [0, 1, 2, 3, 4, 5, 6, 7],
      });
      expect(restored.homeApps.first.label, 'My Gallery');
      expect(restored.homeApps.first.glyph, HomeGlyph.photos);
      expect(restored.homeApps[1].label, 'Calendar');
      final untouched = FeedSettings.fromJson({'homeOs': 'iphone'});
      expect(untouched.homeApps.first.label, 'Messages');
      expect(untouched.homeApps[1].label, 'Calendar');
    },
  );
  testWidgets(
    'classic iPhone has no dashboard, and every icon glyph paints safely',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final p = ReelProject(
        template: 'tiktok-feed',
        feed: FeedSettings(opening: 'home'),
      );
      await tester.pumpWidget(MaterialApp(home: ReelCanvas(project: p)));
      await tester.pumpAndSettle();
      expect(find.text('Calendar'), findsOneWidget);
      expect(find.text('iTunes Store'), findsOneWidget);
      expect(find.text('Safari'), findsOneWidget);
      expect(find.text('9:41 AM'), findsOneWidget);
      expect(find.text(p.feed.widgetTitle), findsNothing);
      for (final glyph in HomeGlyph.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: SizedBox(
                width: 68,
                height: 68,
                child: HomeAppIcon(glyph: glyph, os: HomeOs.iphone),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: glyph.name);
      }
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'home app editor renames a tile and moves the launch tile without losing apps',
    (tester) async {
      final s = FeedSettings();
      var changes = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: HomeAppsEditor(settings: s, onChanged: () => changes++),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Home apps & dock'));
      await tester.pumpAndSettle();
      final label = find.widgetWithText(TextFormField, 'App label');
      await tester.ensureVisible(label);
      await tester.enterText(label, 'Custom messages');
      await tester.pumpAndSettle();
      expect(s.homeApps[0].label, 'Custom messages');
      final launch = find.byKey(
        ValueKey('launch-${s.homeOs.name}-${s.launchSlot}'),
      );
      await tester.ensureVisible(launch);
      await tester.tap(launch);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('4. Camera'),
        -200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('4. Camera').last);
      await tester.pumpAndSettle();
      expect(s.launchSlot, 3);
      expect(s.homeApps[3].glyph, HomeGlyph.tiktok);
      expect(s.homeApps[18].glyph, HomeGlyph.camera);
      expect(s.homeApps[0].label, 'Custom messages');
      expect(changes, greaterThan(1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
