import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockareel/model/maps_web_result.dart';

void main() {
  test('URL inputs stay on Google Maps HTTPS and preserve query text', () {
    final query = MapsWebUrls.search('café & hardware Subic');
    expect(query.host, 'www.google.com');
    expect(query.queryParameters['query'], 'café & hardware Subic');
    expect(
      MapsWebUrls.search('https://maps.app.goo.gl/example').host,
      'maps.app.goo.gl',
    );
    for (final value in [
      'http://www.google.com/maps',
      'https://example.com/maps',
      'https://www.google.com.evil.test/maps',
      'https://user@www.google.com/maps',
      'https://www.google.com/search?q=test',
      'javascript://example.com',
    ]) {
      expect(
        () => MapsWebUrls.search(value),
        throwsFormatException,
        reason: value,
      );
    }
    expect(
      MapsWebUrls.allowedNavigation(Uri.parse('intent://www.google.com/maps')),
      isFalse,
    );
    expect(
      MapsWebUrls.allowedNavigation(Uri.parse('https://accounts.google.com/')),
      isFalse,
    );
  });
  test(
    'target coordinates and Places ID are imported without confusing viewport or feature IDs',
    () {
      const item = MapsWebResult(
        name: 'Fixture Cafe',
        url:
            'https://www.google.com/maps/place/Cafe/@1,2,3z/data=!1s0x1:0x2!3d14.8!4d120.2!19sChIJfixture',
        category: 'Cafe',
      );
      final place = item.toPlace();
      expect(place.latitude, 14.8);
      expect(place.longitude, 120.2);
      expect(place.placeId, 'ChIJfixture');
      expect(place.hasMenu, isTrue);
      final store = const MapsWebResult(
        name: 'Fixture Hardware',
        url:
            'https://www.google.com/maps/place/Hardware/@1,2,3z/data=!1s0x1:0x2',
        category: 'Hardware store',
      ).toPlace();
      expect(store.latitude, isNull);
      expect(store.longitude, isNull);
      expect(store.placeId, isNull);
      expect(store.hasMenu, isFalse);
    },
  );
  test(
    'WebView JSON encoding variants retain contacts and optional reviews',
    () {
      final data = {
        'state': 'place',
        'href': 'https://www.google.com/maps/place/Fixture/',
        'place': {
          'name': 'Fixture Cafe',
          'url': 'https://www.google.com/maps/place/Fixture/',
          'category': 'Cafe',
          'rating': '4.6',
          'reviewCount': '123',
          'phone': '+1 555 0000',
          'website': 'https://example.test/',
          'hours': 'Open 24 hours',
          'reviews': [
            {
              'author': 'Fixture Reviewer',
              'text': 'A review fixture',
              'rating': 4,
            },
          ],
        },
      };
      for (final raw in [jsonEncode(data), jsonEncode(jsonEncode(data))]) {
        final parsed = MapsWebSnapshot.decode(raw);
        expect(parsed.place!.name, 'Fixture Cafe');
        expect(parsed.place!.phone, '+1 555 0000');
        expect(parsed.place!.reviewCount, '123');
        expect(parsed.place!.hours, 'Open 24 hours');
        expect(parsed.reviews.single.author, 'Fixture Reviewer');
        expect(parsed.reviews.single.rating, 4);
      }
    },
  );
}
