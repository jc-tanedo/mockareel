import 'project.dart';

class StreetviewScene {
  final String kind;
  final int mediaIndex;
  final double start, duration;
  const StreetviewScene(this.kind, this.mediaIndex, this.start, this.duration);
  double elapsed(double time) => (time - start).clamp(0, duration);
}

/// Map and movement durations INCLUDE their final tap ripple. Ripples never add
/// another scene or extend the output. A return-to-map tap is a separate scene.
abstract final class StreetviewTimeline {
  static const rippleSeconds = .2;
  static List<StreetviewScene> scenes(ReelProject p) {
    if (p.clips.isEmpty) return [];
    final result = <StreetviewScene>[];
    var start = 0.0;
    void add(String kind, int index, double duration) {
      result.add(StreetviewScene(kind, index, start, duration));
      start += duration;
    }

    add('map', 0, p.streetview.openingMapSeconds);
    for (var i = 0; i < p.clips.length; i++) {
      add('media', i, p.clips[i].duration);
      final settings = p.clips[i].streetview;
      if (i + 1 < p.clips.length) {
        if (settings.transition == 'map') {
          add('back', i, settings.transitionSeconds);
          add('map', i + 1, p.streetview.laterMapSeconds);
        } else {
          add('arrow', i, settings.transitionSeconds);
        }
      } else if (p.streetview.endOnMap) {
        add('back', i, settings.transitionSeconds);
        add('ending-map', i, p.streetview.laterMapSeconds);
      }
    }
    return result;
  }

  static double duration(ReelProject p) =>
      scenes(p).fold(0, (n, s) => n + s.duration);
  static StreetviewScene at(ReelProject p, double time) {
    final all = scenes(p);
    return all.firstWhere(
      (s) => time < s.start + s.duration,
      orElse: () =>
          all.isEmpty ? const StreetviewScene('map', 0, 0, 0) : all.last,
    );
  }

  static double mediaStart(ReelProject p, int index) =>
      scenes(p)
          .where((s) => s.kind == 'media' && s.mediaIndex == index)
          .firstOrNull
          ?.start ??
      0;
}
