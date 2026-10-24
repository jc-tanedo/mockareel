import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockareel/model/app_window_motion.dart';
import 'package:mockareel/model/feed.dart';
import 'package:mockareel/model/project.dart';
import 'package:mockareel/widgets/reel_preview.dart';

void main() {
  test(
    'spring settles exactly at the selected icon and screen without overshoot',
    () {
      for (final os in HomeOs.values) {
        final icon = HomeLayout.icon(os, 0);
        AppWindowFrame sample(bool opening, double time) => AppWindowMotion.at(
          icon: icon,
          opening: opening,
          elapsed: time,
          hold: .5,
        );
        final idle = sample(true, .5);
        expect(idle.left, icon.left);
        expect(idle.top, icon.top);
        expect(idle.width, icon.size);
        expect(idle.radius, icon.radius);
        expect(idle.opacity, 0);
        final full = sample(true, .5 + AppWindowMotion.launchSeconds);
        expect(
          [
            full.left,
            full.top,
            full.width,
            full.height,
            full.radius,
            full.opacity,
          ],
          [0, 0, 360, 640, 0, 1],
        );
        final closed = sample(false, AppWindowMotion.closeSeconds);
        expect(
          [closed.left, closed.top, closed.width, closed.opacity],
          [icon.left, icon.top, icon.size, 0],
        );
        var previous = 0.0;
        for (var i = 0; i <= 120; i++) {
          final frame = sample(
            true,
            .5 + AppWindowMotion.launchSeconds * i / 120,
          );
          expect(frame.progress, inInclusiveRange(previous, 1));
          previous = frame.progress;
        }
        expect(sample(true, .6).progress, greaterThan(.55));
        expect(
          sample(true, .6).opacity,
          1,
          reason: 'Avoid a prolonged transparent window',
        );
        expect(sample(false, .1).progress, lessThan(.35));
      }
    },
  );

  testWidgets(
    'preview advances on every vsync and preserves pause and resume',
    (tester) async {
      final p = ReelProject(
        template: 'tiktok-feed',
        feed: FeedSettings(opening: 'home'),
        clips: [
          ReelClip(
            id: 'photo',
            path: 'missing.jpg',
            name: 'Photo',
            isVideo: false,
            duration: 2,
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TimelinePreview(project: p, startAtBeginning: true),
          ),
        ),
      );
      double position() =>
          tester.widget<ReelCanvas>(find.byType(ReelCanvas)).position;
      await tester.tap(find.byTooltip('Play preview'));
      await tester.pump();
      var last = position();
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(microseconds: 8333));
        expect(
          position(),
          greaterThan(last),
          reason: 'A 120 Hz display must not wait for a 40 ms timer',
        );
        last = position();
      }
      await tester.tap(find.byTooltip('Pause preview'));
      await tester.pump();
      final paused = position();
      await tester.pump(const Duration(milliseconds: 500));
      expect(position(), paused);
      await tester.tap(find.byTooltip('Play preview'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(position(), closeTo(paused + .016, .001));
      await tester.tap(find.byTooltip('Restart preview'));
      await tester.pump();
      expect(position(), 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
