import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockareel/model/maps_web_result.dart';
import 'package:mockareel/model/place_details.dart';
import 'package:mockareel/services/place_coordinates.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const park = 'https://www.google.com/maps/place/Yomiuriland/';
  test(
    'listing Plus Codes resolve to the park, independently of the viewport center',
    () {
      for (final (url, code) in [
        (park, '8Q7XJGG9+4J'),
        ('$park@35.61,139.51,15z', 'JGG9+4J Inagi'),
        ('$park@35.61,139.51,15z', '7XJGG9+4J'),
        ('$park@35.625,139.52,800m', 'G9+4J'),
      ]) {
        final place = MapsWebResult(
          name: 'Yomiuriland',
          url: url,
          plusCode: code,
        ).toPlace();
        expect(place.latitude, closeTo(35.6253, .0001));
        expect(place.longitude, closeTo(139.51907, .0001));
      }
      for (final url in [park, '$park@35.61,139.51,5z']) {
        expect(
          MapsWebResult(
            name: 'Park',
            url: url,
            plusCode: 'JGG9+4J',
          ).toPlace().latitude,
          isNull,
        );
      }
      final explicit = const MapsWebResult(
        name: 'Park',
        url:
            'https://www.google.com/maps/search/?api=1&query=35.6253%2C139.51907',
      ).toPlace();
      expect((explicit.latitude, explicit.longitude), (35.6253, 139.51907));
    },
  );

  test(
    'Android fallback accepts a unique named park in the selected locality',
    () async {
      const channel = MethodChannel('dev.mockareel/place-geocoder');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final place = PlaceDetails(
        name: 'Yomiuri Land',
        address: '4015-1 Yanokuchi, Inagi, Tokyo 206-8725',
      );
      final candidate = {
        'name': 'Yomiuriland',
        'latitude': 35.6253,
        'longitude': 139.51907,
        'localities': ['Inagi'],
      };
      final candidates = [
        {...candidate, 'name': 'Yomiuriland-mae Station'},
        {
          ...candidate,
          'localities': ['Osaka'],
        },
      ];
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.arguments, '${place.name}, ${place.address}');
        return candidates;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      expect(await PlaceCoordinates.resolve(place), isNull);
      candidates.add({
        ...candidate,
        'name': '4015-1',
        'address': 'Japan, ${place.address}',
        'country': 'Japan',
      });
      expect(await PlaceCoordinates.resolve(place), (35.6253, 139.51907));
      candidates.last['address'] = '4016-1 Yanokuchi, Inagi, Tokyo, Japan';
      expect(await PlaceCoordinates.resolve(place), isNull);
      candidates.add(candidate);
      expect(await PlaceCoordinates.resolve(place), (35.6253, 139.51907));
      candidates.add({...candidate, 'latitude': 35.6});
      expect(await PlaceCoordinates.resolve(place), isNull);
    },
  );
}
