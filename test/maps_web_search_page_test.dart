import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockareel/model/maps_web_result.dart';
import 'package:mockareel/model/project.dart';
import 'package:mockareel/pages/maps_web_search_page.dart';
import 'package:mockareel/theme/app_theme.dart';
import 'support/fake_maps_lookup.dart';

const fixture = MapsWebResult(
  name: 'Fixture Cafe',
  url: 'https://www.google.com/maps/place/Fixture+Cafe/',
  category: 'Cafe',
  rating: '4.6',
  address: 'Fixture street',
);
void main() {
  testWidgets(
    'native results, selected detail and optional review return an editable import',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      MapsWebImport? imported;
      final driver = FakeMapsLookup(
        (input, name) async => name == null
            ? const MapsWebSnapshot(state: 'results', results: [fixture])
            : MapsWebSnapshot(
                state: 'place',
                place: fixture.toPlace(
                  phone: '555 0000',
                  hours: 'Open 24 hours',
                ),
                reviews: [
                  FeaturedReview(
                    author: 'Fixture Reviewer',
                    text: 'A review fixture',
                    rating: 4,
                  ),
                ],
              ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  imported = await Navigator.push<MapsWebImport>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MapsWebSearchPage(
                        driver: driver,
                        browserOverride: const Center(
                          child: Text('Browser fixture'),
                        ),
                      ),
                    ),
                  );
                },
                child: const Text('Open search'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open search'));
      await tester.pumpAndSettle();
      expect(find.text('Browser fixture').hitTestable(), findsNothing);
      await tester.enterText(find.byType(TextField), 'cafes in Subic');
      await tester.tap(find.byTooltip('Search Google Maps'));
      await tester.pumpAndSettle();
      expect(find.text('Fixture Cafe'), findsOneWidget);
      await tester.tap(find.text('Fixture Cafe'));
      await tester.pumpAndSettle();
      expect(find.text('555 0000'), findsOneWidget);
      await tester.ensureVisible(find.text('Fixture Reviewer'));
      await tester.tap(find.text('Fixture Reviewer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use this place'));
      await tester.pumpAndSettle();
      expect(imported!.place.name, 'Fixture Cafe');
      expect(imported!.place.hasMenu, isTrue);
      expect(imported!.review!.text, 'A review fixture');
      expect(driver.disposed, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'cancelled lookup cannot overwrite a later search; controls fit phone and landscape',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final old = Completer<MapsWebSnapshot>();
      final driver = FakeMapsLookup(
        (input, _) => input == 'old'
            ? old.future
            : Future.value(
                const MapsWebSnapshot(state: 'results', results: [fixture]),
              ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: MapsWebSearchPage(
            driver: driver,
            browserOverride: const SizedBox(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'old');
      await tester.tap(find.byTooltip('Search Google Maps'));
      await tester.pump();
      await tester.tap(find.text('Cancel search'));
      await tester.pumpAndSettle();
      expect(driver.cancellations, 1);
      await tester.enterText(find.byType(TextField), 'new');
      await tester.tap(find.byTooltip('Search Google Maps'));
      await tester.pumpAndSettle();
      old.complete(const MapsWebSnapshot(state: 'empty'));
      await tester.pumpAndSettle();
      expect(find.text('Fixture Cafe'), findsOneWidget);
      for (final size in [const Size(360, 640), const Size(844, 390)]) {
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Show browser'));
        await tester.pumpAndSettle();
        expect(find.text('Read page'), findsOneWidget);
        await tester.tap(find.byTooltip('Hide browser'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
    },
  );
}
