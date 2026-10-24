import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:archive/archive_io.dart';

/// Conservative mobile import budgets; tests can exercise smaller limits.
class BackupLimits {
  final int archiveBytes, entryBytes, totalBytes, entries, clips;
  const BackupLimits({
    this.archiveBytes = 2 * 1024 * 1024 * 1024,
    this.entryBytes = 1024 * 1024 * 1024,
    this.totalBytes = 4 * 1024 * 1024 * 1024,
    this.entries = 2048,
    this.clips = 512,
  });
}

/// Untrusted archives never choose destination paths or decompress without a budget.
class ProjectArchive {
  final InputFileStream _input;
  final Archive _archive;
  final BackupLimits limits;
  int _expanded = 0;
  ProjectArchive._(this._input, this._archive, this.limits);

  static Future<ProjectArchive> open(String path, BackupLimits limits) async {
    final file = File(path);
    final size = await file.length();
    if (size > limits.archiveBytes) {
      throw const FormatException('Project backup is too large.');
    }
    await _preflight(file, size, limits);
    final input = InputFileStream(path);
    try {
      // Preflight rejects links/encryption before the decoder can interpret them.
      final archive = ZipDecoder().decodeStream(input);
      return ProjectArchive._(input, archive, limits);
    } catch (_) {
      input.closeSync();
      rethrow;
    }
  }

  Map<String, dynamic> manifest() {
    final entry = _file('project.json');
    const maxManifest = 1024 * 1024;
    if (entry.size > maxManifest) {
      throw const FormatException('Project manifest is too large.');
    }
    final output = _LimitedMemory(
      min(entry.size, min(maxManifest, limits.totalBytes)),
    );
    entry.writeContent(output);
    if (output.length != entry.size) {
      throw const FormatException('Invalid project manifest size.');
    }
    _expanded += output.length;
    final data = jsonDecode(utf8.decode(output.getBytes()));
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Invalid project manifest.');
    }
    return data;
  }

  void extract(String source, String destination) {
    final entry = _file(source);
    final budget = min(
      entry.size,
      min(limits.entryBytes, limits.totalBytes - _expanded),
    );
    if (budget < 0) {
      throw const FormatException(
        'Project backup exceeds its extraction budget.',
      );
    }
    final output = _LimitedFile(destination, budget);
    try {
      entry.writeContent(output);
      if (output.length != entry.size) {
        throw const FormatException('Invalid media size in project backup.');
      }
      _expanded += output.length;
    } finally {
      output.closeSync();
    }
  }

  ArchiveFile _file(String name) {
    final entry = _archive.findFile(name);
    if (entry == null || !entry.isFile || entry.isSymbolicLink) {
      throw const FormatException('A media file is missing from this backup.');
    }
    return entry;
  }

  void close() => _input.closeSync();

  static Future<void> _preflight(
    File file,
    int size,
    BackupLimits limits,
  ) async {
    // Our portable format uses ordinary, single-disk ZIPs. Inspect bounded central
    // directory metadata before allocating file entries or decoding any payload.
    if (size < 22) throw const FormatException('Invalid project backup.');
    final input = await file.open();
    try {
      final tailLength = min(size, 65557);
      await input.setPosition(size - tailLength);
      final tail = await input.read(tailLength);
      final tailData = ByteData.sublistView(tail);
      var end = -1;
      for (var i = tail.length - 22; i >= 0; i--) {
        if (tailData.getUint32(i, Endian.little) == 0x06054b50 &&
            i + 22 + tailData.getUint16(i + 20, Endian.little) == tail.length) {
          end = i;
          break;
        }
      }
      if (end < 0) {
        throw const FormatException('Invalid project backup directory.');
      }
      final count = tailData.getUint16(end + 10, Endian.little);
      final bytes = tailData.getUint32(end + 12, Endian.little);
      final offset = tailData.getUint32(end + 16, Endian.little);
      if (count > limits.entries ||
          bytes > 2 * 1024 * 1024 ||
          offset + bytes > size - tailLength + end ||
          tailData.getUint16(end + 4, Endian.little) != 0 ||
          tailData.getUint16(end + 6, Endian.little) != 0) {
        throw const FormatException(
          'Project backup has unsupported or oversized archive metadata.',
        );
      }
      await input.setPosition(offset);
      final directory = await input.read(bytes);
      if (directory.length != bytes) {
        throw const FormatException('Truncated project backup.');
      }
      final data = ByteData.sublistView(directory);
      final names = <String>{};
      var position = 0, total = 0, entries = 0;
      while (position < bytes) {
        if (position + 46 > bytes ||
            data.getUint32(position, Endian.little) != 0x02014b50) {
          throw const FormatException('Invalid project backup entry.');
        }
        final flags = data.getUint16(position + 8, Endian.little);
        final method = data.getUint16(position + 10, Endian.little);
        final expanded = data.getUint32(position + 24, Endian.little);
        final nameLength = data.getUint16(position + 28, Endian.little);
        final length =
            46 +
            nameLength +
            data.getUint16(position + 30, Endian.little) +
            data.getUint16(position + 32, Endian.little);
        final mode = data.getUint32(position + 38, Endian.little) >> 16;
        if (position + length > bytes ||
            ++entries > limits.entries ||
            expanded > limits.entryBytes ||
            (total += expanded) > limits.totalBytes ||
            flags & 1 != 0 ||
            mode & 0xf000 == 0xa000 ||
            (method != 0 && method != 8)) {
          throw const FormatException(
            'Project backup contains unsupported or oversized media.',
          );
        }
        final name = utf8.decode(
          directory.sublist(position + 46, position + 46 + nameLength),
        );
        if (name.isEmpty ||
            name.startsWith('/') ||
            name.contains('\\') ||
            name.contains(':') ||
            name.contains('\u0000') ||
            name.split('/').contains('..') ||
            !names.add(name)) {
          throw const FormatException(
            'Unsafe or duplicate project backup path.',
          );
        }
        position += length;
      }
      if (entries != count) {
        throw const FormatException('Invalid project backup entry count.');
      }
    } finally {
      await input.close();
    }
  }
}

class _LimitedMemory extends OutputMemoryStream {
  final int limit;
  _LimitedMemory(this.limit);
  @override
  void writeBytes(List<int> bytes, {int? length}) {
    if (this.length + (length ?? bytes.length) > limit) {
      throw const FormatException(
        'Project backup exceeds its extraction budget.',
      );
    }
    super.writeBytes(bytes, length: length);
  }

  @override
  void writeByte(int value) {
    if (length >= limit) {
      throw const FormatException(
        'Project backup exceeds its extraction budget.',
      );
    }
    super.writeByte(value);
  }
}

class _LimitedFile extends OutputFileStream {
  final int limit;
  _LimitedFile(String path, this.limit)
    : super.withFileHandle(FileHandle(path, mode: FileAccess.write));
  @override
  void writeBytes(List<int> bytes, {int? length}) {
    if (this.length + (length ?? bytes.length) > limit) {
      throw const FormatException(
        'Project backup exceeds its extraction budget.',
      );
    }
    super.writeBytes(bytes, length: length);
  }

  @override
  void writeByte(int value) {
    if (length >= limit) {
      throw const FormatException(
        'Project backup exceeds its extraction budget.',
      );
    }
    super.writeByte(value);
  }
}
