import 'dart:math';
import 'dart:ui' show Rect;

/// Coordinates are metres east and south of the scene's pin.
class OrbitGeometry {
  OrbitGeometry(this.height, this.points, this.bounds, this.contributors);

  final double height;
  final List<int> points;
  final Rect bounds;
  final Set<String> contributors;

  static OrbitGeometry? fromRing(
    double height,
    List<int> points, {
    Set<String> contributors = const {},
  }) {
    if (points.length < 6 || points.length > 16000) return null;
    int left = points[0], right = left, top = points[1], bottom = top;
    for (int i = 0; i < points.length; i += 2) {
      final x = points[i], y = points[i + 1];
      if (x.abs() > 100000 || y.abs() > 100000) return null;
      left = min(left, x);
      right = max(right, x);
      top = min(top, y);
      bottom = max(bottom, y);
    }
    final bounds = Rect.fromLTRB(
      left.toDouble(),
      top.toDouble(),
      right.toDouble(),
      bottom.toDouble(),
    );
    if (bounds.isEmpty ||
        !bounds.overlaps(const Rect.fromLTRB(-600, -600, 600, 600))) {
      return null;
    }
    return OrbitGeometry(height, points, bounds, contributors);
  }

  List<Object> toJson() => [height, points];
}

double orbitBuildingHeight(Object? metres, Object? floors) {
  double? positive(Object? value) {
    final n = double.tryParse('$value'.replaceFirst(RegExp(r'\s*m$'), ''));
    return n != null && n.isFinite && n > 0 ? n : null;
  }

  return (positive(metres) ?? (positive(floors) ?? 3) * 3).clamp(2, 900);
}

/// Merge in provider priority order. Compare buildings from different feeds
/// and buffered copies in adjacent tiles, preserving OSM's distinct parts.
class OrbitGeometrySet {
  final shapes = <OrbitGeometry>[];
  final credits = <String>{};
  final contributors = <String>{};
  final _cells = <(int, int), List<(OrbitGeometry, String)>>{};
  int _coordinates = 0;

  void add(String source, List<OrbitGeometry> features) {
    features.sort(
      (a, b) => a.bounds.center.distanceSquared.compareTo(
        b.bounds.center.distanceSquared,
      ),
    );
    for (final feature in features) {
      if (shapes.length >= 1800 ||
          _coordinates + feature.points.length > 240000) {
        continue;
      }
      final bounds = feature.bounds;
      final center = bounds.center;
      final cellX = (center.dx / 64).floor(), cellY = (center.dy / 64).floor();
      if (feature.height > 0) {
        bool duplicate = false;
        for (int x = cellX - 1; x <= cellX + 1 && !duplicate; x++) {
          for (int y = cellY - 1; y <= cellY + 1 && !duplicate; y++) {
            for (final (other, provider)
                in _cells[(x, y)] ?? const <(OrbitGeometry, String)>[]) {
              final overlap = bounds.intersect(other.bounds);
              if (overlap.isEmpty) continue;
              final area = overlap.width * overlap.height;
              final union =
                  bounds.width * bounds.height +
                  other.bounds.width * other.bounds.height -
                  area;
              if (area / union > (provider == source ? .98 : .67)) {
                duplicate = true;
                break;
              }
            }
          }
        }
        if (duplicate) continue;
        (_cells[(cellX, cellY)] ??= []).add((feature, source));
      }
      shapes.add(feature);
      _coordinates += feature.points.length;
      credits.add(source);
      contributors.addAll(feature.contributors);
    }
  }
}
