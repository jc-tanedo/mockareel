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
      final keys = List.generate(84, (i) => FeedCapturePlan.key(p, search, i));
      expect(
        keys.toSet().length,
        27,
      ); // Three typed states + 24 moving-dot frames.
      expect(keys.take(20).toSet().length, 1);
      expect(keys.skip(60).toSet().length, 24);
      const opening = FeedScene('home-open', 0, 0, 2.46);
      final closing = FeedScene('home-close', 0, 0, p.feed.outroDuration);
      expect(
        List.generate(
          74,
          (i) => FeedCapturePlan.key(p, opening, i),
        ).toSet().length,
        14,
      );
      expect(
        List.generate(
          71,
          (i) => FeedCapturePlan.key(p, closing, i),
        ).toSet().length,
        12,
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
