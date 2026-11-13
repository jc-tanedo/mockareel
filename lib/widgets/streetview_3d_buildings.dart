import 'dart:math';

import 'package:flutter/material.dart';
import '../model/streetview_3d_camera.dart';

/// A deterministic 3D building block flanking the street corridor.
class BuildingBlock3D {
  final double x, z, width, depth, height;
  const BuildingBlock3D({
    required this.x,
    required this.z,
    required this.width,
    required this.depth,
    required this.height,
  });

  /// Generates low-poly building blocks along both sides of the corridor.
  static List<BuildingBlock3D> generate(String seedText) {
    final rng = Random(seedText.hashCode ^ 0x5f3759df);
    final blocks = <BuildingBlock3D>[];
    for (final side in [-1.0, 1.0]) {
      var z = -4.0;
      while (z < 42.0) {
        final depth = 4.5 + rng.nextDouble() * 5.0;
        final width = 4.0 + rng.nextDouble() * 4.5;
        final height = 6.0 + rng.nextDouble() * 12.0;
        final setback = 6.0 + rng.nextDouble() * 2.5;
        blocks.add(
          BuildingBlock3D(
            x: side * (setback + width * 0.5),
            z: z + depth * 0.5,
            width: width,
            depth: depth,
            height: height,
          ),
        );
        z += depth + 1.4 + rng.nextDouble() * 2.0;
      }
    }
    return blocks;
  }
}

/// Paints translucent 3D building massing projected through [Camera3D].
class Streetview3dBuildingsPainter extends CustomPainter {
  final Camera3D camera;
  final List<BuildingBlock3D> blocks;
  final double opacity;
  final double heightScale;
  final bool dark;

  const Streetview3dBuildingsPainter({
    required this.camera,
    required this.blocks,
    required this.opacity,
    this.heightScale = 1.0,
    this.dark = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0.01 || heightScale <= 0.01) return;

    final sorted = [...blocks]
      ..sort((a, b) {
        final da = (Vec3(a.x, 0, a.z) - camera.pos).length;
        final db = (Vec3(b.x, 0, b.z) - camera.pos).length;
        return db.compareTo(da);
      });

    final roofColor = (dark ? const Color(0xff384356) : const Color(0xffe6e9ef))
        .withValues(alpha: opacity * 0.85);
    final sideColor = (dark ? const Color(0xff2a3342) : const Color(0xffcfd5df))
        .withValues(alpha: opacity * 0.85);
    final frontColor =
        (dark ? const Color(0xff202835) : const Color(0xffbcc3cf)).withValues(
          alpha: opacity * 0.85,
        );
    final edgePaint = Paint()
      ..color = (dark ? Colors.white : Colors.black).withValues(
        alpha: opacity * 0.14,
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    for (final b in sorted) {
      final h = b.height * heightScale;
      final x0 = b.x - b.width * 0.5;
      final x1 = b.x + b.width * 0.5;
      final z0 = b.z - b.depth * 0.5;
      final z1 = b.z + b.depth * 0.5;

      // Project 8 corners (skip if all behind near plane)
      final p000 = camera.project(Vec3(x0, 0, z0), size);
      final p100 = camera.project(Vec3(x1, 0, z0), size);
      final p101 = camera.project(Vec3(x1, 0, z1), size);
      final p001 = camera.project(Vec3(x0, 0, z1), size);
      final p010 = camera.project(Vec3(x0, h, z0), size);
      final p110 = camera.project(Vec3(x1, h, z0), size);
      final p111 = camera.project(Vec3(x1, h, z1), size);
      final p011 = camera.project(Vec3(x0, h, z1), size);

      void drawQuad(Offset? a, Offset? bPt, Offset? c, Offset? d, Color color) {
        if (a == null || bPt == null || c == null || d == null) return;
        final path = Path()
          ..moveTo(a.dx, a.dy)
          ..lineTo(bPt.dx, bPt.dy)
          ..lineTo(c.dx, c.dy)
          ..lineTo(d.dx, d.dy)
          ..close();
        canvas.drawPath(path, Paint()..color = color);
        canvas.drawPath(path, edgePaint);
      }

      // Street-facing wall
      if (b.x < camera.pos.x) {
        drawQuad(p100, p101, p111, p110, sideColor);
      } else {
        drawQuad(p000, p001, p011, p010, sideColor);
      }
      // Front-facing wall (facing camera)
      if (z0 > camera.pos.z) {
        drawQuad(p000, p100, p110, p010, frontColor);
      } else if (z1 < camera.pos.z) {
        drawQuad(p001, p101, p111, p011, frontColor);
      }
      // Roof
      if (camera.pos.y > h || camera.pitch < -0.15) {
        drawQuad(p010, p110, p111, p011, roofColor);
      }
    }
  }

  @override
  bool shouldRepaint(Streetview3dBuildingsPainter oldDelegate) =>
      camera.pos != oldDelegate.camera.pos ||
      camera.pitch != oldDelegate.camera.pitch ||
      camera.yaw != oldDelegate.camera.yaw ||
      opacity != oldDelegate.opacity ||
      heightScale != oldDelegate.heightScale ||
      dark != oldDelegate.dark;
}
