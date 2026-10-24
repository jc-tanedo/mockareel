import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../model/project.dart';

class StaticMapService {
  final http.Client client;
  StaticMapService({http.Client? client}) : client = client ?? http.Client();
  Future<Uint8List> load(
    PlaceDetails place,
    String key, {
    int zoom = 15,
  }) async {
    if (key.trim().isEmpty) {
      throw const FormatException(
        'Add a Google Maps key in Settings, or upload a map image.',
      );
    }
    final coordinates = place.latitude != null && place.longitude != null
        ? '${place.latitude},${place.longitude}'
        : [
            place.name,
            place.address,
          ].where((s) => s.trim().isNotEmpty).join(', ');
    if (coordinates.isEmpty) {
      throw const FormatException(
        'Find a place or enter a name and address first.',
      );
    }
    try {
      final response = await client
          .get(
            Uri.https('maps.googleapis.com', '/maps/api/staticmap', {
              'center': coordinates,
              'markers': 'color:red|$coordinates',
              'zoom': '${zoom.clamp(1, 20)}',
              'size': '640x400',
              'scale': '2',
              'maptype': 'roadmap',
              'key': key.trim(),
            }),
          )
          .timeout(const Duration(seconds: 25));
      if (response.statusCode != 200 ||
          !(response.headers['content-type'] ?? '').startsWith('image/')) {
        throw const FormatException(
          'Map image unavailable. Enable Maps Static API and billing, check key restrictions, or upload a map image.',
        );
      }
      return response.bodyBytes;
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException(
        'Could not load the map image. Check your connection or upload a map image.',
      );
    }
  }

  void dispose() => client.close();
}
