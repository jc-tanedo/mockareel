import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../model/project.dart';
import '../pages/maps_web_header_page.dart';
import 'project_store.dart';
import 'static_map.dart';

class MapHeaderService {
  static Future<String?> loadMap({
    required ReelProject project,
    required ProjectStore store,
    required bool useApiHeaders,
    required String apiKey,
    required BuildContext context,
  }) async {
    final place = project.place;
    final service = StaticMapService();
    File? file;
    try {
      final bytes = useApiHeaders && apiKey.isNotEmpty
          ? await service.load(place, apiKey, zoom: project.mapZoom)
          : await Navigator.of(context).push<Uint8List>(
              MaterialPageRoute(
                builder: (_) => MapsWebHeaderPage(place: place),
              ),
            );
      if (bytes == null) return null;
      file = File('${store.root!.path}/media/map_${newId()}.png');
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (_) {
      if (file != null && await file.exists()) await file.delete();
      rethrow;
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
