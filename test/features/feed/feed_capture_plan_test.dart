import 'package:flutter_test/flutter_test.dart';
import 'package:mockareel/model/feed.dart';
import 'package:mockareel/model/feed_timeline.dart';
import 'package:mockareel/model/project.dart';
import 'package:mockareel/services/feed_capture_plan.dart';

void main() {
  test(
    'reuse holds and repeated graphemes, retaining all animated samples',
    () {
      final p = ReelProject(
        template: 'tiktok-feed',
        feed: FeedSettings(
          search: 'a👩🏽‍💻b',
          typingSeconds: 2,
          loadingSeconds: .8,
          homeSeconds: 2,
          closeToHome: true,
        ),
      );
      final search = FeedTimeline.scenes(p).first;
      final keys = List.generate(168, (i) => FeedCapturePlan.key(p, search, i));
      expect(
        keys.toSet().length,
        51,
      ); // Three typed states + 48 moving-dot frames at 60 fps.
      expect(keys.take(40).toSet().length, 1);
      expect(keys.skip(120).toSet().length, 48);
      const opening = FeedScene('home-open', 0, 0, 2.55);
      final closing = FeedScene('home-close', 0, 0, p.feed.outroDuration);
      expect(
        List.generate(
          153,
          (i) => FeedCapturePlan.key(p, opening, i),
        ).toSet().length,
        42,
      );
      expect(
        List.generate(
          147,
          (i) => FeedCapturePlan.key(p, closing, i),
        ).toSet().length,
        28,
      );
      const swipe = FeedScene('post', 1, 0, 3);
      expect(
        List.generate(
          12,
          (i) => FeedCapturePlan.key(p, swipe, i),
        ).toSet().length,
        12,
      );
    },
  );
}
