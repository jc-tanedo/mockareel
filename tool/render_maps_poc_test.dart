// Optional native UI review: flutter test tool/render_maps_poc_test.dart
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockareel/model/maps_web_result.dart';
import 'package:mockareel/model/project.dart';
import 'package:mockareel/pages/maps_web_search_page.dart';
import 'package:mockareel/theme/app_theme.dart';
import '../test/support/fake_maps_lookup.dart';

void main() {
  testWidgets('render native Maps POC search and import screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      final sdk = Platform.environment['FLUTTER_ROOT'];
      for (final font in [
        ('Roboto', 'Roboto-Regular.ttf'),
        ('MaterialIcons', 'MaterialIcons-Regular.otf'),
      ]) {
        await (FontLoader(font.$1)..addFont(
              File(
                '$sdk/bin/cache/artifacts/material_fonts/${font.$2}',
              ).readAsBytes().then(ByteData.sublistView),
            ))
            .load();
      }
      await Directory('/tmp/mockareel-maps-poc-ui').create(recursive: true);
    });
    final results = [
      const MapsWebResult(
        name: 'Harbor Coffee',
        url: 'https://www.google.com/maps/place/Harbor+Coffee/',
        category: 'Cafe',
        address: 'Rizal Highway, Subic Bay',
        rating: '4.6',
        reviewCount: '128',
      ),
      const MapsWebResult(
        name: 'Seaside Roastery',
        url: 'https://www.google.com/maps/place/Seaside+Roastery/',
        category: 'Coffee shop',
        address: 'Waterfront Road, Subic Bay',
        rating: '4.8',
        reviewCount: '96',
      ),
      const MapsWebResult(
        name: 'Garden Café',
        url: 'https://www.google.com/maps/place/Garden+Cafe/',
        category: 'Cafe',
        address: 'Central Business District, Subic Bay',
        rating: '4.5',
        reviewCount: '215',
      ),
    ];
    final driver = FakeMapsLookup(
      (input, name) async => name == null
          ? MapsWebSnapshot(state: 'results', results: results)
          : MapsWebSnapshot(
              state: 'place',
              place: results.first.toPlace(
                phone: '+63 900 000 0000',
                website: 'https://example.test/',
                hours: 'Open · Closes 10 PM',
              ),
              reviews: [
                FeaturedReview(
                  author: 'Sample reviewer',
                  text:
                      'A warm little café with excellent coffee and a relaxed atmosphere.',
                  rating: 5,
                ),
              ],
            ),
    );
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          home: MapsWebSearchPage(
            driver: driver,
            browserOverride: const SizedBox(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'coffee shops Subic Bay');
    await tester.tap(find.byTooltip('Search Google Maps'));
    await tester.pumpAndSettle();
    Future<void> capture(String name) async {
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final image =
            await (key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        try {
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '/tmp/mockareel-maps-poc-ui/$name.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
        } finally {
          image.dispose();
        }
      });
    }

    await capture('search');
    await tester.tap(find.text('Harbor Coffee'));
    await tester.pumpAndSettle();
    await capture('details');
    await tester.pumpWidget(const SizedBox());
  });
}
