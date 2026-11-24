import 'dart:async';
import 'package:flutter/services.dart';
import '../model/maps_pin.dart';
import '../model/maps_web_result.dart';
import '../model/place_details.dart';

abstract final class PlaceCoordinates {
  static const _channel = MethodChannel('dev.mockareel/place-geocoder');

  static Future<(double, double)?> resolve(PlaceDetails place) async {
    final uri = Uri.tryParse(place.mapsUrl ?? '');
    if (uri != null && MapsWebUrls.allowedNavigation(uri)) {
      final pin = MapsPin.fromListing(uri);
      if (pin != null) return pin;
    }
    if (place.name.trim().isEmpty || place.address.trim().isEmpty) return null;
    final names = {_words(place.name), _words(place.localName)}..remove('');
    final address = ' ${_words(place.address)} ';
    try {
      final candidates = await _channel
          .invokeListMethod<Map>('findPlace', '${place.name}, ${place.address}')
          .timeout(const Duration(seconds: 6));
      final pins = <(double, double)>{};
      for (final candidate in candidates ?? const <Map>[]) {
        if (!names.contains(_words(candidate['name'] as String? ?? ''))) {
          continue;
        }
        final localities = (candidate['localities'] as List)
            .whereType<String>()
            .map(_words);
        if (!localities.any((s) => s.isNotEmpty && address.contains(' $s '))) {
          continue;
        }
        final lat = candidate['latitude'], lon = candidate['longitude'];
        if (lat is num && lon is num && lat.abs() <= 90 && lon.abs() <= 180) {
          pins.add((lat.toDouble(), lon.toDouble()));
        }
      }
      return pins.length == 1 ? pins.single : null;
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    } on TimeoutException {
      return null;
    }
  }

  static String _words(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
      .trim();
}
