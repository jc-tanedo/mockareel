import 'media_preparation_queue.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import '../model/project.dart';
import 'gif_videos.dart';

/// Originals and edit recipes are project assets. Derived, UI-free sources are
/// disposable cache entries shared by players, thumbnails and both exporters.
class EditedMedia {
  static final instance = EditedMedia();
  static const channel = MethodChannel('dev.mockareel/render');
  final Directory? root;
  final _pending = <String, Future<String>>{};
  final _latest = <String, String>{};
  final _consumers = <String, Set<String>>{};
  Future<void> _queue = Future.value();
  int _generation = 0;
  EditedMedia({this.root});

  static String stamp(ReelClip c) =>
      '${c.path}:${c.isVideo}:${c.isGif}:${c.trimStart}:${c.duration}:${c.loopGif}:${jsonEncode(c.effectiveEdits.toJson())}';

  Future<ReelClip> prepare(ReelClip clip) async {
    if (!clip.effectiveEdits.active) return clip;
    final request = ReelClip.fromJson(clip.toJson());
    request.edits = request.effectiveEdits;
    final signature = stamp(request), token = _generation;
    _latest[request.id] = signature;
    final stat = await File(request.path).stat();
    if (stat.type != FileSystemEntityType.file) {
      throw const FormatException('Source media is missing.');
    }
    final key = sha256
        .convert(
          utf8.encode(
            'source-edits-v2:$signature:${stat.size}:${stat.modified.microsecondsSinceEpoch}',
          ),
        )
        .toString();
    final dir =
        root ??
        Directory('${Directory.systemTemp.path}/mockareel-source-edits-v2');
    await dir.create(recursive: true);
    final target = File('${dir.path}/$key.${request.isTimed ? 'mp4' : 'png'}');
    if (await target.exists() && await target.length() > 0) {
      await target.setLastModified(DateTime.now());
      return _derived(request, target.path);
    }
    final pendingKey = '$key:$token';
    (_consumers[pendingKey] ??= <String>{}).add(request.id);
    var task = _pending[pendingKey];
    if (task == null) {
      task = _queue.catchError((Object _) {}).then((_) async {
        // Coalesce slider/drag updates without processing every intermediate edit.
        await Future<void>.delayed(const Duration(milliseconds: 350));
        if (token != _generation ||
            !(_consumers[pendingKey] ?? {}).any(
              (id) => _latest[id] == signature,
            )) {
          throw PlatformException(
            code: 'CANCELLED',
            message: 'Media edits changed.',
          );
        }
        await _prune(dir, target.path);
        final source = request.isGif
            ? await GifVideos.instance.video(request)
            : request.path;
        if (token != _generation) {
          throw const FormatException('Media processing cancelled.');
        }
        final partial = File('${target.path}.${newId()}.partial');
        try {
          await MediaPreparationQueue.run(() {
            if (token != _generation) {
              throw const FormatException('Media processing cancelled.');
            }
            return channel.invokeMethod<String>('processMedia', {
              'path': source,
              'isVideo': request.isTimed,
              'trimStart': request.isGif ? 0.0 : request.trimStart,
              'duration': request.duration,
              'edits': request.edits.toJson(),
              'output': partial.path,
            });
          });
          if (token != _generation) {
            throw const FormatException('Media processing cancelled.');
          }
          if (!await partial.exists() || await partial.length() == 0) {
            throw const FormatException('Edited media could not be prepared.');
          }
          await partial.rename(target.path);
          return target.path;
        } finally {
          if (await partial.exists()) await partial.delete();
        }
      });
      _pending[pendingKey] = task;
      _queue = task.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    }
    try {
      return _derived(request, await task);
    } finally {
      if (identical(_pending[pendingKey], task)) {
        _pending.remove(pendingKey);
        _consumers.remove(pendingKey);
      }
    }
  }

  ReelClip _derived(ReelClip c, String path) => ReelClip.fromJson({
    ...c.toJson(),
    'path': path,
    'edits': <String, dynamic>{},
    'isVideo': c.isTimed,
    'isGif': false,
    'trimStart': 0.0,
    'sourceDuration': c.isTimed ? c.duration : 0.0,
  });

  Future<void> _prune(Directory dir, String protected) async {
    final files = <File>[];
    await for (final f in dir.list()) {
      if (f is File &&
          f.path != protected &&
          (f.path.endsWith('.mp4') || f.path.endsWith('.png'))) {
        files.add(f);
      }
    }
    files.sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));
    var bytes = files.fold<int>(0, (n, f) => n + f.lengthSync());
    for (final f in files) {
      if (bytes > 512 * 1024 * 1024 ||
          DateTime.now().difference(await f.lastModified()).inHours > 48) {
        bytes -= await f.length();
        await f.delete();
      }
    }
  }

  Future<void> cancel() async {
    _generation++;
    if (_pending.isNotEmpty) {
      await channel.invokeMethod<void>('cancelMediaEdits');
    }
  }
}
