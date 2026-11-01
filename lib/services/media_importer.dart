import 'dart:io';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import '../model/project.dart';
import 'gif_media.dart';
import 'native_renderer.dart';
import 'project_store.dart';

class MediaImporter {
  static const videoExtensions = {'mp4', 'mov', 'm4v', 'webm', 'mkv', '3gp'};

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
    final info = video
        ? await renderer.inspect(file.path)
        : <String, dynamic>{};
    var length = (info['duration'] as num?)?.toDouble() ?? 0;
    if (video && length <= 0) {
      try {
        final player = VideoPlayerController.file(File(file.path));
        await player.initialize();
        if (player.value.duration > Duration.zero) {
          length = player.value.duration.inMicroseconds / 1000000.0;
        }
        await player.dispose();
      } catch (_) {}
    }
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

  static Future<({List<ReelClip> clips, int failures})> pickMultipleClips({
    required ProjectStore store,
    required NativeRenderer renderer,
    double defaultDuration = 3.5,
    double? cardWidth,
  }) async {
    final files = await ImagePicker().pickMultipleMedia();
    final clips = <ReelClip>[];
    var failures = 0;
    for (final file in files) {
      try {
        final clip = await retainClip(
          file,
          store: store,
          renderer: renderer,
          defaultDuration: defaultDuration,
          cardWidth: cardWidth,
        );
        clips.add(clip);
      } catch (_) {
        failures++;
      }
    }
    return (clips: clips, failures: failures);
  }

  static const audioExtensions = [
    'mp3',
    'm4a',
    'aac',
    'wav',
    'ogg',
    'opus',
    'flac',
    'mp4',
    'm4v',
    'mov',
    'wma',
  ];

  static Future<MusicTrack?> pickMusicTrack({
    required ProjectStore store,
    required NativeRenderer renderer,
  }) async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: audioExtensions,
    ).catchError(
      (Object _) => FilePicker.pickFile(
        type: FileType.any,
      ),
    ).catchError(
      (Object _) => FilePicker.pickFile(
        type: FileType.audio,
      ),
    );
    if (file?.path == null) return null;
    final info = await renderer.inspect(file!.path!);
    var duration = (info['duration'] as num?)?.toDouble() ?? 0;
    var hasAudio = info['hasAudio'] == true;
    if (!hasAudio) {
      final ext = file.name.split('.').last.toLowerCase();
      if (audioExtensions.contains(ext)) {
        hasAudio = true;
      }
    }
    if (!hasAudio || duration <= 0) {
      try {
        final player = VideoPlayerController.file(File(file.path!));
        await player.initialize();
        if (player.value.duration > Duration.zero) {
          duration = player.value.duration.inMicroseconds / 1000000.0;
          hasAudio = true;
        }
        await player.dispose();
      } catch (_) {}
    }
    if (!hasAudio || duration <= 0) {
      throw const FormatException('Choose an audio file your device can play.');
    }
    final path = await store.retainMedia(file.path!, file.name);
    return MusicTrack(path: path, name: file.name, sourceDuration: duration);
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
