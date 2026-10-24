import 'dart:convert';
import 'package:http/http.dart' as http;
import '../model/project.dart';

class PlacesService {
  final String key;
  final http.Client client;
  PlacesService(this.key, {http.Client? client})
    : client = client ?? http.Client();
  Future<List<PlaceDetails>> search(String query) async {
    final response = await client
        .post(
          Uri.https('places.googleapis.com', '/v1/places:searchText'),
          headers: {
            'Content-Type': 'application/json',
            'X-Goog-Api-Key': key,
            'X-Goog-FieldMask':
                'places.id,places.displayName,places.formattedAddress,places.rating,places.primaryTypeDisplayName,places.userRatingCount,places.priceLevel,places.currentOpeningHours,places.types,places.nationalPhoneNumber,places.websiteUri,places.location',
          },
          body: jsonEncode({
            'textQuery': query.trim(),
            'languageCode': 'en',
            'pageSize': 8,
          }),
        )
        .timeout(const Duration(seconds: 20));
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      final status = (body['error'] as Map?)?['status'] ?? response.statusCode;
      throw Exception(
        'Places lookup failed ($status). Enable Places API (New), billing, and check the key restrictions.',
      );
    }
    return (body['places'] as List? ?? []).map((raw) {
      final p = raw as Map<String, dynamic>;
      return PlaceDetails(
        name: (p['displayName'] as Map?)?['text'] as String? ?? '',
        category:
            (p['primaryTypeDisplayName'] as Map?)?['text'] as String? ?? '',
        address: p['formattedAddress'] as String? ?? '',
        rating: (p['rating'] as num?)?.toStringAsFixed(1) ?? '',
        placeId: p['id'] as String?,
        latitude: ((p['location'] as Map?)?['latitude'] as num?)?.toDouble(),
        longitude: ((p['location'] as Map?)?['longitude'] as num?)?.toDouble(),
        types: (p['types'] as List? ?? []).cast<String>(),
        phone: p['nationalPhoneNumber'] as String? ?? '',
        website: p['websiteUri'] as String? ?? '',
        reviewCount: p['userRatingCount']?.toString() ?? '',
        price:
            const {
              'PRICE_LEVEL_FREE': 'Free',
              'PRICE_LEVEL_INEXPENSIVE': 'Inexpensive',
              'PRICE_LEVEL_MODERATE': 'Moderate',
              'PRICE_LEVEL_EXPENSIVE': 'Expensive',
              'PRICE_LEVEL_VERY_EXPENSIVE': 'Very expensive',
            }[p['priceLevel']] ??
            '',
        hours: (p['currentOpeningHours'] as Map?)?['openNow'] == null
            ? ''
            : (p['currentOpeningHours'] as Map)['openNow'] == true
            ? 'Open now'
            : 'Closed now',
      );
    }).toList();
  }

  void dispose() => client.close();
}
