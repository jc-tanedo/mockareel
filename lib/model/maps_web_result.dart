import 'dart:convert';
import 'project.dart';

class MapsWebResult {
  final String name, url, category, address, rating, reviewCount, summary;
  const MapsWebResult({
    required this.name,
    required this.url,
    this.category = '',
    this.address = '',
    this.rating = '',
    this.reviewCount = '',
    this.summary = '',
  });
  factory MapsWebResult.fromJson(Map<String, dynamic> j) => MapsWebResult(
    name: _string(j, 'name', 180),
    url: _string(j, 'url', 6000),
    category: _string(j, 'category', 100),
    address: _string(j, 'address', 500),
    rating: _string(j, 'rating', 8),
    reviewCount: _string(j, 'reviewCount', 20),
    summary: _string(j, 'summary', 400),
  );
  static String _string(Map<String, dynamic> j, String key, int max) {
    final s = j[key] is String ? (j[key] as String).trim() : '';
    return s.length > max ? s.substring(0, max) : s;
  }

  PlaceDetails toPlace({
    String phone = '',
    String website = '',
    String hours = '',
  }) {
    final uri = Uri.tryParse(url);
    String decoded;
    try {
      decoded = Uri.decodeFull(url);
    } on FormatException {
      decoded = url;
    }
    final coordinates = RegExp(
      r'!3d(-?\d+(?:\.\d+)?)!4d(-?\d+(?:\.\d+)?)',
    ).firstMatch(decoded);
    final lat = coordinates == null ? null : double.tryParse(coordinates[1]!);
    final lng = coordinates == null ? null : double.tryParse(coordinates[2]!);
    final id =
        RegExp(r'!(?:19|1)s(ChIJ[^!/?]+)').firstMatch(decoded)?[1] ??
        uri?.queryParameters['query_place_id'];
    final type = category.toLowerCase();
    return PlaceDetails(
      name: name,
      category: category,
      address: address,
      rating: rating,
      reviewCount: reviewCount,
      placeId: id,
      mapsUrl:
          uri != null &&
              MapsWebUrls.allowedNavigation(uri) &&
              uri.scheme == 'https'
          ? url
          : null,
      latitude: lat != null && lat.abs() <= 90 ? lat : null,
      longitude: lng != null && lng.abs() <= 180 ? lng : null,
      phone: phone,
      website: website,
      hours: hours,
      types: [
        if (RegExp(r'\b(restaurant|deli|diner|pizzeria)\b').hasMatch(type))
          'restaurant'
        else if (RegExp(r'\b(cafe|café|coffee shop)\b').hasMatch(type))
          'cafe'
        else if (type.contains('bakery'))
          'bakery'
        else if (RegExp(r'\bbar\b').hasMatch(type))
          'bar',
      ],
    );
  }
}

class MapsWebSnapshot {
  final String state, href, query;
  final List<MapsWebResult> results;
  final PlaceDetails? place;
  final List<FeaturedReview> reviews;
  const MapsWebSnapshot({
    required this.state,
    this.href = '',
    this.query = '',
    this.results = const [],
    this.place,
    this.reviews = const [],
  });
  factory MapsWebSnapshot.decode(Object raw) {
    var data = raw;
    for (var i = 0; i < 2 && data is String; i++) {
      data = jsonDecode(data);
    }
    if (data is! Map) {
      throw const FormatException(
        'Google Maps has not returned readable results yet.',
      );
    }
    final j = Map<String, dynamic>.from(data);
    final details = j['place'] is Map
        ? Map<String, dynamic>.from(j['place'] as Map)
        : null;
    return MapsWebSnapshot(
      state: j['state'] as String? ?? 'loading',
      href: j['href'] as String? ?? '',
      query: j['query'] as String? ?? '',
      results: [
        for (final item in (j['results'] as List? ?? []).take(15))
          if (item is Map)
            MapsWebResult.fromJson(Map<String, dynamic>.from(item)),
      ],
      place: details == null
          ? null
          : MapsWebResult.fromJson(details).toPlace(
              phone: MapsWebResult._string(details, 'phone', 100),
              website: MapsWebResult._string(details, 'website', 500),
              hours: MapsWebResult._string(details, 'hours', 300),
            ),
      reviews: [
        for (final raw in (details?['reviews'] as List? ?? []).take(3))
          if (raw is Map &&
              (raw['text'] as String? ?? '').trim().isNotEmpty &&
              raw['rating'] is num &&
              (raw['rating'] as num) >= 1 &&
              (raw['rating'] as num) <= 5)
            FeaturedReview(
              author: (raw['author'] as String? ?? '').trim(),
              text: (raw['text'] as String).trim(),
              rating: (raw['rating'] as num).round(),
            ),
      ],
    );
  }
}

class MapsWebImport {
  final PlaceDetails place;
  final FeaturedReview? review;
  const MapsWebImport(this.place, {this.review});
}

abstract final class MapsWebUrls {
  static Uri header(PlaceDetails place) {
    final saved = place.mapsUrl;
    if (saved != null && Uri.tryParse(saved)?.scheme == 'https') {
      try {
        return browserUri(search(saved));
      } on FormatException {
        /* Imported backups may contain an invalid URL. */
      }
    }
    final query = [
      place.name,
      place.address,
    ].where((s) => s.trim().isNotEmpty).join(', ');
    if (place.placeId != null &&
        place.placeId!.startsWith('ChIJ') &&
        query.isNotEmpty) {
      return Uri.https('www.google.com', '/maps/search/', {
        'api': '1',
        'query': query,
        'query_place_id': place.placeId!,
        'hl': 'en',
      });
    }
    if (query.isNotEmpty) return search(query);
    final lat = place.latitude, lng = place.longitude;
    if (lat != null &&
        lng != null &&
        lat.isFinite &&
        lng.isFinite &&
        lat.abs() <= 90 &&
        lng.abs() <= 180) {
      return search('$lat,$lng');
    }
    throw const FormatException(
      'Find a place or enter a name and address first.',
    );
  }

  static Uri browserUri(Uri uri) =>
      const {'www.google.com', 'maps.google.com'}.contains(uri.host) &&
          uri.path.startsWith('/maps')
      ? uri.replace(
          queryParameters: {
            ...uri.queryParametersAll,
            'hl': ['en'],
          },
        )
      : uri;

  static bool allowedNavigation(Uri uri) =>
      uri.toString() == 'about:blank' ||
      (uri.scheme == 'https' &&
          uri.userInfo.isEmpty &&
          uri.port == 443 &&
          (const {
            'www.google.com',
            'maps.google.com',
            'maps.app.goo.gl',
            'goo.gl',
            'consent.google.com',
          }.contains(uri.host)) &&
          (uri.host != 'www.google.com' ||
              uri.path.startsWith('/maps') ||
              uri.path.startsWith('/sorry')) &&
          (uri.host != 'maps.google.com' ||
              uri.path == '/' ||
              uri.path.startsWith('/maps')));
  static Uri search(String input) {
    final value = input.trim();
    if (value.length > 6000) {
      throw const FormatException(
        'That link is too long. Try a Google Maps share link or a place name and city.',
      );
    }
    final parsed = Uri.tryParse(value);
    if (value.contains('://')) {
      if (parsed == null ||
          !allowedNavigation(parsed) ||
          parsed.scheme != 'https' ||
          parsed.host == 'consent.google.com' ||
          (parsed.host == 'www.google.com' &&
              !parsed.path.startsWith('/maps'))) {
        throw const FormatException(
          'Paste a Google Maps HTTPS link, or enter a place name and city.',
        );
      }
      return parsed;
    }
    if (value.isEmpty) {
      throw const FormatException('Enter a place name and city.');
    }
    return Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': value,
      'hl': 'en',
    });
  }
}
