import 'export_images.dart';
import 'package:flutter/services.dart';
import '../model/project.dart';
import '../model/template_layout.dart';
import '../widgets/output_palette.dart';

class NativeRenderer {
  static const channel = MethodChannel('dev.mockareel/render');
  static const events = EventChannel('dev.mockareel/render-progress');
  int _generation = 0;
  Stream<double> get progress =>
      events.receiveBroadcastStream().map((e) => (e as num).toDouble());
  Future<Map<String, dynamic>> inspect(String path) async =>
      Map<String, dynamic>.from(
        await channel.invokeMethod<Map>('inspect', {'path': path}) ?? {},
      );
  Future<String> thumbnail(String path, double seconds) async => (await channel
      .invokeMethod<String>('thumbnail', {'path': path, 'seconds': seconds}))!;
  Future<String> export(
    ReelProject project,
    List<String> overlays, {
    List<String> introFrames = const [],
  }) async {
    final generation = ++_generation;
    final images = ExportImages();
    try {
      final clips = <Map<String, dynamic>>[];
      final starts = <String>[], ends = <String>[];
      for (final clip in project.clips) {
        final source = clip.isVideo
            ? clip.path
            : await images.prepare(clip.path);
        clips.add({...clip.toJson(), 'path': source});
        starts.add(
          clip.isVideo ? await thumbnail(clip.path, clip.trimStart) : source,
        );
        ends.add(
          clip.isVideo
              ? await thumbnail(
                  clip.path,
                  clip.trimStart + clip.duration - .001,
                )
              : source,
        );
        if (generation != _generation) {
          throw PlatformException(
            code: 'CANCELLED',
            message: 'Export cancelled',
          );
        }
      }
      final path = await channel.invokeMethod<String>('export', {
        'clips': clips,
        'overlays': overlays,
        'posters': starts,
        'endPosters': ends,
        'layout': TemplateLayout.native,
        'backgroundColor': OutputPalette(
          dark: project.darkOutput,
        ).surface.toARGB32(),
        'progressColor': OutputPalette(
          dark: project.darkOutput,
        ).progress.toARGB32(),
        'slideSeconds': project.slideSeconds,
        'music': project.music?.toJson(),
        'sheetIntroSeconds': introFrames.isEmpty
            ? 0
            : project.sheetIntroSeconds,
        'introFrames': introFrames,
      });
      if (path == null) {
        throw StateError('The renderer did not return a video.');
      }
      return path;
    } finally {
      await images.dispose();
    }
  }

  Future<String> exportFeed({
    required List<Map<String, dynamic>> clips,
    required List<String> overlays,
    required List<List<String>> frames,
    required List<double> transitions,
    MusicTrack? music,
  }) async {
    final generation = ++_generation;
    final images = ExportImages();
    try {
      final sources = <Map<String, dynamic>>[];
      final posters = <String>[];
      for (final c in clips) {
        final source = c['isVideo'] == true
            ? c['path'] as String
            : await images.prepare(c['path'] as String);
        sources.add({...c, 'path': source});
        posters.add(
          c['isVideo'] == true
              ? await thumbnail(
                  c['path'] as String,
                  (c['trimStart'] as num).toDouble(),
                )
              : source,
        );
        if (generation != _generation) {
          throw PlatformException(
            code: 'CANCELLED',
            message: 'Export cancelled',
          );
        }
      }
      final path = await channel.invokeMethod<String>('export', {
        'template': 'tiktok-feed',
        'clips': sources,
        'overlays': overlays,
        'posters': posters,
        'endPosters': posters,
        'layout': TemplateLayout.native,
        'sceneFrames': frames,
        'transitions': transitions,
        'music': music?.toJson(),
      });
      if (path == null) {
        throw StateError('The renderer did not return a video.');
      }
      return path;
    } finally {
      await images.dispose();
    }
  }

  Future<void> cancel() {
    _generation++;
    return channel.invokeMethod('cancel');
  }

  Future<String> saveToGallery(String path) async =>
      (await channel.invokeMethod<String>('saveToGallery', {'path': path}))!;
}
