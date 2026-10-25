import 'dart:io';
import 'dart:ui' as ui;

/// Media3 rejects GIF MIME inputs even though Flutter can display them. Keep
/// project originals intact and supply a bounded PNG first frame to the encoder.
class ExportImages {
  Directory? _temp;
  final _paths = <String, String>{};
  Future<String> prepare(String path) async {
    if (_paths.containsKey(path)) return _paths[path]!;
    final source = File(path);
    // Missing sources are reported by the native renderer's existing validation.
    if (!await source.exists()) return path;
    final handle = await source.open();
    late final List<int> signature;
    try {
      signature = await handle.read(6);
    } finally {
      await handle.close();
    }
    final magic = String.fromCharCodes(signature);
    if (magic != 'GIF87a' && magic != 'GIF89a') return path;
    if (await source.length() > 64 * 1024 * 1024) {
      throw const FormatException(
        'This GIF is too large to prepare. Convert it to a video or replace it with a photo.',
      );
    }
    final buffer = await ui.ImmutableBuffer.fromFilePath(path);
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    ui.Image? image;
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final scale =
          2160 /
          (descriptor.width > descriptor.height
              ? descriptor.width
              : descriptor.height);
      codec = await descriptor.instantiateCodec(
        targetWidth: scale < 1
            ? (descriptor.width * scale).round().clamp(1, 2160)
            : descriptor.width,
        targetHeight: scale < 1
            ? (descriptor.height * scale).round().clamp(1, 2160)
            : descriptor.height,
      );
      image = (await codec.getNextFrame()).image;
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) {
        throw const FormatException('Could not prepare the GIF photo.');
      }
      _temp ??= await Directory.systemTemp.createTemp(
        'mockareel-export-images-',
      );
      final target = File('${_temp!.path}/${_paths.length}.png');
      await target.writeAsBytes(png.buffer.asUint8List(), flush: true);
      return _paths[path] = target.path;
    } finally {
      image?.dispose();
      codec?.dispose();
      descriptor?.dispose();
      buffer.dispose();
    }
  }

  Future<void> dispose() async {
    final temp = _temp;
    if (temp != null && await temp.exists()) await temp.delete(recursive: true);
    _paths.clear();
    _temp = null;
  }
}
