import 'package:flutter_test/flutter_test.dart';
import 'package:mockareel/model/m3_motion.dart';
import 'package:mockareel/model/streetview_layout.dart';
import 'package:mockareel/model/streetview_motion.dart';

void main() {
  test(
    'M3 Expressive springs hit endpoints and respect spatial/effects split',
    () {
      final spatials = [
        M3Motion.fastSpatial,
        M3Motion.defaultSpatial,
        M3Motion.slowSpatial,
      ];
      final effects = [
        M3Motion.fastEffects,
        M3Motion.defaultEffects,
        M3Motion.slowEffects,
      ];
      for (final sp in [...spatials, ...effects]) {
        expect(sp.eval(-1), 0.0);
        expect(sp.eval(0), 0.0);
        expect(sp.eval(1), 1.0);
        expect(sp.eval(2), 1.0);
        expect(sp.eval(double.nan), 0.0);
      }

      for (final ef in effects) {
        var prev = 0.0;
        for (var i = 0; i <= 200; i++) {
          final v = ef.eval(i / 200);
          expect(v, inInclusiveRange(prev, 1.0));
          prev = v;
        }
      }

      // Spatial springs overshoot subtly without wild oscillation.
      for (final sp in spatials) {
        var peak = 0.0;
        for (var i = 0; i <= 200; i++) {
          final v = sp.eval(i / 200);
          expect(v, greaterThanOrEqualTo(0.0));
          if (v > peak) peak = v;
        }
        expect(peak, greaterThan(1.005));
        expect(peak, lessThan(1.12));
      }

      // Cross-language goldens verified identically in Kotlin M3MotionTest.kt.
      expect(
        M3Motion.fastSpatial.eval(0.5),
        closeTo(1.0631625334491193, 1e-10),
      );
      expect(
        M3Motion.defaultSpatial.eval(0.5),
        closeTo(1.0139572459460215, 1e-10),
      );
      expect(
        M3Motion.slowSpatial.eval(0.5),
        closeTo(1.0108248967325388, 1e-10),
      );
      expect(
        M3Motion.fastEffects.eval(0.25),
        closeTo(0.6724891396950416, 1e-10),
      );
      expect(
        M3Motion.defaultEffects.eval(0.25),
        closeTo(0.7130586057331392, 1e-10),
      );
      expect(
        M3Motion.slowEffects.eval(0.25),
        closeTo(0.7078946343291297, 1e-10),
      );
    },
  );

  test(
    'Streetview container expand matches native OpenGL transform bounds',
    () {
      final start = StreetviewContainerMotion.expandAt(0, 0.42);
      expect(start.left, StreetviewLayout.thumbnailLeft);
      expect(start.top, StreetviewLayout.thumbnailTop);
      expect(start.width, StreetviewLayout.thumbnailWidth);
      expect(start.height, StreetviewLayout.thumbnailHeight);
      expect(start.radius, 12.0);
      expect(start.chromeOpacity, 0.0);

      final mid = StreetviewContainerMotion.expandAt(0.2, 0.42);
      expect(mid.left, closeTo(-0.07713334745017608, 1e-8));
      expect(mid.top, closeTo(-3.1110450138237686, 1e-8));
      expect(mid.width, closeTo(361.7869225492624, 1e-8));
      expect(mid.height, closeTo(643.7666784671503, 1e-8));
      expect(mid.radius, 0.0);

      final settled = StreetviewContainerMotion.expandAt(0.42, 0.42);
      expect(
        [
          settled.left,
          settled.top,
          settled.width,
          settled.height,
          settled.radius,
          settled.chromeOpacity,
          settled.scrimAlpha,
          settled.sheetOffset,
        ],
        [0.0, 0.0, 360.0, 640.0, 0.0, 1.0, 0.0, 0.0],
      );

      expect(
        StreetviewContainerMotion.backTapProgress(0.05, 0.55),
        greaterThan(0),
      );
      expect(StreetviewContainerMotion.backTapProgress(0.25, 0.55), -1.0);
      final backStart = StreetviewContainerMotion.shrinkAt(0.0, 0.55);
      expect(
        [backStart.left, backStart.top, backStart.width, backStart.height],
        [0.0, 0.0, 360.0, 640.0],
      );
      final backEnd = StreetviewContainerMotion.shrinkAt(0.55, 0.55);
      expect(
        [
          backEnd.left,
          backEnd.top,
          backEnd.width,
          backEnd.height,
          backEnd.radius,
        ],
        [
          StreetviewLayout.thumbnailLeft,
          StreetviewLayout.thumbnailTop,
          StreetviewLayout.thumbnailWidth,
          StreetviewLayout.thumbnailHeight,
          12.0,
        ],
      );
    },
  );
}
