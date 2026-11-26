import 'dart:async';
import 'package:flutter/services.dart';
import '../model/maps_pin.dart';
import '../model/maps_web_result.dart';
import '../model/place_details.dart';
import 'landmark_coordinates.dart';

abstract final class PlaceCoordinates {
  static const _channel = MethodChannel('dev.mockareel/place-geocoder');

  static Future<List<Map>> _lookup(String query) async {
    try {
      return await _channel
              .invokeListMethod<Map>('findPlace', query)
              .timeout(const Duration(seconds: 8)) ??
          [];
    } on PlatformException {
      return [];
    } on MissingPluginException {
      return [];
    } on TimeoutException {
      return [];
    }
  }

  /// Return candidate pins for explicit selection when Maps has no readable page.
  static Future<List<MapsWebResult>> search(String query) async {
    final results = <MapsWebResult>[];
    for (final row in await _lookup(query)) {
      final pin = _pin(row);
      if (pin == null) continue;
      final address = row['address'] as String? ?? '';
      final name = row['name'] as String? ?? '';
      if (address.isEmpty && name.isEmpty) continue;
      results.add(
        MapsWebResult(
          name: name.isEmpty ? address : name,
          address: address,
          url: MapsWebUrls.search('${pin.$1},${pin.$2}').toString(),
        ),
      );
    }
    return results;
  }

  static (double, double)? _pin(Map row) {
    final lat = row['latitude'], lon = row['longitude'];
    return lat is num && lon is num && lat.abs() <= 90 && lon.abs() <= 180
        ? (lat.toDouble(), lon.toDouble())
        : null;
  }

  static Future<(double, double)?> resolve(PlaceDetails place) async {
    final uri = Uri.tryParse(place.mapsUrl ?? '');
    if (uri != null && MapsWebUrls.allowedNavigation(uri)) {
      final pin = MapsPin.fromListing(uri);
      if (pin != null) return pin;
    }
    if (place.name.trim().isEmpty || place.address.trim().isEmpty) return null;
    final names = {_name(place.name), _name(place.localName)}..remove('');
    final address = _words(place.address);
    final pins = <(double, double)>{};
    for (final row in await _lookup('${place.name}, ${place.address}')) {
      final pin = _pin(row);
      if (pin == null) continue;
      final name = _words(row['name'] as String? ?? '');
      final localities = (row['localities'] as List? ?? [])
          .whereType<String>()
          .map(_words);
      final sameLocality = localities.any(
        (s) => s.isNotEmpty && ' $address '.contains(' $s '),
      );
      // Android often returns the street number as featureName. Require a
      // complete numbered address match before using such a result as a pin.
      final rowAddress = _words(row['address'] as String? ?? '');
      final country = _words(row['country'] as String? ?? '');
      final addressOnly =
          (name.isEmpty ||
              RegExp(r'^\d+[a-z]?(?: \d+[a-z]?)*$').hasMatch(name)) &&
          RegExp(r'\d').hasMatch(address) &&
          (address == rowAddress ||
              (country.isNotEmpty &&
                  (rowAddress == '$country $address' ||
                      rowAddress == '$address $country')));
      if (addressOnly || (sameLocality && names.contains(_name(name)))) {
        pins.add(pin);
      }
    }
    if (pins.length == 1) return pins.single;
    return LandmarkCoordinates.lookup(place);
  }

  static String _name(String value) => _words(value).replaceAll(' ', '');

  static String _words(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
      .trim();
}
