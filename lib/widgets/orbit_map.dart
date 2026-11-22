import 'dart:math';
import 'package:flutter/material.dart';
import '../model/orbit_scene.dart';

class OrbitMap extends StatefulWidget {
  final String path;
  final double progress;
  final bool dark;
  const OrbitMap({
    super.key,
    required this.path,
    required this.progress,
    required this.dark,
  });
  @override
  State<OrbitMap> createState() => _OrbitMapState();
}

class _OrbitMapState extends State<OrbitMap> {
  late var scene = OrbitScene.load(widget.path);
  @override
  void didUpdateWidget(OrbitMap old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) scene = OrbitScene.load(widget.path);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<OrbitScene>(
    future: scene,
    builder: (context, snapshot) {
      final map =
          OrbitScene.cached(widget.path) ??
          (snapshot.connectionState == ConnectionState.done
              ? snapshot.data
              : null);
      if (map == null) {
        return Center(
          child: snapshot.hasError
              ? const Text('Map unavailable')
              : const CircularProgressIndicator(),
        );
      }
      return Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: OrbitPainter(map, widget.progress, widget.dark)),
          Align(
            alignment: Alignment.bottomCenter,
            child: ColoredBox(
              color: Colors.black87,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  map.credit,
                  style: const TextStyle(color: Colors.white, fontSize: 8),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

class OrbitPainter extends CustomPainter {
  final OrbitScene scene;
  final double progress;
  final bool dark;
  OrbitPainter(this.scene, this.progress, this.dark);
  @override
  void paint(Canvas canvas, Size size) {
    final angle = (-65 + 26 * progress) * pi / 180,
        c = cos(angle),
        s = sin(angle);
    final scale = size.width / 450,
        origin = Offset(size.width * .5, size.height * .54);
    final ground = scene.elevation(Offset.zero);
    double depth(Offset p) => p.dx * s + p.dy * c;
    Offset project(Offset p, double h) =>
        origin +
        Offset(
          (p.dx * c - p.dy * s) * scale,
          (depth(p) * .64 - (h - ground) * .77) * scale,
        );
    final brush = Paint();
    void face(List<Offset> points, Color color) {
      final path = Path()..addPolygon(points, true);
      if (path.getBounds().overlaps(Offset.zero & size)) {
        canvas.drawPath(path, brush..color = color);
      }
    }

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final land = dark ? const Color(0xff273545) : const Color(0xffc4d1bd);
    canvas.drawColor(land, BlendMode.src);
    for (var z = 0; z < 24; z++) {
      for (var x = 0; x < 24; x++) {
        final p = Offset(x * 50.0 - 600, z * 50.0 - 600), i = z * 25 + x;
        final heights = scene.grid;
        face(
          [
            project(p, heights[i]),
            project(p + const Offset(50, 0), heights[i + 1]),
            project(p + const Offset(50, 50), heights[i + 26]),
            project(p + const Offset(0, 50), heights[i + 25]),
          ],
          Color.lerp(
            land,
            Colors.black,
            ((heights[i + 1] - heights[i]) / 90 + .08).clamp(0, 0.35),
          )!,
        );
      }
    }
    final buildings = <OrbitFootprint>[];
    for (final f in scene.shapes) {
      if (f.height >= 0) {
        buildings.add(f);
        continue;
      }
      face(
        [for (final p in f.points) project(p, scene.elevation(p))],
        f.height == -3
            ? Colors.blueGrey
            : f.height == -2
            ? const Color(0xff608568)
            : dark
            ? const Color(0xff556572)
            : const Color(0xffe1dfd4),
      );
    }
    buildings.sort((a, b) => depth(a.center).compareTo(depth(b.center)));
    for (final b in buildings) {
      final base = scene.elevation(b.center),
          top = [for (final p in b.points) project(p, base + b.height)];
      final bottom = [for (final p in b.points) project(p, base)];
      final bounds =
          (Path()
                ..addPolygon(top, true)
                ..addPolygon(bottom, true))
              .getBounds();
      if (!bounds.overlaps(Offset.zero & size)) continue;
      final sides = List.generate(top.length, (i) => i)
        ..sort(
          (i, j) => (depth(b.points[i]) + depth(b.points[(i + 1) % top.length]))
              .compareTo(
                depth(b.points[j]) + depth(b.points[(j + 1) % top.length]),
              ),
        );
      for (final i in sides) {
        final j = (i + 1) % top.length;
        final edge = b.points[j] - b.points[i];
        face(
          [bottom[i], bottom[j], top[j], top[i]],
          Color.lerp(
            dark ? const Color(0xff3b5164) : const Color(0xff839198),
            dark ? const Color(0xff8496a6) : const Color(0xffc5cacc),
            .5 + .42 * cos(edge.direction),
          )!,
        );
      }
      face(top, dark ? const Color(0xff93a7b7) : const Color(0xffe9e6df));
    }
    canvas.drawCircle(origin, 5, brush..color = Colors.white);
    canvas.drawCircle(origin, 3.5, brush..color = Colors.red);
    canvas.restore();
  }

  @override
  bool shouldRepaint(OrbitPainter old) =>
      scene != old.scene || progress != old.progress || dark != old.dark;
}
