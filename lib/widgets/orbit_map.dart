import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../model/orbit_scene.dart';
import '../model/orbit_media_pose.dart';

class OrbitMap extends StatelessWidget {
  final String path;
  final double progress, zoom;
  final bool dark;
  const OrbitMap({
    super.key,
    required this.path,
    required this.progress,
    required this.dark,
    this.zoom = 1,
  });
  @override
  Widget build(BuildContext context) => OrbitSceneBuilder(
    path: path,
    builder: (scene, failed) => OrbitMapView(
      scene: scene,
      failed: failed,
      camera: OrbitMediaPose(progress),
      dark: dark,
      zoom: zoom,
    ),
  );
}

class OrbitSceneBuilder extends StatefulWidget {
  final String? path;
  final Widget Function(OrbitScene? scene, bool failed) builder;
  const OrbitSceneBuilder({
    super.key,
    required this.path,
    required this.builder,
  });
  @override
  State<OrbitSceneBuilder> createState() => _OrbitSceneBuilderState();
}

class _OrbitSceneBuilderState extends State<OrbitSceneBuilder> {
  Future<OrbitScene>? _load() =>
      widget.path == null ? null : OrbitScene.load(widget.path!);
  late var scene = _load();
  @override
  void didUpdateWidget(OrbitSceneBuilder old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) scene = _load();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<OrbitScene>(
    future: scene,
    builder: (context, snapshot) => widget.builder(
      widget.path == null
          ? null
          : OrbitScene.cached(widget.path!) ??
                (snapshot.connectionState == ConnectionState.done
                    ? snapshot.data
                    : null),
      snapshot.hasError,
    ),
  );
}

class OrbitMapView extends StatelessWidget {
  final OrbitScene? scene;
  final bool failed, dark;
  final OrbitMediaPose camera;
  final double zoom;
  const OrbitMapView({
    super.key,
    required this.scene,
    required this.failed,
    required this.camera,
    required this.dark,
    required this.zoom,
  });
  @override
  Widget build(BuildContext context) {
    final map = scene;
    if (map == null) {
      return Center(
        child: failed
            ? const Text('Map unavailable')
            : const CircularProgressIndicator(),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        if (map.atlas case final atlas?)
          Image(
            image: atlas,
            excludeFromSemantics: true,
            frameBuilder: (context, child, frame, sync) {
              if (child is! RawImage || child.image == null) return child;
              return CustomPaint(
                painter: _GoogleOrbitPainter(child.image!, camera.progress),
              );
            },
          )
        else
          CustomPaint(
            painter: OrbitPainter(
              map,
              camera.progress,
              dark,
              zoom: zoom,
              camera: camera,
            ),
          ),
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
  }
}

class OrbitPainter extends CustomPainter {
  final OrbitScene scene;
  final double zoom;
  final OrbitMediaPose camera;
  final bool dark, foregroundOnly;
  OrbitPainter(
    this.scene,
    double progress,
    this.dark, {
    this.zoom = 1,
    this.foregroundOnly = false,
    OrbitMediaPose? camera,
  }) : camera = camera ?? OrbitMediaPose(progress);
  @override
  void paint(Canvas canvas, Size size) {
    final angle = camera.heading, c = cos(angle), s = sin(angle);
    final scale = size.width / 450 * zoom,
        origin = camera.pin(size, scale),
        depthScale = camera.depthScale,
        heightScale = camera.heightScale;
    final ground = scene.elevation(Offset.zero);
    double depth(Offset p) => p.dx * s + p.dy * c;
    Offset project(Offset p, double h) =>
        origin +
        Offset(
          (p.dx * c - p.dy * s) * scale,
          (depth(p) * depthScale - (h - ground) * heightScale) * scale,
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
    if (foregroundOnly) {
      final plane = (Path()..addRect(Offset.zero & size)).transform(
        camera.matrix.storage,
      );
      canvas.clipPath(plane);
    }
    final clipBounds = canvas.getLocalClipBounds();
    final land = dark ? const Color(0xff273545) : const Color(0xffc4d1bd);
    if (!foregroundOnly) {
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
    }
    final buildings = <OrbitFootprint>[];
    for (final f in scene.shapes) {
      if (f.height >= 0) {
        if (!foregroundOnly || OrbitMediaPose.inFrontOfPanel(f)) {
          buildings.add(f);
        }
        continue;
      }
      if (foregroundOnly) continue;
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
      if (!bounds.overlaps(clipBounds)) continue;
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
    if (!foregroundOnly) {
      canvas.drawCircle(origin, 5, brush..color = Colors.white);
      canvas.drawCircle(origin, 3.5, brush..color = Colors.red);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(OrbitPainter old) =>
      scene != old.scene ||
      foregroundOnly != old.foregroundOnly ||
      camera.progress != old.camera.progress ||
      camera.turn != old.camera.turn ||
      camera.tilt != old.camera.tilt ||
      camera.focus != old.camera.focus ||
      camera.lift != old.camera.lift ||
      dark != old.dark ||
      zoom != old.zoom;
}

class _GoogleOrbitPainter extends CustomPainter {
  final ui.Image atlas;
  final double progress;
  _GoogleOrbitPainter(this.atlas, this.progress);
  @override
  void paint(Canvas canvas, Size size) {
    final at = progress.clamp(0.0, 1.0) * 23;
    final w = atlas.width / 6, h = atlas.height / 4;
    void draw(int frame, double opacity) {
      canvas.drawImageRect(
        atlas,
        Rect.fromLTWH((frame % 6) * w, (frame ~/ 6) * h, w, h * .5 / .54),
        Offset.zero & size,
        Paint()
          ..filterQuality = FilterQuality.low
          ..color = Colors.white.withValues(alpha: opacity),
      );
    }

    draw(at.floor(), 1);
    if (at.ceil() != at.floor()) draw(at.ceil(), at - at.floor());
  }

  @override
  bool shouldRepaint(_GoogleOrbitPainter old) =>
      old.atlas != atlas || old.progress != progress;
}
