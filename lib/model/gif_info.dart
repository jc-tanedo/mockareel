import 'dart:typed_data';

/// GIF container timing without decompressing image pixels. Delays of 0/10 ms
/// follow browser behavior (100 ms); disposal/compositing stays with Flutter.
class GifInfo {
  final int width, height;
  final List<int> delaysMs;
  GifInfo(this.width, this.height, this.delaysMs);
  double get duration => delaysMs.fold<int>(0, (a, b) => a + b) / 1000;
  static bool signature(List<int> bytes) =>
      bytes.length >= 6 &&
      (String.fromCharCodes(bytes.take(6)) == 'GIF87a' ||
          String.fromCharCodes(bytes.take(6)) == 'GIF89a');
  factory GifInfo.parse(Uint8List bytes) {
    if (!signature(bytes) || bytes.length < 13) {
      throw const FormatException('Invalid GIF header.');
    }
    var p = 6;
    int byte() {
      if (p >= bytes.length) throw const FormatException('Truncated GIF.');
      return bytes[p++];
    }

    int word() {
      final low = byte();
      return low | (byte() << 8);
    }

    void skip(int count) {
      if (count < 0 || p + count > bytes.length) {
        throw const FormatException('Truncated GIF.');
      }
      p += count;
    }

    void blocks() {
      var n = byte();
      while (n != 0) {
        skip(n);
        n = byte();
      }
    }

    final width = word(), height = word(), flags = byte();
    skip(2);
    if (width == 0 || height == 0 || width * height > 32 * 1024 * 1024) {
      throw const FormatException('GIF dimensions are too large.');
    }
    if (flags & 0x80 != 0) skip(3 * (1 << ((flags & 7) + 1)));
    final delays = <int>[];
    var delay = 100;
    while (p < bytes.length) {
      final marker = byte();
      if (marker == 0x3b) break;
      if (marker == 0x21) {
        final label = byte();
        if (label == 0xf9) {
          if (byte() != 4) {
            throw const FormatException('Invalid GIF control block.');
          }
          skip(1);
          final ticks = word();
          delay = ticks <= 1 ? 100 : ticks * 10;
          skip(1);
          if (byte() != 0) {
            throw const FormatException('Invalid GIF control terminator.');
          }
        } else {
          blocks();
        }
      } else if (marker == 0x2c) {
        skip(8);
        final imageFlags = byte();
        if (imageFlags & 0x80 != 0) skip(3 * (1 << ((imageFlags & 7) + 1)));
        skip(1);
        blocks();
        delays.add(delay);
        delay = 100;
        if (delays.length > 2000) {
          throw const FormatException(
            'This GIF has too many frames. Use a video instead.',
          );
        }
      } else {
        throw const FormatException('Invalid GIF block.');
      }
    }
    if (delays.isEmpty) {
      throw const FormatException('The GIF contains no image frames.');
    }
    return GifInfo(width, height, List.unmodifiable(delays));
  }
  int frameAt(double seconds) {
    var remaining = (seconds * 1000 + .000001).floor();
    for (var i = 0; i < delaysMs.length; i++) {
      if (remaining < delaysMs[i]) return i;
      remaining -= delaysMs[i];
    }
    return delaysMs.length - 1;
  }

  /// Quantize once to the app's 30 fps output clock; reuse the same GIF frame
  /// across samples and loop only within the user's selected source phase.
  List<int> samples(double start, double length, bool loop) =>
      List.generate((length * 30).ceil(), (i) {
        var t = start + i / 30;
        t = loop ? t % duration : t.clamp(0, duration - .000001);
        return frameAt(t);
      });
}
