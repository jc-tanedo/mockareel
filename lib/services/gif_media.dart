import 'dart:io';
import '../model/gif_info.dart';
import '../model/project.dart';

abstract final class GifMedia {
  static Future<GifInfo?> inspect(String path) async {
    final file = File(path);
    if (!file.existsSync()) return null;
    final reader = file.openSync();
    late final List<int> head;
    try {
      head = reader.readSync(6);
    } finally {
      reader.closeSync();
    }
    if (!GifInfo.signature(head)) return null;
    if (await file.length() > 64 * 1024 * 1024) {
      throw const FormatException(
        'This GIF is too large. Use a video instead.',
      );
    }
    return GifInfo.parse(await file.readAsBytes());
  }

  static Future<void> hydrate(ReelClip clip) async {
    if (clip.isVideo || (clip.isGif && clip.sourceDuration > 0)) return;
    final info = await inspect(clip.path);
    if (info == null) return;
    clip.isGif = true;
    clip.sourceDuration = info.duration;
    clip.normalize();
  }

  static Future<void> hydrateProject(ReelProject project) async {
    for (final clip in [
      ...project.clips,
      if (project.feed.homeMedia != null) project.feed.homeMedia!,
    ]) {
      try {
        await hydrate(clip);
      } on FileSystemException {
        /* Keep missing media editable. */
      } on FormatException {
        /* A damaged clip must not hide the whole project. */
      }
    }
  }
}
