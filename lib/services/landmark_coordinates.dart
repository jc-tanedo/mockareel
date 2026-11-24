import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../model/place_details.dart';

/// Resolve a landmark using its primary geographic coordinate. A title alone
/// cannot identify a branch, station, or nearby attraction.
abstract final class LandmarkCoordinates {
  static Future<(double, double)?> lookup(
    PlaceDetails place, {
    http.Client? client,
  }) async {
    final site = _site(place.website);
    final name = place.name.trim();
    final parts = place.address.split(',');
    if (site == null ||
        name.isEmpty ||
        name.contains('|') ||
        parts.length < 3) {
      return null;
    }
    final localities = parts
        .skip(1)
        .take(parts.length - 2)
        .map(_words)
        .where(
          (part) =>
              part.length >= 3 &&
              RegExp(r'\p{L}', unicode: true).hasMatch(part),
        )
        .toList();
    if (localities.isEmpty) return null;
    final uri = Uri.https('en.wikipedia.org', '/w/api.php', {
      'action': 'query',
      'format': 'json',
      'formatversion': '2',
      'redirects': '1',
      'titles': name,
      'prop': 'coordinates|extlinks|extracts',
      'coprimary': 'primary',
      'coprop': 'globe',
      'ellimit': '50',
      'exintro': '1',
      'explaintext': '1',
      'exchars': '1000',
    });
    final transport = client ?? http.Client();
    try {
      final response = await transport
          .get(
            uri,
            headers: {
              'User-Agent':
                  'Mockareel (https://github.com/jc-tanedo/mockareel)',
            },
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data case {
        'query': {
          'pages': [
            {
              'title': final String title,
              'extract': final String extract,
              'extlinks': final List links,
              'coordinates': [
                {'lat': final num lat, 'lon': final num lon, 'globe': 'earth'},
              ],
            },
          ],
        },
      }) {
        final intro = ' ${_words(extract)} ';
        if (_words(title).replaceAll(' ', '') ==
                _words(name).replaceAll(' ', '') &&
            localities.any((part) => intro.contains(' $part ')) &&
            links.whereType<Map>().any(
              (link) => link['url'] is String && _site(link['url']) == site,
            ) &&
            lat.abs() <= 90 &&
            lon.abs() <= 180) {
          return (lat.toDouble(), lon.toDouble());
        }
      }
    } on Exception {
      // A missing article, an offline device, or a provider outage leaves the pin editable.
      return null;
    } finally {
      if (client == null) transport.close();
    }
    return null;
  }

  static String _words(String text) => text
      .toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
      .trim();

  static String? _site(String value) {
    final u = Uri.tryParse(value);
    if (u == null ||
        !{'http', 'https'}.contains(u.scheme) ||
        u.host.isEmpty ||
        u.userInfo.isNotEmpty) {
      return null;
    }
    final path = u.path.replaceFirst(RegExp(r'/+$'), '');
    final root = RegExp(
      r'^/en(?:-[a-z]{2})?$',
      caseSensitive: false,
    ).hasMatch(path);
    return u.host.replaceFirst(RegExp(r'^www\.'), '') + (root ? '' : path);
  }
}
