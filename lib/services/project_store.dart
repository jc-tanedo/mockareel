import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/project.dart';

class ProjectStore {
  Directory? root;
  Future<void> _writes = Future.value();
  ProjectStore({this.root});
  Future<void> initialize() async {
    root ??= Directory(
        '${(await getApplicationDocumentsDirectory()).path}/mockareel');
    for (final name in ['projects', 'media', 'exports']) {
      await Directory('${root!.path}/$name').create(recursive: true);
    }
  }

  Future<String> retainMedia(String source, String name) async {
    final ext = name.contains('.')
        ? name.split('.').last.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '')
        : 'bin';
    final target = '${root!.path}/media/${newId()}.$ext';
    await File(source).copy(target);
    return target;
  }

  Future<void> save(ReelProject project) {
    project.updatedAt = DateTime.now();
    final data = jsonEncode(project.toJson());
    final target = '${root!.path}/projects/${project.id}.json';
    final next = _writes.catchError((_) {}).then((_) async {
      final temp = File('$target.tmp');
      await temp.writeAsString(data, flush: true);
      await temp.rename(target);
      await (await SharedPreferences.getInstance())
          .setString('currentProject', project.id);
    });
    _writes = next;
    return next;
  }

  Future<List<ReelProject>> projects() async {
    await _writes.catchError((_) {});
    final results = <ReelProject>[];
    await for (final entry in Directory('${root!.path}/projects').list()) {
      if (entry is! File || !entry.path.endsWith('.json')) continue;
      try {
        results.add(ReelProject.fromJson(
            jsonDecode(await entry.readAsString()) as Map<String, dynamic>));
      } on FormatException {
        /* Keep other projects accessible if one file is damaged. */
      }
    }
    results.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return results;
  }

  Future<ReelProject> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('currentProject');
    final all = await projects();
    for (final p in all) {
      if (p.id == id) return p;
    }
    final old = prefs.getString('draft');
    if (old != null && all.isEmpty) {
      try {
        final data = jsonDecode(old) as Map<String, dynamic>;
        final p = ReelProject(
            place: PlaceDetails.fromJson(
                Map<String, dynamic>.from(data['place'] as Map? ?? data)));
        final durations =
            (data['clipDurationsSeconds'] ?? data['durations']) as List? ?? [];
        for (final path in data['media'] as List? ?? []) {
          if (path is! String || !await File(path).exists()) continue;
          final name = path.split('/').last;
          p.clips.add(ReelClip(
              id: newId(),
              path: await retainMedia(path, name),
              name: name,
              isVideo:
                  RegExp(r'\.(mp4|mov|m4v|webm|mkv)$', caseSensitive: false)
                      .hasMatch(name),
              duration: durations.isEmpty
                  ? 3.5
                  : (durations[p.clips.length % durations.length] as num)
                      .toDouble()));
        }
        await save(p);
        return p;
      } on FormatException {
        /* Start a new project if the legacy draft is invalid. */
      }
    }
    return all.isNotEmpty ? all.first : ReelProject();
  }

  Future<String> backup(ReelProject project) async {
    final output = '${root!.path}/exports/${newId()}.mockareel';
    final data = project.toJson();
    final clips = data['clips'] as List;
    final encoder = ZipFileEncoder();
    encoder.create(output);
    try {
      for (var i = 0; i < project.clips.length; i++) {
        final c = project.clips[i];
        final relative = 'media/${c.id}.${c.path.split('.').last}';
        clips[i]['path'] = relative;
        await encoder.addFile(File(c.path), relative);
      }
      final bytes = utf8.encode(jsonEncode(data));
      encoder.addArchiveFile(ArchiveFile('project.json', bytes.length, bytes));
    } finally {
      encoder.close();
    }
    return output;
  }

  Future<ReelProject> importBackup(String path) async {
    final stream = InputFileStream(path);
    try {
      final archive = ZipDecoder().decodeStream(stream);
      final manifest = archive.findFile('project.json');
      if (manifest == null || manifest.size > 1024 * 1024) {
        throw const FormatException('This is not a Mockareel project.');
      }
      final json =
          jsonDecode(utf8.decode(manifest.content)) as Map<String, dynamic>;
      if (json['version'] != 2) {
        throw const FormatException('Unsupported project version.');
      }
      json['id'] = newId();
      final clips = json['clips'] as List;
      final written = <File>[];
      try {
        for (final clip in clips) {
          final entry = archive.findFile(clip['path'] as String);
          if (entry == null || !entry.isFile) {
            throw const FormatException(
                'A media file is missing from this backup.');
          }
          // Archive paths never become destination paths, preventing path traversal.
          final ext = (clip['path'] as String)
              .split('.')
              .last
              .replaceAll(RegExp('[^a-zA-Z0-9]'), '');
          final destination = File('${root!.path}/media/${newId()}.$ext');
          written.add(destination);
          final output = OutputFileStream(destination.path);
          try {
            entry.writeContent(output);
          } finally {
            output.close();
          }
          clip['path'] = destination.path;
        }
        final p = ReelProject.fromJson(json);
        await save(p);
        return p;
      } catch (_) {
        for (final file in written) {
          if (await file.exists()) await file.delete();
        }
        rethrow;
      }
    } finally {
      stream.close();
    }
  }
}
