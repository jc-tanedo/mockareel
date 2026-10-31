/// Android devices can expose only one hardware encoder. Source processing,
/// GIF conversion and reel export share this queue; playback uses decoders.
abstract final class MediaPreparationQueue {
  static Future<void> _tail = Future.value();
  static Future<T> run<T>(Future<T> Function() work) {
    final task = _tail.then((_) => work());
    _tail = task.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return task;
  }
}
