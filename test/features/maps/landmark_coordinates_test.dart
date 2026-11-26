import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mockareel/model/place_details.dart';
import 'package:mockareel/services/landmark_coordinates.dart';

void main() {
  test(
    'a redirected landmark must match the selected name, locality and website',
    () async {
      final place = PlaceDetails(
        name: 'Yomiuri Land',
        address: '4015-1 Yanokuchi, Inagi, Tokyo 206-8725',
        website: 'https://www.yomiuriland.com/',
      );
      final page = <String, dynamic>{
        'title': 'Yomiuriland',
        'extract': 'An amusement park in Inagi, Tokyo.',
        'extlinks': [
          {'url': 'https://www.yomiuriland.com/en/'},
        ],
        'coordinates': [
          {'globe': 'earth', 'lat': 35.62583333, 'lon': 139.51861111},
        ],
      };
      final client = MockClient((request) async {
        expect(request.url.host, 'en.wikipedia.org');
        expect(request.url.queryParameters['titles'], 'Yomiuri Land');
        return http.Response(
          jsonEncode({
            'query': {
              'pages': [page],
            },
          }),
          200,
        );
      });
      Future<(double, double)?> lookup() =>
          LandmarkCoordinates.lookup(place, client: client);
      expect(await lookup(), (35.62583333, 139.51861111));
      page['title'] = 'Yomiuriland-mae Station';
      expect(await lookup(), isNull);
      page['title'] = 'Yomiuriland';
      page['extract'] = 'An amusement park in Osaka.';
      expect(await lookup(), isNull);
      page['extract'] = 'An amusement park in Inagi.';
      page['extlinks'] = [
        {'url': 'https://www.yomiuriland.com.example.net/'},
      ];
      expect(await lookup(), isNull);
      page['extlinks'] = [
        {'url': place.website},
      ];
      page['coordinates'] = [];
      expect(await lookup(), isNull);
    },
  );
}
