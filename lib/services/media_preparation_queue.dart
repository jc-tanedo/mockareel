import 'dart:async';

/// Android devices can expose only one hardware encoder. Source processing,
/// GIF conversion and reel export share this queue; playback uses decoders.
abstract final class MediaPreparationQueue {
  static Future<void> _tail = Future.value();
  static Future<T> run<T>(Future<T> Function() work) async {
    final previous = _tail;
    final next = Zone.root.run(() => Completer<void>());
    _tail = next.future;
    try {
      await previous;
    } catch (_) {
      // Previous queued work already surfaced its own error to its caller.
    }
    try {
      return await work();
    } finally {
      Zone.root.run(() {
        if (!next.isCompleted) next.complete();
      });
    }
  }
}
