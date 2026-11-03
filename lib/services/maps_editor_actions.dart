import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../model/project.dart';
import '../pages/maps_web_search_page.dart';
import '../widgets/place_form_controllers.dart';
import '../widgets/project_name_dialog.dart';
import 'map_header_service.dart';
import 'media_importer.dart';
import 'native_renderer.dart';
import 'project_store.dart';

class MapsEditorActions {
  static String formatError(Object e) => e is PlatformException
      ? e.message ?? e.code
      : e.toString().replaceFirst('Exception: ', '');

  static Future<void> loadMap({
    required ReelProject project,
    required ProjectStore store,
    required bool useApiHeaders,
    required String apiKey,
    required BuildContext context,
    required Future<void> Function(String) precache,
    required void Function(String path, String source) onApplyHeader,
  }) async {
    final path = await MapHeaderService.loadMap(
      project: project,
      store: store,
      useApiHeaders: useApiHeaders,
      apiKey: apiKey,
      context: context,
    );
    if (path == null) return;
    await precache(path);
    onApplyHeader(
      path,
      useApiHeaders && apiKey.isNotEmpty ? 'google' : 'browser',
    );
  }

  static Future<void> uploadMap({
    required ProjectStore store,
    required Future<void> Function(String) precache,
    required void Function(String path, String source) onApplyHeader,
  }) async {
    final path = await MapHeaderService.uploadMap(store: store);
    if (path == null) return;
    await precache(path);
    onApplyHeader(path, 'upload');
  }

  static Future<void> pickMusic({
    required ReelProject project,
    required ProjectStore store,
    required NativeRenderer renderer,
    required VoidCallback onChanged,
  }) async {
    final track = await MediaImporter.pickMusicTrack(
      store: store,
      renderer: renderer,
    );
    if (track != null) {
      project.music = track;
      onChanged();
    }
  }

  static Future<void> pickMedia({
    required ReelProject project,
    required ProjectStore store,
    required NativeRenderer renderer,
    required void Function(int newSelectedIndex) onAdded,
    required void Function(String message) onToast,
  }) async {
    final result = await MediaImporter.pickMultipleClips(
      store: store,
      renderer: renderer,
      defaultDuration: 3.5,
    );
    if (result.clips.isNotEmpty) {
      project.clips.addAll(result.clips);
      onAdded(project.clips.length - 1);
    }
    if (result.failures > 0) {
      onToast(
        '${result.failures} files could not be opened. '
        'Try JPG/PNG/GIF images or MP4 video.',
      );
    }
  }

  static Future<void> findPlace({
    required BuildContext context,
    required ReelProject project,
    required PlaceFormControllers form,
    required String Function() getApiKey,
    required bool Function() getUseApiHeaders,
    required Future<void> Function() onRequestApiKey,
    required Future<void> Function() onLoadMap,
    required VoidCallback onChanged,
  }) async {
    final imported = await MapsWebSearchPage.search(
      context,
      initial: form.name.text,
      requestApiKey: () async {
        if (getApiKey().isEmpty) await onRequestApiKey();
        final key = getApiKey();
        return key.isEmpty ? null : key;
      },
    );
    if (imported == null || !context.mounted) return;
    project.place = imported.place;
    project.review = imported.review ?? FeaturedReview(enabled: false);
    project.mapHeaderPath = null;
    form.populate(imported.place);
    if (project.title == 'Untitled reel') {
      project.title = imported.place.name;
    }
    onChanged();
    if (project.headerMode == 'map' &&
        getApiKey().isNotEmpty &&
        getUseApiHeaders()) {
      await onLoadMap();
    }
  }

  static Future<void> renameProject({
    required BuildContext context,
    required ReelProject project,
    required VoidCallback onChanged,
  }) async {
    final title = await ProjectNameDialog.show(context, project.title);
    if (title != null && title.isNotEmpty) {
      project.title = title;
      onChanged();
    }
  }

  static Future<void> shareBackup({
    required ReelProject project,
    required ProjectStore store,
    required Future<void> Function() onSave,
  }) async {
    await onSave();
    await MediaImporter.shareProjectBackup(project, store);
  }
}
