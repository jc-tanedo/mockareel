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
    final starts = <String>[], ends = <String>[];
    for (final clip in project.clips) {
      starts.add(
        clip.isVideo ? await thumbnail(clip.path, clip.trimStart) : clip.path,
      );
      ends.add(
        clip.isVideo
            ? await thumbnail(clip.path, clip.trimStart + clip.duration - .001)
            : clip.path,
      );
      if (generation != _generation) {
        throw PlatformException(code: 'CANCELLED', message: 'Export cancelled');
      }
    }
    final path = await channel.invokeMethod<String>('export', {
      'clips': project.clips.map((c) => c.toJson()).toList(),
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
      'sheetIntroSeconds': introFrames.isEmpty ? 0 : project.sheetIntroSeconds,
      'introFrames': introFrames,
    });
    if (path == null) throw StateError('The renderer did not return a video.');
    return path;
  }

  Future<void> cancel() {
    _generation++;
    return channel.invokeMethod('cancel');
  }

  Future<String> saveToGallery(String path) async =>
      (await channel.invokeMethod<String>('saveToGallery', {'path': path}))!;
}
