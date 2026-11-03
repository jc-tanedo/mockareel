import 'package:flutter/widgets.dart';

/// Paints export boundaries even when the engine stops sending display vsyncs.
Future<void> exportCaptureFrame() async {
  final binding = WidgetsBinding.instance;
  final observer = _CaptureFrameObserver(binding);
  binding.addObserver(observer);
  try {
    final painted = binding.endOfFrame;
    if (!binding.framesEnabled) binding.scheduleWarmUpFrame();
    await painted;
  } finally {
    binding.removeObserver(observer);
  }
}

class _CaptureFrameObserver extends WidgetsBindingObserver {
  final WidgetsBinding binding;
  _CaptureFrameObserver(this.binding);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Also unblock a capture that began in the foreground just before Home or
    // screen lock stopped regular frames. Warm-up frames use timers, not vsync.
    if (!binding.framesEnabled) binding.scheduleWarmUpFrame();
  }
}
