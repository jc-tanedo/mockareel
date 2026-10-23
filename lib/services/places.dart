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
                'places.id,places.displayName,places.formattedAddress,places.rating,places.primaryTypeDisplayName',
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
      );
    }).toList();
  }

  void dispose() => client.close();
}
