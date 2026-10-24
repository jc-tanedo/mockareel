import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockareel/model/project.dart';
import 'package:mockareel/services/project_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory dir;
  late ProjectStore store;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    dir = await Directory.systemTemp.createTemp('mockareel-untrusted-');
    store = ProjectStore(root: Directory('${dir.path}/app'));
    await store.initialize();
  });
  tearDown(() => dir.delete(recursive: true));
  Map<String, dynamic> manifest() => ReelProject(
    clips: [
      ReelClip(id: 'a', path: 'media/a.jpg', name: 'Photo', isVideo: false),
    ],
  ).toJson();
  Future<String> backup(
    Map<String, dynamic> data, {
    Map<String, List<int>> files = const {
      'media/a.jpg': [1, 2, 3],
    },
    void Function(Uint8List)? modify,
  }) async {
    final archive = Archive();
    final json = utf8.encode(jsonEncode(data));
    archive.add(ArchiveFile('project.json', json.length, json));
    files.forEach(
      (name, bytes) => archive.add(ArchiveFile(name, bytes.length, bytes)),
    );
    final bytes = Uint8List.fromList(ZipEncoder().encode(archive));
    modify?.call(bytes);
    final file = File('${dir.path}/test.mockareel');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  int header(Uint8List bytes, String name) {
    final data = ByteData.sublistView(bytes);
    for (var i = 0; i < bytes.length - 46; i++) {
      if (data.getUint32(i, Endian.little) == 0x02014b50) {
        final n = data.getUint16(i + 28, Endian.little);
        if (utf8.decode(bytes.sublist(i + 46, i + 46 + n)) == name) return i;
      }
    }
    throw StateError('Fixture entry not found');
  }

  test(
    'traversal paths are rejected without writing outside owned media',
    () async {
      final data = manifest();
      (data['clips'] as List).first['path'] = '../outside.jpg';
      final path = await backup(
        data,
        files: {
          '../outside.jpg': [1, 2, 3],
        },
      );
      await expectLater(store.importBackup(path), throwsFormatException);
      expect(await File('${dir.path}/outside.jpg').exists(), false);
      expect(await Directory('${store.root!.path}/media').list().length, 0);
    },
  );
  test(
    'archive entry and compressed file budgets are enforced before extraction',
    () async {
      final path = await backup(manifest());
      final countLimited = ProjectStore(
        root: store.root,
        backupLimits: const BackupLimits(entries: 1),
      );
      await expectLater(countLimited.importBackup(path), throwsFormatException);
      final fileLimited = ProjectStore(
        root: store.root,
        backupLimits: const BackupLimits(archiveBytes: 10),
      );
      await expectLater(fileLimited.importBackup(path), throwsFormatException);
    },
  );
  test('declared oversized media and symlink entries are rejected', () async {
    var path = await backup(
      manifest(),
      modify: (bytes) {
        ByteData.sublistView(bytes).setUint32(
          header(bytes, 'media/a.jpg') + 24,
          0x7fffffff,
          Endian.little,
        );
      },
    );
    await expectLater(store.importBackup(path), throwsFormatException);
    path = await backup(
      manifest(),
      modify: (bytes) {
        ByteData.sublistView(bytes).setUint32(
          header(bytes, 'media/a.jpg') + 38,
          0xa1ff0000,
          Endian.little,
        );
      },
    );
    await expectLater(store.importBackup(path), throwsFormatException);
    expect(await Directory('${store.root!.path}/media').list().length, 0);
  });
  test(
    'lying archive sizes cannot bypass the actual extraction limit',
    () async {
      final path = await backup(
        manifest(),
        files: {'media/a.jpg': List.filled(8192, 7)},
        modify: (bytes) {
          ByteData.sublistView(
            bytes,
          ).setUint32(header(bytes, 'media/a.jpg') + 24, 1, Endian.little);
        },
      );
      final limited = ProjectStore(
        root: store.root,
        backupLimits: const BackupLimits(entryBytes: 4096, totalBytes: 4096),
      );
      await expectLater(limited.importBackup(path), throwsFormatException);
      expect(await Directory('${store.root!.path}/media').list().length, 0);
      expect(await store.projects(), isEmpty);
    },
  );
  test(
    'malformed fields roll back extracted media and do not save a project',
    () async {
      final data = manifest();
      data['place'] = [];
      final path = await backup(data);
      await expectLater(store.importBackup(path), throwsFormatException);
      expect(await Directory('${store.root!.path}/media').list().length, 0);
      expect(await store.projects(), isEmpty);
    },
  );
  test('missing later media rolls back files already restored', () async {
    final data = manifest();
    (data['clips'] as List).add(
      ReelClip(
        id: 'b',
        path: 'media/missing.jpg',
        name: 'Missing',
        isVideo: false,
      ).toJson(),
    );
    final path = await backup(data);
    await expectLater(store.importBackup(path), throwsFormatException);
    expect(await Directory('${store.root!.path}/media').list().length, 0);
  });
  test(
    'a damaged saved schema does not hide healthy library projects',
    () async {
      await store.save(ReelProject(title: 'Healthy'));
      await File(
        '${store.root!.path}/projects/broken.json',
      ).writeAsString('{"clips":"wrong type"}');
      expect((await store.projects()).single.title, 'Healthy');
    },
  );
}
