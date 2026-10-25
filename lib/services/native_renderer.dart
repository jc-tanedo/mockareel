import 'gif_media.dart';
import 'gif_videos.dart';
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
  Future<String> poster(ReelClip clip, {double position = 0}) async {
    if (clip.isGif) {
      final video = await GifVideos.instance.video(clip);
      return thumbnail(video, position.clamp(0, clip.duration - .001));
    }
    return clip.isVideo
        ? thumbnail(
            clip.path,
            clip.trimStart + position.clamp(0, clip.duration - .001),
          )
        : clip.path;
  }

  Future<Map<String, dynamic>> _source(ReelClip clip) async {
    await GifMedia.hydrate(clip);
    if (!clip.isGif) return clip.toJson();
    final path = await GifVideos.instance.video(clip);
    return {
      ...clip.toJson(),
      'path': path,
      'isVideo': true,
      'trimStart': 0.0,
      'sourceDuration': clip.duration,
    };
  }

  Future<String> export(
    ReelProject project,
    List<String> overlays, {
    List<String> introFrames = const [],
  }) async {
    final generation = ++_generation;
    final clips = <Map<String, dynamic>>[],
        starts = <String>[],
        ends = <String>[];
    for (final clip in project.clips) {
      clips.add(await _source(clip));
      starts.add(await poster(clip));
      ends.add(await poster(clip, position: clip.duration - .001));
      if (generation != _generation) {
        throw PlatformException(code: 'CANCELLED', message: 'Export cancelled');
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
      'sheetIntroSeconds': introFrames.isEmpty ? 0 : project.sheetIntroSeconds,
      'introFrames': introFrames,
    });
    if (path == null) throw StateError('The renderer did not return a video.');
    return path;
  }

  Future<String> exportFeed({
    required List<Map<String, dynamic>> clips,
    required List<String> overlays,
    required List<List<String>> frames,
    required List<double> transitions,
    MusicTrack? music,
  }) async {
    final generation = ++_generation;
    final sources = <Map<String, dynamic>>[], posters = <String>[];
    for (final c in clips) {
      final loop = c['loopSource'] == true;
      final clip = ReelClip.fromJson({
        ...c,
        if (loop) 'duration': c['loopDuration'],
      });
      final source = await _source(clip);
      sources.add({...c, ...source, 'duration': c['duration']});
      posters.add(await poster(clip));
      if (generation != _generation) {
        throw PlatformException(code: 'CANCELLED', message: 'Export cancelled');
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
    if (path == null) throw StateError('The renderer did not return a video.');
    return path;
  }

  Future<void> cancel() {
    _generation++;
    return Future.wait<void>([
      channel.invokeMethod<void>('cancel'),
      GifVideos.instance.cancel(),
    ]).then((_) {});
  }

  Future<String> saveToGallery(String path) async =>
      (await channel.invokeMethod<String>('saveToGallery', {'path': path}))!;
}
