import 'package:flutter_test/flutter_test.dart';
import 'package:mockareel/model/project.dart';
import 'package:mockareel/model/streetview_motion.dart';

void main() {
  ReelClip moving() => ReelClip(
    id: 'a',
    path: 'a.jpg',
    name: 'a',
    isVideo: false,
    duration: 4,
    streetview: StreetviewMedia(
      slowZoom: true,
      slowPan: true,
      turntable: true,
      zoomAmount: .1,
      panAmount: .04,
      turntableDegrees: 12,
    ),
  );
  test(
    'camera projects arrows with the Android homography and holds its last frame',
    () {
      final c = moving();
      // Shared goldens are also tested against the native texture matrix.
      for (final row in [
        [0.0, 63.0, 498.0],
        [1.5, 48.716640205694105, 512.1070570159702],
        [4.0, 24.473041444226567, 539.6081369823565],
      ]) {
        final point = StreetviewMotion.at(c, row[0]).project(63, 498);
        expect(point.x, closeTo(row[1], .00001));
        expect(point.y, closeTo(row[2], .00001));
      }
      expect(StreetviewMotion.at(c, 4).scale, StreetviewMotion.at(c, 40).scale);
      expect(StreetviewMotion.sample(-1, 4), 0);
    },
  );
  test(
    'zoom, pan and turntable are independent and persist with their media',
    () {
      final c = moving();
      c.streetview
        ..slowZoom = false
        ..slowPan = false;
      final pose = StreetviewMotion.at(c, 2);
      expect(pose.offsetX, 0);
      expect(pose.yaw, greaterThan(0));
      final restored = ReelClip.fromJson(c.toJson());
      expect(restored.streetview.slowZoom, false);
      expect(restored.streetview.slowPan, false);
      expect(restored.streetview.turntable, true);
      expect(StreetviewMotion.native(restored), {
        'zoom': 0.0,
        'pan': 0.0,
        'turn': 12.0,
      });
      restored.streetview.turntable = false;
      expect(StreetviewMotion.active(restored), false);
      expect(StreetviewMotion.at(restored, 2).project(63, 498).x, 63);
      final legacy = StreetviewMedia.fromJson({'panZoom': true});
      expect(legacy.slowPan, true);
      expect(legacy.slowZoom, true);
      expect(legacy.turntable, false);
    },
  );
}
