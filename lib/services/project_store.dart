import 'gif_media.dart';
import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/project.dart';
import 'project_archive.dart';
export 'project_archive.dart' show BackupLimits;

class ProjectStore {
  Directory? root;
  Future<void> _writes = Future.value();
  final BackupLimits backupLimits;
  ProjectStore({this.root, this.backupLimits = const BackupLimits()});
  Future<void> initialize() async {
    root ??= Directory(
      '${(await getApplicationDocumentsDirectory()).path}/mockareel',
    );
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
      await (await SharedPreferences.getInstance()).setString(
        'currentProject',
        project.id,
      );
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
        final project = ReelProject.fromJson(
          jsonDecode(await entry.readAsString()) as Map<String, dynamic>,
        );
        await GifMedia.hydrateProject(project);
        results.add(project);
      } on FormatException {
        /* Keep other projects accessible if one file is damaged. */
      } on TypeError {
        /* A valid JSON document may still contain an invalid project schema. */
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
            Map<String, dynamic>.from(data['place'] as Map? ?? data),
          ),
        );
        final durations =
            (data['clipDurationsSeconds'] ?? data['durations']) as List? ?? [];
        for (final path in data['media'] as List? ?? []) {
          if (path is! String || !await File(path).exists()) continue;
          final name = path.split('/').last;
          p.clips.add(
            ReelClip(
              id: newId(),
              path: await retainMedia(path, name),
              name: name,
              isVideo: RegExp(
                r'\.(mp4|mov|m4v|webm|mkv)$',
                caseSensitive: false,
              ).hasMatch(name),
              duration: durations.isEmpty
                  ? 3.5
                  : (durations[p.clips.length % durations.length] as num)
                        .toDouble(),
            ),
          );
        }
        await GifMedia.hydrateProject(p);
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
      if (project.music != null) {
        final music = project.music!;
        final relative = 'media/music.${music.path.split('.').last}';
        (data['music'] as Map)['path'] = relative;
        await encoder.addFile(File(music.path), relative);
      }
      if (project.mapHeaderPath != null) {
        final relative =
            'media/map-header.${project.mapHeaderPath!.split('.').last}';
        data['mapHeaderPath'] = relative;
        await encoder.addFile(File(project.mapHeaderPath!), relative);
      }
      for (var i = 0; i < project.clips.length; i++) {
        final avatar = project.clips[i].post.avatarPath;
        if (avatar == null) continue;
        final relative = 'media/avatar-$i.${avatar.split('.').last}';
        (clips[i]['post'] as Map)['avatarPath'] = relative;
        await encoder.addFile(File(avatar), relative);
      }
      final maps = <String, String>{};
      for (var i = 0; i < project.clips.length; i++) {
        final path = project.clips[i].streetview.mapPath;
        if (path == null) continue;
        var relative = maps[path];
        if (relative == null) {
          relative =
              'media/streetview-map-${maps.length}.${path.split('.').last}';
          maps[path] = relative;
          await encoder.addFile(File(path), relative);
        }
        (clips[i]['streetview'] as Map)['mapPath'] = relative;
      }
      if (project.feed.homeMedia != null) {
        final home = project.feed.homeMedia!;
        final relative = 'media/home.${home.path.split('.').last}';
        ((data['feed'] as Map)['homeMedia'] as Map)['path'] = relative;
        await encoder.addFile(File(home.path), relative);
      }
      final bytes = utf8.encode(jsonEncode(data));
      encoder.addArchiveFile(ArchiveFile('project.json', bytes.length, bytes));
    } finally {
      encoder.close();
    }
    return output;
  }

  Future<ReelProject> importBackup(String path) async {
    final archive = await ProjectArchive.open(path, backupLimits);
    try {
      final json = archive.manifest();
      if (json['version'] != 2) {
        throw const FormatException('Unsupported project version.');
      }
      json['id'] = newId();
      final clips = json['clips'] as List;
      if (clips.length > backupLimits.clips) {
        throw const FormatException('This project contains too many clips.');
      }
      final written = <File>[];
      try {
        for (final clip in [
          ...clips,
          if (json['music'] != null) json['music'],
          if (json['mapHeaderPath'] != null)
            {'path': json['mapHeaderPath'], 'isMapHeader': true},
        ]) {
          if (clip.containsKey('id')) {
            final replacementId = newId();
            if (json['heroClipId'] == clip['id']) {
              json['heroClipId'] = replacementId;
            }
            clip['id'] = replacementId;
          }
          // Archive paths never become destination paths, preventing path traversal.
          final ext = (clip['path'] as String)
              .split('.')
              .last
              .replaceAll(RegExp('[^a-zA-Z0-9]'), '');
          final destination = File('${root!.path}/media/${newId()}.$ext');
          written.add(destination);
          archive.extract(clip['path'] as String, destination.path);
          clip['path'] = destination.path;
          if (clip['isMapHeader'] == true) {
            json['mapHeaderPath'] = destination.path;
          }
        }
        Future<String> restoreExtra(String source) async {
          final ext = source
              .split('.')
              .last
              .replaceAll(RegExp('[^a-zA-Z0-9]'), '');
          final file = File('${root!.path}/media/${newId()}.$ext');
          written.add(file);
          archive.extract(source, file.path);
          return file.path;
        }

        final restoredMaps = <String, String>{};
        for (final clip in clips) {
          final streetview = clip['streetview'] as Map?;
          final source = streetview?['mapPath'] as String?;
          if (source != null) {
            final restored = restoredMaps[source] ?? await restoreExtra(source);
            restoredMaps[source] = restored;
            streetview!['mapPath'] = restored;
          }
          final post = clip['post'] as Map?;
          if (post?['avatarPath'] != null) {
            post!['avatarPath'] = await restoreExtra(
              post['avatarPath'] as String,
            );
          }
        }
        final home = (json['feed'] as Map?)?['homeMedia'] as Map?;
        if (home != null) {
          home['id'] = newId();
          home['path'] = await restoreExtra(home['path'] as String);
        }
        final p = ReelProject.fromJson(json);
        await GifMedia.hydrateProject(p);
        await save(p);
        return p;
      } catch (_) {
        for (final file in written) {
          if (await file.exists()) await file.delete();
        }
        rethrow;
      }
    } on TypeError {
      throw const FormatException('Invalid project backup fields.');
    } finally {
      archive.close();
    }
  }
}
