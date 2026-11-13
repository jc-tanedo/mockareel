import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import '../model/streetview_3d_camera.dart';

/// Paints the daytime sky dome and horizon haze behind the 3D corridor.
void paintStreetview3dSky(Canvas canvas, Size size, Camera3D camera) {
  final horizon = camera.project(const Vec3(0, 0, 200), size);
  final horizonY = (horizon?.dy ?? size.height * 0.42).clamp(
    0.0,
    size.height * 0.9,
  );
  final skyRect = Rect.fromLTWH(0, 0, size.width, horizonY + 40);
  final paint = Paint()
    ..shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xff3c84d8),
        Color(0xff7ab8f5),
        Color(0xffbfe0ff),
        Color(0xffeaf4ff),
      ],
      stops: [0.0, 0.42, 0.82, 1.0],
    ).createShader(skyRect);
  canvas.drawRect(skyRect, paint);
}

/// Projects a [ui.Image] onto a subdivided 3D street-corridor mesh using
/// [Canvas.drawVertices] and [Camera3D].
class Streetview3dCorridorPainter extends CustomPainter {
  final Camera3D camera;
  final ui.Image? outgoingImage;
  final ui.Image? incomingImage;
  final double incomingAlpha;
  final double incomingZOffset;
  final double incomingYawOffset;
  final ui.Image? mapImage;
  final double mapAlpha;

  const Streetview3dCorridorPainter({
    required this.camera,
    this.outgoingImage,
    this.incomingImage,
    this.incomingAlpha = 0,
    this.incomingZOffset = 18,
    this.incomingYawOffset = 0,
    this.mapImage,
    this.mapAlpha = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    paintStreetview3dSky(canvas, size, camera);

    if (mapImage != null && mapAlpha > 0.01) {
      _drawGroundMap(canvas, size, mapImage!, mapAlpha);
    }
    if (outgoingImage != null) {
      _drawCorridorMesh(
        canvas,
        size,
        outgoingImage!,
        alpha: 1.0,
        zOffset: 0,
        yawOffset: 0,
      );
    }
    if (incomingImage != null && incomingAlpha > 0.01) {
      _drawCorridorMesh(
        canvas,
        size,
        incomingImage!,
        alpha: incomingAlpha,
        zOffset: incomingZOffset,
        yawOffset: incomingYawOffset,
      );
    }
  }

  void _drawGroundMap(Canvas canvas, Size size, ui.Image image, double alpha) {
    const cols = 10;
    const rows = 10;
    const halfW = 36.0;
    const zMin = -32.0;
    const zMax = 44.0;
    final positions = <Offset>[];
    final texCoords = <Offset>[];
    final indices = <int>[];
    final w = image.width.toDouble();
    final h = image.height.toDouble();

    for (var r = 0; r <= rows; r++) {
      final v = r / rows;
      final z = ui.lerpDouble(zMax, zMin, v)!;
      for (var c = 0; c <= cols; c++) {
        final u = c / cols;
        final x = ui.lerpDouble(-halfW, halfW, u)!;
        final camPt = camera.toCameraSpace(Vec3(x, 0, z));
        positions.add(camera.projectCameraPoint(camPt, size));
        texCoords.add(Offset(u * w, v * h));
      }
    }
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final i0 = r * (cols + 1) + c;
        final i1 = i0 + 1;
        final i2 = i0 + cols + 1;
        final i3 = i2 + 1;
        indices.addAll([i0, i1, i2, i1, i3, i2]);
      }
    }
    _drawTexturedVertices(canvas, image, positions, texCoords, indices, alpha);
  }

  void _drawCorridorMesh(
    Canvas canvas,
    Size size,
    ui.Image image, {
    required double alpha,
    required double zOffset,
    required double yawOffset,
  }) {
    const cols = 14;
    const rows = 16;
    final w = image.width.toDouble();
    final h = image.height.toDouble();
    final positions = <Offset>[];
    final texCoords = <Offset>[];
    final camZ = <double>[];
    final indices = <int>[];

    final cosY = cos(yawOffset);
    final sinY = sin(yawOffset);

    for (var r = 0; r <= rows; r++) {
      final v = r / rows;
      for (var c = 0; c <= cols; c++) {
        final u = c / cols;
        var world = _corridorVertex(u, v);
        if (yawOffset != 0) {
          world = Vec3(
            world.x * cosY + world.z * sinY,
            world.y,
            -world.x * sinY + world.z * cosY,
          );
        }
        world = Vec3(world.x, world.y, world.z + zOffset);
        final cp = camera.toCameraSpace(world);
        camZ.add(cp.z);
        positions.add(camera.projectCameraPoint(cp, size));
        texCoords.add(Offset(u * w, v * h));
      }
    }

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final i0 = r * (cols + 1) + c;
        final i1 = i0 + 1;
        final i2 = i0 + cols + 1;
        final i3 = i2 + 1;
        if (camZ[i0] > camera.nearPlane ||
            camZ[i1] > camera.nearPlane ||
            camZ[i2] > camera.nearPlane) {
          indices.addAll([i0, i1, i2]);
        }
        if (camZ[i1] > camera.nearPlane ||
            camZ[i3] > camera.nearPlane ||
            camZ[i2] > camera.nearPlane) {
          indices.addAll([i1, i3, i2]);
        }
      }
    }

    if (indices.isEmpty) return;
    _drawTexturedVertices(canvas, image, positions, texCoords, indices, alpha);
  }

  /// Maps normalized UV (0..1, 0..1) of a 9:16 clip onto a 3D street corridor:
  /// - Lower half (v >= 0.52): 3D asphalt ground plane (Y = 0)
  /// - Left/right edges (u < 0.22 or u > 0.78): curved 3D corridor walls
  /// - Upper center: curved far horizon dome
  Vec3 _corridorVertex(double u, double v) {
    const roadHalfW = 8.5;
    if (v >= 0.52) {
      final groundT = (v - 0.52) / 0.48; // 0 at horizon, 1 at foreground
      final z = ui.lerpDouble(35.0, 1.2, pow(groundT, 0.85).toDouble())!;
      final x = (u - 0.5) * 2.0 * roadHalfW;
      return Vec3(x, 0.0, z);
    }

    final wallV = 1.0 - (v / 0.52); // 0 at horizon, 1 at top of frame
    final y = wallV * 13.5;
    final edgeDist = (u - 0.5).abs() * 2.0; // 0 at center, 1 at outer edge
    if (edgeDist > 0.44) {
      final sideT = ((edgeDist - 0.44) / 0.56).clamp(0.0, 1.0);
      final x = (u < 0.5 ? -1.0 : 1.0) * roadHalfW;
      final z = ui.lerpDouble(35.0, 2.0, sideT)!;
      return Vec3(x, y, z);
    }

    final centerX = (u - 0.5) * 2.0 * roadHalfW;
    final domeZ = 35.0 + (1.0 - edgeDist / 0.44) * 3.0;
    return Vec3(centerX, y, domeZ);
  }

  void _drawTexturedVertices(
    Canvas canvas,
    ui.Image image,
    List<Offset> positions,
    List<Offset> texCoords,
    List<int> indices,
    double alpha,
  ) {
    final vertices = ui.Vertices(
      ui.VertexMode.triangles,
      positions,
      textureCoordinates: texCoords,
      indices: Uint16List.fromList(indices),
    );
    final paint = Paint()
      ..shader = ImageShader(
        image,
        TileMode.clamp,
        TileMode.clamp,
        Matrix4.identity().storage,
      )
      ..filterQuality = FilterQuality.medium
      ..color = Color.fromRGBO(255, 255, 255, alpha.clamp(0.0, 1.0));
    canvas.drawVertices(vertices, BlendMode.srcOver, paint);
  }

  @override
  bool shouldRepaint(Streetview3dCorridorPainter oldDelegate) =>
      camera.pos != oldDelegate.camera.pos ||
      camera.pitch != oldDelegate.camera.pitch ||
      camera.yaw != oldDelegate.camera.yaw ||
      camera.fovY != oldDelegate.camera.fovY ||
      outgoingImage != oldDelegate.outgoingImage ||
      incomingImage != oldDelegate.incomingImage ||
      incomingAlpha != oldDelegate.incomingAlpha ||
      mapImage != oldDelegate.mapImage ||
      mapAlpha != oldDelegate.mapAlpha;
}
