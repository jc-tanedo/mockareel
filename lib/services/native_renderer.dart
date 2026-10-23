import 'package:flutter/services.dart';
import '../model/project.dart';

class NativeRenderer {
  static const channel = MethodChannel('dev.mockareel/render');
  static const events = EventChannel('dev.mockareel/render-progress');
  Stream<double> get progress =>
      events.receiveBroadcastStream().map((e) => (e as num).toDouble());
  Future<Map<String, dynamic>> inspect(String path) async =>
      Map<String, dynamic>.from(
        await channel.invokeMethod<Map>('inspect', {'path': path}) ?? {},
      );
  Future<String> export(ReelProject project, List<String> overlays) async {
    final path = await channel.invokeMethod<String>('export', {
      'clips': project.clips.map((c) => c.toJson()).toList(),
      'overlays': overlays,
    });
    if (path == null) throw StateError('The renderer did not return a video.');
    return path;
  }

  Future<void> cancel() => channel.invokeMethod('cancel');
  Future<String> saveToGallery(String path) async =>
      (await channel.invokeMethod<String>('saveToGallery', {'path': path}))!;
}
