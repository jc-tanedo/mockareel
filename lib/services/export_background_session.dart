import 'package:flutter/services.dart';

/// One foreground export session, including Flutter capture and native encoding.
class ExportBackgroundSession {
  static const channel = MethodChannel('dev.mockareel/export-session');
  bool _active = false;
  final _updates = Stopwatch();
  String? _status;

  Future<bool?> start(String title) async {
    try {
      final enabled = await channel.invokeMethod<bool>('start', {
        'title': title,
      });
      _active = true;
      _status = null;
      _updates.reset();
      return enabled;
    } on MissingPluginException {
      // Platforms without the Android service retain their existing export flow.
      return null;
    }
  }

  Future<void> update(String status, double? progress) async {
    if (!_active) return;
    if (_status == status &&
        _updates.isRunning &&
        _updates.elapsedMilliseconds < 1000) {
      return;
    }
    _status = status;
    _updates
      ..reset()
      ..start();
    await channel.invokeMethod<void>('update', {
      'status': status,
      'progress': progress,
    });
  }

  Future<void> finish({required bool complete}) async {
    if (!_active) return;
    _active = false;
    _updates.stop();
    await channel.invokeMethod<void>('finish', {'complete': complete});
  }
}
