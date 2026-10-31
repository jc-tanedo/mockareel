import 'dart:io';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../model/project.dart';
import 'gif_media.dart';
import 'native_renderer.dart';
import 'project_store.dart';

class MediaImporter {
  static const videoExtensions = {
    'mp4',
    'mov',
    'm4v',
    'webm',
    'mkv',
    '3gp',
  };

  static bool isVideo(XFile file) {
    if (file.mimeType?.startsWith('video/') == true) return true;
    final dot = file.name.lastIndexOf('.');
    if (dot == -1) return false;
    final ext = file.name.substring(dot + 1).toLowerCase();
    return videoExtensions.contains(ext);
  }

  static Future<ReelClip> retainClip(
    XFile file, {
    required ProjectStore store,
    required NativeRenderer renderer,
    double defaultDuration = 3.5,
    double? cardWidth,
  }) async {
    final video = isVideo(file);
    final info =
        video ? await renderer.inspect(file.path) : <String, dynamic>{};
    final length = (info['duration'] as num?)?.toDouble() ?? 0;
    if (video && length <= 0) {
      throw const FormatException('Video duration is unavailable');
    }
    final retained = await store.retainMedia(file.path, file.name);
    final clip = ReelClip(
      id: newId(),
      path: retained,
      name: file.name,
      isVideo: video,
      sourceDuration: length,
      duration: video ? min(defaultDuration, length) : defaultDuration,
      cardWidth: cardWidth ?? (defaultDuration > 4 ? 1 : 1.25),
    );
    await GifMedia.hydrate(clip);
    return clip;
  }

  static Future<MusicTrack?> pickMusicTrack({
    required ProjectStore store,
    required NativeRenderer renderer,
  }) async {
    final file = await FilePicker.pickFile(type: FileType.audio);
    if (file?.path == null) return null;
    final info = await renderer.inspect(file!.path!);
    final duration = (info['duration'] as num?)?.toDouble() ?? 0;
    if (info['hasAudio'] != true || duration <= 0) {
      throw const FormatException('Choose an audio file your device can play.');
    }
    final path = await store.retainMedia(file.path!, file.name);
    return MusicTrack(
      path: path,
      name: file.name,
      sourceDuration: duration,
    );
  }

  static Future<void> shareProjectBackup(
    ReelProject project,
    ProjectStore store,
  ) async {
    final path = await store.backup(project);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(path)],
        subject: '${project.title} — Mockareel project',
      ),
    );
  }

  static Future<void> precacheMediaImage(
    String path,
    BuildContext context,
  ) async {
    Object? failure;
    await precacheImage(
      FileImage(File(path)),
      context,
      onError: (error, stack) {
        failure = error;
      },
    );
    if (failure != null) {
      throw const FormatException(
        'An image could not be decoded. Replace missing media.',
      );
    }
  }
}
