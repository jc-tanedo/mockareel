import 'dart:math';
import 'project.dart';

/// Logical coordinates measured from the reference's fixed place sheet.
abstract final class TemplateLayout {
  static const width = 360.0, height = 640.0;
  static const galleryLeft = 16.0, galleryTop = 250.0;
  static const galleryWidth = 328.0, galleryHeight = 250.0;
  static const gap = 8.0, radius = 12.0;
  static const exportScale = 3.0;
  static double transitionDuration(ReelProject p, int index) =>
      index <= 0 ? 0 : min(p.slideSeconds, p.clips[index].duration * .45);
  static List<double> starts(ReelProject p) {
    var x = 0.0;
    return p.clips.map((c) {
      final start = x;
      x += galleryWidth * c.cardWidth + gap;
      return start;
    }).toList();
  }

  static double offset(ReelProject p, double time) {
    final index = p.clipAt(time);
    if (index <= 0) return 0;
    final positions = starts(p);
    final duration = transitionDuration(p, index);
    final progress = ((time - p.startOf(index)) / duration).clamp(0.0, 1.0);
    final eased = 1 - pow(1 - progress, 3);
    return positions[index - 1] +
        (positions[index] - positions[index - 1]) * eased;
  }

  static Map<String, double> get native => {
    'width': width,
    'height': height,
    'galleryLeft': galleryLeft,
    'galleryTop': galleryTop,
    'galleryWidth': galleryWidth,
    'galleryHeight': galleryHeight,
    'gap': gap,
    'radius': radius,
    'exportScale': exportScale,
  };
}
