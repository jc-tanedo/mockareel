import 'dart:convert';
import 'dart:io';
import 'dart:ui';

class OrbitFootprint {
  final double height;
  final List<Offset> points;
  final Offset center;
  OrbitFootprint(this.height, this.points)
    : center = points.reduce((a, b) => a + b) / points.length.toDouble();
}

/// Heights in metres, on a 25 × 25 grid centred on the selected pin.
/// Negative feature heights denote road, park and water polygons.
class OrbitScene {
  final List<OrbitFootprint> shapes;
  final List<double> grid;
  final String credit;
  OrbitScene(this.shapes, this.grid, this.credit);

  factory OrbitScene.decode(String source) {
    if (source.length > 4000000) {
      throw const FormatException('Map scene is too large.');
    }
    final data = jsonDecode(source) as Map;
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
        OrbitFootprint(number(row[0]), [
          for (int i = 0; i < coords.length; i += 2)
            Offset(number(coords[i]), number(coords[i + 1])),
        ]),
      );
    }
    final grid = (data['grid'] as List).map(number).toList();
    if (grid.length != 625) {
      throw const FormatException('Invalid terrain grid.');
    }
    return OrbitScene(shapes, grid, data['credit'] as String);
  }
  double elevation(Offset p) {
    final x = ((p.dx + 600) / 50).clamp(0.0, 23.99999),
        z = ((p.dy + 600) / 50).clamp(0.0, 23.99999);
    final i = x.floor() + 25 * z.floor(), a = x - x.floor(), b = z - z.floor();
    return (grid[i] * (1 - a) + grid[i + 1] * a) * (1 - b) +
        (grid[i + 25] * (1 - a) + grid[i + 26] * a) * b;
  }

  // Map assets are immutable. Hold a few decoded scenes for synchronous
  // first paint during frame-by-frame Android export.
  static final _cache = <String, OrbitScene>{};
  static OrbitScene? cached(String path) => _cache[path];
  static Future<OrbitScene> load(String path) async {
    final hit = cached(path);
    if (hit != null) return hit;
    final file = File(path);
    if (await file.length() > 4000000) {
      throw const FormatException('Map scene is too large.');
    }
    final scene = OrbitScene.decode(await file.readAsString());
    if (_cache.length >= 4) _cache.remove(_cache.keys.first);
    return _cache[path] = scene;
  }
}
