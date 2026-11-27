import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../data/orbit_scene_loader.dart';
import '../model/orbit_media_pose.dart';
import '../model/orbit_scene.dart';

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
      widget.path == null ? null : OrbitSceneLoader.load(widget.path!);
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
          : OrbitSceneLoader.cached(widget.path!) ??
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
            image: MemoryImage(atlas),
            excludeFromSemantics: true,
            frameBuilder: (context, child, frame, sync) {
              if (child is! RawImage || child.image == null) return child;
              return CustomPaint(
                painter: _GoogleOrbitPainter(child.image!, camera),
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
    final horizon = dark ? const Color(0xff233747) : const Color(0xffcad9cf);
    const sunDir = Offset(0.79, 0.61);
    double hazeAt(Offset world) =>
        (((world - camera.focus).distance - 180.0) / 360.0).clamp(0.0, 0.62);

    if (!foregroundOnly) {
      canvas.drawColor(land, BlendMode.src);
      for (var z = 0; z < 24; z++) {
        for (var x = 0; x < 24; x++) {
          final p = Offset(x * 50.0 - 600, z * 50.0 - 600), i = z * 25 + x;
          final heights = scene.grid;
          final cellColor = Color.lerp(
            land,
            Colors.black,
            ((heights[i + 1] - heights[i]) / 90 + .08).clamp(0, 0.35),
          )!;
          face([
            project(p, heights[i]),
            project(p + const Offset(50, 0), heights[i + 1]),
            project(p + const Offset(50, 50), heights[i + 26]),
            project(p + const Offset(0, 50), heights[i + 25]),
          ], Color.lerp(cellColor, horizon, hazeAt(p + const Offset(25, 25)))!);
        }
      }
    }
    final buildings = <OrbitFootprint>[];
    for (final f in scene.shapes) {
      if (f.height >= 0) {
        if (!foregroundOnly || camera.inFrontOfPanel(f)) {
          buildings.add(f);
        }
        continue;
      }
      if (foregroundOnly) continue;
      final baseFeature = f.height == -3
          ? (dark ? const Color(0xff385772) : Colors.blueGrey)
          : f.height == -2
          ? (dark ? const Color(0xff3e614e) : const Color(0xff608568))
          : dark
          ? const Color(0xff556572)
          : const Color(0xffe1dfd4);
      face([
        for (final p in f.points) project(p, scene.elevation(p)),
      ], Color.lerp(baseFeature, horizon, hazeAt(f.center))!);
    }
    buildings.sort((a, b) => depth(a.center).compareTo(depth(b.center)));
    if (!foregroundOnly) {
      for (final b in buildings) {
        if (b.height < 4) continue;
        final haze = hazeAt(b.center);
        if (haze >= 0.58) continue;
        final shadowLen = min(b.height * 0.42, 32.0);
        final base = scene.elevation(b.center);
        final shadowPoly = [
          for (final p in b.points) project(p + sunDir * shadowLen, base),
        ];
        final shadowPath = Path()..addPolygon(shadowPoly, true);
        if (shadowPath.getBounds().overlaps(clipBounds)) {
          canvas.drawPath(
            shadowPath,
            brush
              ..color = Colors.black.withValues(
                alpha: (dark ? 0.22 : 0.13) * (1 - haze),
              ),
          );
        }
      }
      if (camera.mount case final mount?) {
        final halfW = OrbitWallMount.defaultWidth * mount.sizeFactor * 0.5;
        final base = scene.elevation(mount.center) + mount.baseAbovePin;
        final a0 = mount.center - mount.tangent * halfW;
        final b0 = mount.center + mount.tangent * halfW;
        final reach = sunDir * 4.5 + mount.normal * 3.0;
        final contact = [
          project(a0, base),
          project(b0, base),
          project(b0 + reach, base),
          project(a0 + reach, base),
        ];
        face(contact, Colors.black.withValues(alpha: dark ? 0.26 : 0.16));
      }
    }
    final bandPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.05
      ..strokeCap = StrokeCap.butt;
    final roofEdgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;
    for (final b in buildings) {
      final base = scene.elevation(b.center),
          haze = hazeAt(b.center),
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
      final wallColor = b.color(roof: false, dark: dark);
      for (final i in sides) {
        final j = (i + 1) % top.length;
        final edge = b.points[j] - b.points[i];
        final len = max(1e-6, edge.distance);
        final lit = (edge.dx * sunDir.dx + edge.dy * sunDir.dy) / len;
        final shadedWall = Color.lerp(
          wallColor,
          const Color(0xff172431),
          (.21 - .15 * lit).clamp(0.05, 0.36),
        )!;
        final visibleWall = Color.lerp(shadedWall, horizon, haze)!;
        final quad = [bottom[i], bottom[j], top[j], top[i]];
        face(quad, visibleWall);
        if (b.height >= 12 && haze < 0.45) {
          final spanW = (bottom[j] - bottom[i]).distance;
          final spanH = (bottom[i] - top[i]).distance;
          if (spanW >= 18 && spanH >= 18) {
            final floors = min(8, ((b.height - 4.0) / 5.0).floor());
            if (floors >= 1) {
              // Opaque lerp + clip inside the wall quad ensures pixel-identical
              // results between foregroundOnly and base renders.
              bandPaint.color = Color.lerp(
                visibleWall,
                dark ? const Color(0xffb5d8f0) : const Color(0xff1b2c3b),
                (dark ? 0.14 : 0.11) * (1 - haze),
              )!;
              for (var k = 1; k <= floors; k++) {
                final frac = (3.5 + (k - 1) * 4.5) / b.height;
                if (frac >= 0.86) break;
                final pL = Offset.lerp(bottom[i], top[i], frac)!;
                final pR = Offset.lerp(bottom[j], top[j], frac)!;
                canvas.drawLine(
                  Offset.lerp(pL, pR, 0.14)!,
                  Offset.lerp(pL, pR, 0.86)!,
                  bandPaint,
                );
              }
            }
          }
        }
      }
      final roofFill = Color.lerp(
        b.color(roof: true, dark: dark),
        horizon,
        haze,
      )!;
      final roofPath = Path()..addPolygon(top, true);
      if (roofPath.getBounds().overlaps(clipBounds)) {
        canvas.drawPath(roofPath, brush..color = roofFill);
        if (haze < 0.52) {
          canvas.save();
          canvas.clipPath(roofPath);
          canvas.drawPath(
            roofPath,
            roofEdgePaint
              ..color = Color.lerp(
                roofFill,
                dark ? const Color(0xffcfe6f7) : Colors.white,
                (dark ? 0.18 : 0.28) * (1 - haze),
              )!,
          );
          canvas.restore();
        }
      }
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
      camera.mount != old.camera.mount ||
      camera.turn != old.camera.turn ||
      camera.tilt != old.camera.tilt ||
      camera.focus != old.camera.focus ||
      camera.lift != old.camera.lift ||
      dark != old.dark ||
      zoom != old.zoom;
}

class _GoogleOrbitPainter extends CustomPainter {
  final ui.Image atlas;
  final OrbitMediaPose camera;
  _GoogleOrbitPainter(this.atlas, this.camera);
  @override
  void paint(Canvas canvas, Size size) {
    final at = camera.progress.clamp(0.0, 1.0) * 23;
    final w = atlas.width / 6, h = atlas.height / 4;
    final viewport = Offset.zero & size;
    var dest = viewport;
    canvas.save();
    canvas.clipRect(viewport);
    if (camera.focus != Offset.zero ||
        camera.lift != 0 ||
        camera.turn != 0 ||
        camera.distanceScale != 1 ||
        camera.tilt != 0) {
      // The atlas has images only. Pan the captured frame with the camera
      // and overscan just enough to keep its edges outside the viewport.
      final transform = camera.groundFrom(OrbitMediaPose(camera.progress));
      final source = MatrixUtils.transformRect(
        Matrix4.inverted(transform),
        viewport,
      );
      final halfWidth = max(
        (source.left - viewport.center.dx).abs(),
        (source.right - viewport.center.dx).abs(),
      );
      final halfHeight = max(
        (source.top - viewport.center.dy).abs(),
        (source.bottom - viewport.center.dy).abs(),
      );
      final cover = max(
        1.0,
        max(2 * halfWidth / size.width, 2 * halfHeight / size.height),
      );
      dest = Rect.fromCenter(
        center: viewport.center,
        width: size.width * cover,
        height: size.height * cover,
      );
      canvas.transform(transform.storage);
    }
    void draw(int frame, double opacity) {
      canvas.drawImageRect(
        atlas,
        Rect.fromLTWH((frame % 6) * w, (frame ~/ 6) * h, w, h * .5 / .54),
        dest,
        Paint()
          ..filterQuality = FilterQuality.low
          ..color = Colors.white.withValues(alpha: opacity),
      );
    }

    draw(at.floor(), 1);
    if (at.ceil() != at.floor()) draw(at.ceil(), at - at.floor());
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GoogleOrbitPainter old) =>
      old.atlas != atlas || old.camera != camera;
}

/// North-up plan view of the saved vector capture for offline Maps scenes.
class OrbitPlanMap extends StatelessWidget {
  final OrbitScene? scene;
  final bool dark;
  final String name;
  const OrbitPlanMap({
    super.key,
    required this.scene,
    required this.dark,
    required this.name,
  });
  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      CustomPaint(painter: _PlanPainter(scene, dark)),
      Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_on, size: 30, color: Color(0xffe64a39)),
            if (name.isNotEmpty)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: dark ? Colors.black87 : Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: dark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      if (scene != null && scene!.atlas == null)
        Align(
          alignment: Alignment.bottomCenter,
          child: ColoredBox(
            color: Colors.black87,
            child: Text(
              scene!.credit,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 8, color: Colors.white),
            ),
          ),
        ),
    ],
  );
}

class _PlanPainter extends CustomPainter {
  final OrbitScene? scene;
  final bool dark;
  _PlanPainter(this.scene, this.dark);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawColor(
      dark ? const Color(0xff233448) : const Color(0xffe9ebe4),
      BlendMode.src,
    );
    canvas.translate(size.width / 2, size.height / 2);
    final scale = size.width / 500;
    canvas.scale(scale);
    final visible = canvas.getLocalClipBounds(), brush = Paint();
    for (final buildings in [false, true]) {
      for (final feature in scene?.shapes ?? const <OrbitFootprint>[]) {
        if ((feature.height > 0) != buildings ||
            !feature.bounds.overlaps(visible)) {
          continue;
        }
        brush.color = feature.height == -3
            ? (dark ? const Color(0xff122b49) : const Color(0xffa6cfee))
            : feature.height == -2
            ? (dark ? const Color(0xff284942) : const Color(0xffb2d5aa))
            : buildings
            ? feature.color(roof: true, dark: dark)
            : (dark ? const Color(0xff526070) : Colors.white);
        canvas.drawPath(feature.outline, brush);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PlanPainter old) =>
      old.scene != scene || old.dark != dark;
}
