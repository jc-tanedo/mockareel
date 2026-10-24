import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockareel/model/maps_web_result.dart';
import 'package:mockareel/model/project.dart';
import 'package:mockareel/pages/maps_web_header_page.dart';
import 'package:mockareel/services/maps_web_header_session.dart';
import 'package:mockareel/theme/app_theme.dart';
import 'package:mockareel/widgets/browser_map_header_image.dart';
import 'package:mockareel/widgets/maps_key_dialog.dart';

class HeaderFixture implements MapsHeaderDriver {
  final Uint8List bytes;
  Rect? bounds;
  bool disposed = false;
  HeaderFixture(this.bytes);
  @override
  Future<void> initialize() async {}
  @override
  Future<void> load(PlaceDetails place) async {}
  @override
  Future<void> zoom(bool inward) async {}
  @override
  Future<Uint8List> capture(Rect physicalBounds) async {
    bounds = physicalBounds;
    return bytes;
  }

  @override
  void dispose() {
    disposed = true;
  }
}

void main() {
  test(
    'header retains an exact listing, rejects unsafe backup URLs and falls back without an API key',
    () {
      final place = PlaceDetails(
        name: 'Fixture Cafe',
        address: 'Fixture Street',
        mapsUrl:
            'https://www.google.com/maps/place/Fixture+Cafe/data=!3d12!4d123',
      );
      expect(
        MapsWebUrls.header(place).path,
        '/maps/place/Fixture+Cafe/data=!3d12!4d123',
      );
      expect(PlaceDetails.fromJson(place.toJson()).mapsUrl, place.mapsUrl);
      place.mapsUrl = 'https://example.com/private';
      expect(
        MapsWebUrls.header(place).queryParameters['query'],
        'Fixture Cafe, Fixture Street',
      );
      place.placeId = 'ChIJFixture';
      expect(
        MapsWebUrls.header(place).queryParameters['query_place_id'],
        'ChIJFixture',
      );
      final fromWeb = const MapsWebResult(
        name: 'Fixture',
        url: 'https://www.google.com/maps/place/Fixture/',
      ).toPlace();
      expect(fromWeb.mapsUrl, contains('/maps/place/Fixture/'));
      expect(() => MapsWebUrls.header(PlaceDetails()), throwsFormatException);
    },
  );

  testWidgets(
    'map framing fits phone and landscape and returns a captured header',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final driver = HeaderFixture(Uint8List.fromList([1, 2, 3]));
      Uint8List? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await Navigator.push<Uint8List>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MapsWebHeaderPage(
                      place: PlaceDetails(name: 'Fixture Cafe'),
                      driver: driver,
                      browserOverride: const ColoredBox(color: Colors.blue),
                    ),
                  ),
                );
              },
              child: const Text('Open map'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open map'));
      await tester.pumpAndSettle();
      for (final size in [
        const Size(360, 640),
        const Size(844, 390),
        const Size(390, 844),
      ]) {
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Use map header').hitTestable(), findsOneWidget);
      }
      await tester.tap(find.text('Use map header'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pumpAndSettle();
      expect(result, orderedEquals([1, 2, 3]));
      expect(driver.bounds!.width / driver.bounds!.height, closeTo(1.6, .01));
      expect(driver.disposed, isTrue);
    },
  );

  testWidgets(
    'advanced settings list required APIs and a cleared key disables API headers',
    (tester) async {
      MapsAdvancedSettings? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showDialog<MapsAdvancedSettings>(
                  context: context,
                  builder: (_) => const MapsKeyDialog(
                    initialValue: 'fixture-key',
                    useApiHeaders: true,
                  ),
                );
              },
              child: const Text('Settings'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      expect(find.textContaining('1. Places API (New)'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(result!.key, isEmpty);
      expect(result!.useApiHeaders, isFalse);
    },
  );

  testWidgets(
    'collapsed map keeps its centered location and original attribution footer',
    (tester) async {
      await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawRect(
          const Rect.fromLTWH(0, 0, 1000, 625),
          Paint()..color = const Color(0xff0000ff),
        );
        canvas.drawRect(
          const Rect.fromLTWH(0, 160, 1000, 320),
          Paint()..color = const Color(0xffff0000),
        );
        canvas.drawRect(
          const Rect.fromLTWH(0, 560, 1000, 65),
          Paint()..color = const Color(0xff00ff00),
        );
        final image = await recorder.endRecording().toImage(1000, 625);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        final dir = await Directory.systemTemp.createTemp(
          'maps-header-fixture-',
        );
        final file = File('${dir.path}/map.png');
        await file.writeAsBytes(png!.buffer.asUint8List());
        addTearDown(() => dir.delete(recursive: true));
        image.dispose();
        final boundaryKey = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: RepaintBoundary(
                key: boundaryKey,
                child: SizedBox(
                  width: 360,
                  height: 94,
                  child: BrowserMapHeaderImage(path: file.path),
                ),
              ),
            ),
          ),
        );
        await precacheImage(
          FileImage(file),
          tester.element(find.byType(BrowserMapHeaderImage)),
        );
        await tester.pumpAndSettle();
        final snapshot =
            await (boundaryKey.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage();
        final pixels = (await snapshot.toByteData())!.buffer.asUint8List();
        expect(
          pixels[(10 * 360 + 180) * 4],
          255,
          reason: 'Location stays visible in the collapsed header',
        );
        expect(
          pixels[(90 * 360 + 180) * 4 + 1],
          255,
          reason: 'Original footer stays visible',
        );
        snapshot.dispose();
      });
    },
  );
}
