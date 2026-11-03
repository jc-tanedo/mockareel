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
  test('legacy signed turn angles migrate without losing rotation', () {
    final legacy = StreetviewMedia.fromJson({
      'turntable': true,
      'turntableDegrees': -12,
    });
    expect(legacy.turntableDegrees, 12);
    expect(legacy.turntableReverse, true);
    final restored = StreetviewMedia.fromJson(legacy.toJson());
    expect(restored.turntableDegrees, 12);
    expect(restored.turntableReverse, true);
    final explicit = StreetviewMedia.fromJson({
      'turntableDegrees': -12,
      'turntableReverse': false,
    });
    expect(explicit.turntableReverse, false);
    expect(explicit.turntableDegrees, 12);
    expect(
      StreetviewMedia.fromJson({'turntableDegrees': 12}).turntableReverse,
      false,
    );
    expect(
      StreetviewMedia.fromJson({'turntableDegrees': -30}).turntableDegrees,
      15,
    );
  });
  test(
    'camera projects arrows with the Android homography and holds its last frame',
    () {
      final c = moving();
      // Shared goldens are also tested against the native texture matrix.
      for (final row in [
        [0.0, 52.5287801354672, 518.2630981924528],
        [1.5, 46.826553827680854, 514.6571419475807],
        [4.0, 24.492614555768, 539.4973086337196],
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
      final poseAtStart = StreetviewMotion.at(c, 0);
      expect(poseAtStart.offsetX, 0);
      expect(poseAtStart.yaw, lessThan(0));
      final poseAtEnd = StreetviewMotion.at(c, 4);
      expect(poseAtEnd.yaw, greaterThan(0));
      c.streetview.turntableReverse = true;
      expect(StreetviewMotion.at(c, 0).yaw, greaterThan(0));
      expect(StreetviewMotion.at(c, 4).yaw, lessThan(0));
      c.streetview.turntableReverse = false;
      final restored = ReelClip.fromJson(c.toJson());
      expect(restored.streetview.slowZoom, false);
      expect(restored.streetview.slowPan, false);
      expect(restored.streetview.turntable, true);
      expect(restored.streetview.turntableReverse, false);
      expect(StreetviewMotion.native(restored), {
        'zoom': 0.0,
        'pan': 0.0,
        'turn': 12.0,
        'turnReverse': false,
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
