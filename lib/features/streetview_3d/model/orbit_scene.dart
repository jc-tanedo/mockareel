import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import 'building_appearance.dart';

class OrbitFootprint {
  final double height;
  final List<Offset> points;
  final Offset center;
  late final Path outline = Path()..addPolygon(points, true);
  late final Rect bounds = outline.getBounds();
  final BuildingAppearance appearance;
  late final int _paletteSeed =
      (bounds.center.dx.round() * 73856093 ^
              bounds.center.dy.round() * 19349663 ^
              bounds.width.round() * 83492791)
          .abs();
  Color color({required bool roof, required bool dark}) =>
      appearance.base(top: roof, seed: _paletteSeed, dark: dark);
  OrbitFootprint(
    this.height,
    this.points, [
    this.appearance = const BuildingAppearance(),
  ]) : center = points.reduce((a, b) => a + b) / points.length.toDouble();

  bool blocksRay(Offset start, Offset direction, double reach) {
    final end = start + direction * reach;
    if (!bounds.overlaps(Rect.fromPoints(start, end).inflate(.01))) {
      return false;
    }
    if (outline.contains(start)) return true;
    for (int i = 0; i < points.length; i++) {
      final offset = points[i] - start;
      final edge = points[(i + 1) % points.length] - points[i];
      final cross = direction.dx * edge.dy - direction.dy * edge.dx;
      if (cross.abs() < 1e-8) continue;
      final distance = (offset.dx * edge.dy - offset.dy * edge.dx) / cross;
      final along =
          (offset.dx * direction.dy - offset.dy * direction.dx) / cross;
      if (distance >= 0 && distance < reach && along >= 0 && along <= 1) {
        return true;
      }
    }
    return false;
  }
}

/// Upright panel on an exterior wall. Distances are in local map metres.
class OrbitWallMount {
  static const defaultHeading = 52 * pi / 180;
  // World dimensions of the existing 360 × 640 panel at the default map scale.
  static const defaultWidth = 135.0, defaultHeight = 192 / (.8 * .77);
  final Offset center, tangent;
  final double baseAbovePin, sizeFactor;
  final String id;
  const OrbitWallMount(
    this.id,
    this.center,
    this.tangent,
    this.baseAbovePin,
    this.sizeFactor,
  );
  Offset get normal => Offset(-tangent.dy, tangent.dx);

  static Map<String, OrbitWallMount> candidates(OrbitScene scene) {
    if (scene.atlas != null) return const {};
    final view = Offset(-sin(defaultHeading), cos(defaultHeading));
    const radius = 120.0;
    // Preserve clear local placements before trying a different camera heading
    // or a wall across a larger station plaza.
    final groups = List.generate(3, (_) => <(double, OrbitWallMount)>[]);
    for (final building in scene.shapes) {
      if (building.height < 8 ||
          !building.bounds.inflate(radius).contains(Offset.zero)) {
        continue;
      }
      final points = building.points;
      double area = 0;
      for (int i = 0; i < points.length; i++) {
        final a = points[i], b = points[(i + 1) % points.length];
        area += a.dx * b.dy - b.dx * a.dy;
      }
      if (area.abs() < 4) continue;
      for (int i = 0; i < points.length; i++) {
        final a = points[i], edge = points[(i + 1) % points.length] - a;
        final length = edge.distance;
        if (length < 5) continue;
        final axis = edge / length;
        // Orient the tangent so its left normal points outside either winding.
        final tangent = area > 0 ? -axis : axis;
        final normal = Offset(-tangent.dy, tangent.dx);
        final facing = normal.dx * view.dx + normal.dy * view.dy;
        final factor = min(
          1.0,
          min(
            .86 * length / defaultWidth,
            .80 * building.height / defaultHeight,
          ),
        );
        if (factor * defaultHeight < 6) continue;
        final margin = .5 * defaultWidth * factor + .04 * length;
        final along = -(a.dx * axis.dx + a.dy * axis.dy);
        final center = a + axis * along.clamp(margin, length - margin);
        final score = center.distance + 12 * (1 - facing);
        if (center.distance > radius) continue;
        final group = center.distance > 60
            ? 2
            : facing < .5
            ? 1
            : 0;
        String endpoint(Offset p) => '${p.dx.round()},${p.dy.round()}';
        final endpoints = [
          endpoint(a),
          endpoint(points[(i + 1) % points.length]),
        ]..sort();
        groups[group].add((
          score,
          OrbitWallMount(
            endpoints.join('/'),
            center + normal * .05,
            tangent,
            scene.elevation(building.center) -
                scene.elevation(Offset.zero) +
                (building.height - factor * defaultHeight) / 2,
            factor,
          ),
        ));
      }
    }
    final visible = <String, OrbitWallMount>{};
    for (final candidates in groups) {
      candidates.sort((a, b) => a.$1.compareTo(b.$1));
      for (final (_, candidate) in candidates) {
        if (!visible.containsKey(candidate.id) &&
            !visible.values.any(candidate._overlapsPanel) &&
            candidate._visible(scene)) {
          visible[candidate.id] = candidate;
        }
      }
    }
    return Map.unmodifiable(visible);
  }

  // Providers can split a single facade into slightly different segments.
  // Avoid offering two placements on top of one another on the same face.
  bool _overlapsPanel(OrbitWallMount other) {
    final d = other.center - center;
    double dot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;
    if (dot(normal, other.normal) < .998 || dot(d, normal).abs() > 1) {
      return false;
    }
    final smaller = min(sizeFactor, other.sizeFactor);
    final overlap =
        defaultWidth * (sizeFactor + other.sizeFactor) / 2 -
        dot(d, tangent).abs();
    final vertical =
        min(
          baseAbovePin + defaultHeight * sizeFactor,
          other.baseAbovePin + defaultHeight * other.sizeFactor,
        ) -
        max(baseAbovePin, other.baseAbovePin);
    return overlap >= .8 * defaultWidth * smaller &&
        vertical >= .8 * defaultHeight * smaller;
  }

  // Trace rays from the lower corners towards the camera at both ends of
  // the media shot. Reject interior walls and facades hidden by other roofs.
  bool _visible(OrbitScene scene) {
    final height =
        scene.elevation(Offset.zero) +
        baseAbovePin +
        .04 * sizeFactor * defaultHeight;
    for (final side in [-.5, .5]) {
      final corner = center + tangent * (side * sizeFactor * defaultWidth);
      if (scene.elevation(corner) >
          scene.elevation(Offset.zero) + baseAbovePin) {
        return false;
      }
    }
    for (final building in scene.shapes) {
      if (building.height <= 0) continue;
      final rise = scene.elevation(building.center) + building.height - height;
      if (rise <= 0) continue;
      final reach = rise * .77 / .64;
      if (!building.bounds
          .inflate(reach + sizeFactor * defaultWidth / 2)
          .contains(center)) {
        continue;
      }
      for (final sign in [-1, 0, 1]) {
        final start =
            center + tangent * (sign * .46 * sizeFactor * defaultWidth);
        for (final angle in [-13.0, 0.0, 13.0]) {
          final yaw = angle * pi / 180;
          final ray = normal * cos(yaw) + tangent * sin(yaw);
          if (building.blocksRay(start, ray, reach)) return false;
        }
      }
    }
    return true;
  }
}

/// Heights in metres, on a 25 × 25 grid centred on the selected pin.
/// Negative feature heights denote road, park and water polygons.
class OrbitScene {
  final List<OrbitFootprint> shapes;
  final List<double> grid;
  final String credit;
  final Uint8List? atlas;
  OrbitScene(this.shapes, this.grid, this.credit, {this.atlas});
  late final Map<String, OrbitWallMount> walls = OrbitWallMount.candidates(
    this,
  );
  OrbitWallMount? get wallMount => walls.values.firstOrNull;
  OrbitWallMount? wallFor(String? id) => walls[id] ?? wallMount;
  // A refreshed survey can round the same facade endpoints to adjacent metres.
  // Only keep a previous choice when both ends still match a visible wall.
  String? matchingWall(String? id) {
    if (id == null || walls.containsKey(id)) return id;
    final coords = id.split(RegExp('[,/]')).map(double.tryParse).toList();
    if (coords.length != 4 || coords.any((v) => v == null || !v.isFinite)) {
      return null;
    }
    final a = Offset(coords[0]!, coords[1]!),
        b = Offset(coords[2]!, coords[3]!);
    String? match;
    var best = 4.01;
    for (final key in walls.keys) {
      final edge = key.split(RegExp('[,/]')).map(double.parse).toList();
      final p = Offset(edge[0], edge[1]), q = Offset(edge[2], edge[3]);
      final distance = min(
        max((p - a).distanceSquared, (q - b).distanceSquared),
        max((p - b).distanceSquared, (q - a).distanceSquared),
      );
      if (distance < best) {
        match = key;
        best = distance;
      }
    }
    return match;
  }

  String get placementDescription => describeWall(null);
  String describeWall(String? id) {
    if (atlas != null) {
      return 'Media at pin · This capture contains imagery only.';
    }
    if (wallFor(id) case final mount?) {
      return 'Media on building wall · ${mount.center.distance.round()} m from pin';
    }
    return shapes.any((s) => s.height > 0)
        ? 'Media at pin · No clear wall fits within 120 m.'
        : 'Media at pin · No building footprints in this capture.';
  }

  String get coverage {
    if (atlas != null) return 'Google Photorealistic 3D Tiles · Media at pin';
    final count = shapes.where((s) => s.height > 0).length;
    final footprints = count == 0
        ? 'no building footprints loaded'
        : '$count building ${count == 1 ? 'footprint' : 'footprints'}';
    final placement = wallMount == null
        ? 'Media at pin'
        : 'Media on building wall';
    return 'Open data · $footprints · $placement';
  }

  factory OrbitScene.decode(String source) {
    if (source.length > 12000000) {
      throw const FormatException('Map scene is too large.');
    }
    final data = jsonDecode(source) as Map;
    if (data['provider'] == 'google-3d') {
      final bytes = base64Decode(data['atlas'] as String);
      if (bytes.length < 64 || bytes[0] != 255 || bytes[1] != 216) {
        throw const FormatException('Invalid Google orbit frames.');
      }
      return OrbitScene([], [], data['credit'] as String, atlas: bytes);
    }
    final shapes = <OrbitFootprint>[];
    double number(dynamic n) {
      if (n is! num || !n.isFinite || n.abs() > 100000) {
        throw const FormatException('Invalid map coordinate.');
      }
      return n.toDouble();
    }

    final rows = data['shapes'] as List;
    if (rows.length > 20000) {
      throw const FormatException('Too many map features.');
    }
    for (final row in rows) {
      final coords = row[1] as List;
      if (coords.length < 6 || coords.length.isOdd || coords.length > 16000) {
        continue;
      }
      shapes.add(
        OrbitFootprint(
          number(row[0]),
          [
            for (int i = 0; i < coords.length; i += 2)
              Offset(number(coords[i]), number(coords[i + 1])),
          ],
          row.length > 2 && row[2] is Map
              ? BuildingAppearance.fromJson(row[2] as Map)
              : const BuildingAppearance(),
        ),
      );
    }
    final grid = (data['grid'] as List).map(number).toList();
    if (grid.length != 625) {
      throw const FormatException('Invalid terrain grid.');
    }
    return OrbitScene(shapes, grid, data['credit'] as String);
  }

  /// Relief around the media pin, including nearby roofs, in metres.
  late final double localRelief = _measureRelief();
  double _measureRelief() {
    final center = elevation(Offset.zero);
    double low = center, high = center;
    void include(double height) {
      if (height < low) low = height;
      if (height > high) high = height;
    }

    for (int row = 9; row <= 15; row++) {
      for (int col = 9; col <= 15; col++) {
        include(grid[row * 25 + col]);
      }
    }
    for (final shape in shapes) {
      if (shape.height > 0 && shape.center.distanceSquared <= 180 * 180) {
        include(elevation(shape.center) + shape.height);
      }
    }
    return high - low;
  }

  double elevation(Offset p) {
    final x = ((p.dx + 600) / 50).clamp(0.0, 23.99999),
        z = ((p.dy + 600) / 50).clamp(0.0, 23.99999);
    final i = x.floor() + 25 * z.floor(), a = x - x.floor(), b = z - z.floor();
    return (grid[i] * (1 - a) + grid[i + 1] * a) * (1 - b) +
        (grid[i + 25] * (1 - a) + grid[i + 26] * a) * b;
  }
}
