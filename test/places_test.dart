import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mockareel/services/places.dart';

void main() {
  test(
    'Places New lookup authenticates and populates editable fields',
    () async {
      final service = PlacesService(
        'test-key',
        client: MockClient((request) async {
          expect(request.url.path, '/v1/places:searchText');
          expect(request.headers['X-Goog-Api-Key'], 'test-key');
          expect(jsonDecode(request.body)['textQuery'], 'Cafe Makati');
          expect(
            request.headers['X-Goog-FieldMask'],
            contains('places.formattedAddress'),
          );
          return http.Response(
            jsonEncode({
              'places': [
                {
                  'id': 'place-id',
                  'types': ['cafe', 'food'],
                  'nationalPhoneNumber': '12345',
                  'websiteUri': 'https://cafe.example',
                  'displayName': {'text': 'Cafe Test'},
                  'primaryTypeDisplayName': {'text': 'Coffee shop'},
                  'formattedAddress': 'Makati, Philippines',
                  'rating': 4.7,
                  'userRatingCount': 123,
                  'priceLevel': 'PRICE_LEVEL_MODERATE',
                  'currentOpeningHours': {'openNow': true},
                },
              ],
            }),
            200,
          );
        }),
      );
      final p = (await service.search(' Cafe Makati ')).single;
      expect(p.name, 'Cafe Test');
      expect(p.rating, '4.7');
      expect(p.category, 'Coffee shop');
      expect(p.address, 'Makati, Philippines');
      expect(p.placeId, 'place-id');
      expect(p.reviewCount, '123');
      expect(p.price, 'Moderate');
      expect(p.hours, 'Open now');
      expect(p.hasMenu, true);
      expect(p.actions.map((a) => a.kind), [
        'directions',
        'menu',
        'call',
        'website',
      ]);
      service.dispose();
    },
  );
  test(
    'Google authorization errors are actionable and never expose the key',
    () async {
      final service = PlacesService(
        'secret-key',
        client: MockClient(
          (_) async => http.Response(
            '{"error":{"status":"PERMISSION_DENIED","message":"secret-key"}}',
            403,
          ),
        ),
      );
      await expectLater(
        service.search('Cafe'),
        throwsA(
          predicate(
            (e) =>
                e.toString().contains('Places API (New)') &&
                !e.toString().contains('secret-key'),
          ),
        ),
      );
      service.dispose();
    },
  );
}
