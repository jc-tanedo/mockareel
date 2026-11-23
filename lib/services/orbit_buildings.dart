import 'dart:math';
import '../model/building_appearance.dart';
import 'dart:ui' show Rect;

/// Coordinates are metres east and south of the scene's pin.
class OrbitGeometry {
  OrbitGeometry(
    this.height,
    this.points,
    this.bounds,
    this.contributors,
    this.appearance,
  );
  BuildingAppearance appearance;

  final double height;
  final List<int> points;
  final Rect bounds;
  final Set<String> contributors;

  static OrbitGeometry? fromRing(
    double height,
    List<int> points, {
    Set<String> contributors = const {},
    BuildingAppearance appearance = const BuildingAppearance(),
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
    return OrbitGeometry(height, points, bounds, contributors, appearance);
  }

  List<Object> toJson() => [
    height,
    points,
    if (!appearance.empty) appearance.toJson(),
  ];
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

  // A bounding box alone can also match a courtyard or a neighbouring part.
  bool _sameOutline(OrbitGeometry a, OrbitGeometry b) {
    bool follows(List<int> points, List<int> ring) {
      for (int i = 0; i < points.length; i += 2) {
        var near = false;
        for (int j = 0; j < ring.length; j += 2) {
          final k = (j + 2) % ring.length;
          final dx = ring[k] - ring[j], dy = ring[k + 1] - ring[j + 1];
          final x = points[i] - ring[j], y = points[i + 1] - ring[j + 1];
          final t = ((x * dx + y * dy) / max(1, dx * dx + dy * dy)).clamp(0, 1);
          if ((x - t * dx) * (x - t * dx) + (y - t * dy) * (y - t * dy) <= 9) {
            near = true;
            break;
          }
        }
        if (!near) return false;
      }
      return true;
    }

    // Very detailed outlines can require millions of segment comparisons.
    // Keep their original attributes when this match is too expensive.
    return a.points.length * b.points.length <= 400000 &&
        follows(a.points, b.points) &&
        follows(b.points, a.points);
  }

  void add(String source, List<OrbitGeometry> features) {
    features.sort(
      (a, b) => a.bounds.center.distanceSquared.compareTo(
        b.bounds.center.distanceSquared,
      ),
    );
    for (final feature in features) {
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
                if (!feature.appearance.empty &&
                    area / union >= .90 &&
                    _sameOutline(feature, other)) {
                  final merged = other.appearance.fillFrom(feature.appearance);
                  if (merged.wall != other.appearance.wall ||
                      merged.roof != other.appearance.roof ||
                      merged.wallMaterial != other.appearance.wallMaterial ||
                      merged.roofMaterial != other.appearance.roofMaterial) {
                    other.appearance = merged;
                    credits.add(source);
                    contributors.addAll(feature.contributors);
                  }
                }
                duplicate = true;
                break;
              }
            }
          }
        }
        if (duplicate) continue;
      }
      if (shapes.length >= 1800 ||
          _coordinates + feature.points.length > 240000) {
        continue;
      }
      if (feature.height > 0) {
        (_cells[(cellX, cellY)] ??= []).add((feature, source));
      }
      shapes.add(feature);
      _coordinates += feature.points.length;
      credits.add(source);
      contributors.addAll(feature.contributors);
    }
  }
}
