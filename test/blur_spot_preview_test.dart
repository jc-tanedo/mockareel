import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockareel/model/media_edits.dart';
import 'package:mockareel/widgets/blur_spot_preview.dart';

void main() {
  testWidgets(
    'tiny blur has a 64px target, drags without jumping and magnifies its landing point',
    (tester) async {
      final spot = BlurSpot(radius: .025);
      var committed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                height: 260,
                child: StatefulBuilder(
                  builder: (context, update) => BlurSpotPreview(
                    sourceSize: const Size(1200, 2400),
                    image: const ColoredBox(
                      key: ValueKey('photo'),
                      color: Colors.blue,
                    ),
                    spots: [spot],
                    selected: spot.id,
                    onSelect: (_) => update(() {}),
                    onChanged: () {
                      committed++;
                      update(() {});
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final semantics = tester.ensureSemantics();
      final handle = find.bySemanticsLabel('Blur spot 1');
      expect(tester.getSize(handle), const Size(64, 64));
      // Start outside the tiny visible blur, inside the enlarged touch target.
      final start = tester.getCenter(handle) + const Offset(25, 0);
      final gesture = await tester.startGesture(start);
      await gesture.moveBy(const Offset(24, 12));
      await tester.pump();
      await gesture.moveBy(const Offset(10, 6));
      await tester.pump();
      final image = tester.getRect(find.byKey(const ValueKey('photo')));
      expect(spot.x, closeTo(.5 + 34 / image.width, .001));
      expect(spot.y, closeTo(.5 + 18 / image.height, .001));
      final magnifier = find.byType(RawMagnifier);
      expect(
        committed,
        0,
        reason: 'Do not queue a source render on every pointer event.',
      );
      expect(magnifier, findsOneWidget);
      final lens = tester.getRect(magnifier);
      final glass = tester.widget<RawMagnifier>(magnifier);
      expect(glass.magnificationScale, 2);
      expect(lens.bottom, lessThan(start.dy + 18));
      final focal = lens.center + glass.focalPointOffset;
      expect(focal.dx, closeTo(image.left + spot.x * image.width, .001));
      expect(focal.dy, closeTo(image.top + spot.y * image.height, .001));
      await gesture.up();
      await tester.pump();
      expect(find.byType(RawMagnifier), findsNothing);
      expect(committed, 1);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );
  testWidgets(
    'edge drags stay bounded and removing the preview removes its magnifier',
    (tester) async {
      tester.view.physicalSize = const Size(390, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final spot = BlurSpot(x: 0, y: 0, radius: .025);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 360,
                height: 260,
                child: BlurSpotPreview(
                  sourceSize: const Size(1200, 2400),
                  image: const ColoredBox(color: Colors.blue),
                  spots: [spot],
                  selected: spot.id,
                  onSelect: (_) {},
                  onChanged: () {},
                ),
              ),
            ),
          ),
        ),
      );
      final semantics = tester.ensureSemantics();
      final gesture = await tester.startGesture(
        tester.getCenter(find.bySemanticsLabel('Blur spot 1')),
      );
      await gesture.moveBy(const Offset(24, 12));
      await tester.pump();
      var lens = tester.getRect(find.byType(RawMagnifier));
      expect(lens.left, greaterThanOrEqualTo(0));
      expect(lens.top, greaterThanOrEqualTo(0));
      expect(lens.right, lessThanOrEqualTo(390));
      await gesture.moveTo(const Offset(388, 638));
      await tester.pump();
      expect(spot.x, 1);
      expect(spot.y, 1);
      lens = tester.getRect(find.byType(RawMagnifier));
      expect(lens.right, lessThanOrEqualTo(390));
      expect(lens.bottom, lessThanOrEqualTo(640));
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(find.byType(RawMagnifier), findsNothing);
      await gesture.up();
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );
}
