import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import '../model/project.dart';
import 'project_store.dart';
import 'static_map.dart';

class MapHeaderService {
  static Future<String?> loadMap({
    required ReelProject project,
    required ProjectStore store,
    required bool useApiHeaders,
    required String apiKey,
    required Future<Uint8List?> Function(PlaceDetails) capture,
  }) async {
    final place = project.place;
    final service = StaticMapService();
    try {
      final bytes = useApiHeaders && apiKey.isNotEmpty
          ? await service.load(place, apiKey, zoom: project.mapZoom)
          : await capture(place);
      if (bytes == null) return null;
      return (await store.writeMapAsset('map_${newId()}.png', bytes)).path;
    } finally {
      service.dispose();
    }
  }

  static Future<String?> uploadMap({required ProjectStore store}) async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null) return null;
    return await store.retainMedia(file.path, file.name);
  }
}
