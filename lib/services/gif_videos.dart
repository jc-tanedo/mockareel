import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import '../model/project.dart';
import 'gif_media.dart';

/// A cached MP4 of just the selected GIF segment, shared by preview and export.
/// Frame extraction is serial, honors disposal, and retains only sampled frames.
class GifVideos {
  static final instance = GifVideos();
  static const channel = MethodChannel('dev.mockareel/gif');
  final Directory? root;
  final _pending = <String, Future<String>>{};
  Future<void> _queue = Future.value();
  int _generation = 0;
  GifVideos({this.root});
  Future<String> video(ReelClip clip) async {
    await GifMedia.hydrate(clip);
    if (!clip.isGif) throw const FormatException('This media is not a GIF.');
    final stat = await File(clip.path).stat();
    final key = sha256
        .convert(
          utf8.encode(
            'gif-v1:${clip.path}:${stat.size}:${stat.modified.microsecondsSinceEpoch}:${clip.trimStart}:${clip.duration}:${clip.loopGif}',
          ),
        )
        .toString();
    final directory =
        root ?? Directory('${Directory.systemTemp.path}/mockareel-gif-v1');
    await directory.create(recursive: true);
    final target = File('${directory.path}/$key.mp4');
    if (await target.exists() && await target.length() > 0) {
      await target.setLastModified(DateTime.now());
      return target.path;
    }
    final existing = _pending[key];
    if (existing != null) return existing;
    final request = ReelClip.fromJson(clip.toJson());
    final token = _generation;
    final task = _queue.catchError((Object _) {}).then((_) async {
      if (token != _generation) {
        throw const FormatException('GIF preparation cancelled.');
      }
      // Cache maintenance is confined to this directory; scratch frames never
      // become project assets. Recently used clips remain available to players.
      await _prune(directory, target.path);
      return _encode(request, target, token);
    });
    _pending[key] = task;
    _queue = task.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    try {
      return await task;
    } finally {
      _pending.remove(key);
    }
  }

  Future<void> _prune(Directory dir, String protected) async {
    final files = <File>[];
    await for (final entry in dir.list()) {
      if (entry is File &&
          entry.path.endsWith('.mp4') &&
          entry.path != protected) {
        files.add(entry);
      }
    }
    files.sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));
    var size = files.fold<int>(0, (n, f) => n + f.lengthSync());
    for (final file in files) {
      if (DateTime.now().difference(await file.lastModified()).inHours > 48 ||
          size > 256 * 1024 * 1024) {
        final bytes = await file.length();
        await file.delete();
        size -= bytes;
      }
    }
  }

  Future<String> _encode(ReelClip clip, File target, int token) async {
    final partial = File('${target.path}.partial.mp4');
    if (await partial.exists()) await partial.delete();
    final info = await GifMedia.inspect(clip.path);
    if (info == null) {
      throw const FormatException(
        'The GIF could not be opened. Replace this media.',
      );
    }
    final samples = info.samples(clip.trimStart, clip.duration, clip.loopGif);
    final needed = samples.toSet();
    final last = needed.reduce(max);
    final scratch = await Directory.systemTemp.createTemp(
      'mockareel-gif-frames-',
    );
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    try {
      buffer = await ui.ImmutableBuffer.fromFilePath(clip.path);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final scale = min(1.0, 1080 / max(info.width, info.height));
      int even(int value) =>
          (max(64, min(1080, (value * scale).round())) / 2).ceil() * 2;
      final width = even(info.width), height = even(info.height);
      codec = await descriptor.instantiateCodec(
        targetWidth: width,
        targetHeight: height,
      );
      final paths = <int, String>{};
      var bytes = 0;
      for (var i = 0; i <= last; i++) {
        if (token != _generation) {
          throw const FormatException('GIF preparation cancelled.');
        }
        final frame = await codec.getNextFrame();
        try {
          if (needed.contains(i)) {
            final png = await frame.image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            if (png == null) {
              throw const FormatException('Could not decode a GIF frame.');
            }
            bytes += png.lengthInBytes;
            if (bytes > 256 * 1024 * 1024) {
              throw const FormatException(
                'This GIF segment needs too much space. Select a shorter duration.',
              );
            }
            final file = File('${scratch.path}/$i.png');
            await file.writeAsBytes(png.buffer.asUint8List());
            paths[i] = file.path;
          }
        } finally {
          frame.image.dispose();
        }
      }
      final recorder = ui.PictureRecorder();
      ui.Canvas(
        recorder,
      ).drawColor(const ui.Color(0xff000000), ui.BlendMode.src);
      final picture = recorder.endRecording();
      final blank = await picture.toImage(width, height);
      picture.dispose();
      try {
        final png = (await blank.toByteData(format: ui.ImageByteFormat.png))!;
        await File(
          '${scratch.path}/base.png',
        ).writeAsBytes(png.buffer.asUint8List());
      } finally {
        blank.dispose();
      }
      final frames = <Map<String, dynamic>>[];
      for (var i = 0; i < samples.length; i++) {
        if (i == 0 || samples[i] != samples[i - 1]) {
          frames.add({
            'timeUs': (i * 1000000 / 30).round(),
            'path': paths[samples[i]]!,
          });
        }
      }
      if (token != _generation) {
        throw const FormatException('GIF preparation cancelled.');
      }
      await channel.invokeMethod<void>('encode', {
        'base': '${scratch.path}/base.png',
        'frames': frames,
        'duration': clip.duration,
        'width': width,
        'height': height,
        'output': partial.path,
      });
      if (token != _generation) {
        throw const FormatException('GIF preparation cancelled.');
      }
      if (!await partial.exists() || await partial.length() == 0) {
        throw const FormatException('GIF video could not be prepared.');
      }
      await partial.rename(target.path);
      return target.path;
    } catch (_) {
      if (await partial.exists()) await partial.delete();
      rethrow;
    } finally {
      codec?.dispose();
      descriptor?.dispose();
      buffer?.dispose();
      if (await scratch.exists()) await scratch.delete(recursive: true);
    }
  }

  Future<void> cancel() async {
    _generation++;
    if (_pending.isNotEmpty) await channel.invokeMethod<void>('cancel');
  }
}
