import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:mockareel/model/project.dart';
import 'package:mockareel/model/streetview_motion.dart';
import 'package:mockareel/widgets/streetview_camera.dart';

class PhotoWalkFrame extends StatelessWidget {
  final ReelClip clip;
  final double seconds;
  const PhotoWalkFrame({super.key, required this.clip, required this.seconds});
  // Translate the camera in a pinhole projection. Near surfaces have greater
  // disparity. On a side step the camera turns slightly toward the subject.
  static StreetviewPose pose(
    ReelClip clip,
    double seconds,
    int layer, {
    bool overscan = true,
  }) {
    final t = StreetviewMotion.sample(seconds, clip.duration) / clip.duration;
    final inverseDepth = (layer + 1) / 3;
    if (clip.streetview.walkMove == 'forward') {
      return StreetviewPose(1 / (1 - .18 * t * inverseDepth), 0, 0);
    }
    final travel = (clip.streetview.walkMove == 'left' ? 1 : -1) * t;
    return StreetviewPose(
      overscan ? 1.20 : 1,
      -.09 * travel,
      24 * travel * inverseDepth,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          for (var i = 0; i < 3; i++)
            StreetviewCameraTransform(
              pose: pose(clip, seconds, i),
              child: Transform.scale(
                scale: clip.zoom,
                alignment: Alignment(clip.panX, 0),
                child: Image.file(
                  File(clip.streetview.walkLayers[i]),
                  fit: BoxFit.cover,
                  alignment: Alignment(clip.panX, 0),
                  gaplessPlayback: true,
                  excludeFromSemantics: true,
                  frameBuilder: (context, child, frame, synchronous) {
                    if (child is! RawImage ||
                        child.image == null ||
                        clip.streetview.walkDepth.length != 1024) {
                      return child;
                    }
                    return CustomPaint(
                      painter: _DepthSurface(
                        child.image!,
                        clip.streetview.walkDepth,
                        clip.panX,
                        clip.streetview.walkMove,
                        StreetviewMotion.sample(seconds, clip.duration) /
                            clip.duration,
                        i,
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Project a textured relief mesh inside each filled layer. The parent already
/// applies the layer's reference depth, yaw and framing.
class _DepthSurface extends CustomPainter {
  final ui.Image image;
  final List<int> depth;
  final double pan, time;
  final String move;
  final int layer;
  _DepthSurface(
    this.image,
    this.depth,
    this.pan,
    this.move,
    this.time,
    this.layer,
  );

  static const cells = 31;
  static final indices = <int>[
    for (int y = 0; y < cells; y++)
      for (int x = 0; x < cells; x++) ...[
        y * 32 + x,
        y * 32 + x + 1,
        (y + 1) * 32 + x,
        y * 32 + x + 1,
        (y + 1) * 32 + x + 1,
        (y + 1) * 32 + x,
      ],
  ];

  double depthAt(double u, double v) {
    final x = (u * cells).clamp(0.0, 30.99999),
        y = (v * cells).clamp(0.0, 30.99999);
    final i = y.floor() * 32 + x.floor(), a = x - x.floor(), b = y - y.floor();
    return (((depth[i] * (1 - a) + depth[i + 1] * a) * (1 - b) +
                (depth[i + 32] * (1 - a) + depth[i + 33] * a) * b) /
            255)
        .clamp(layer / 3, (layer + 1) / 3);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final pixels = Size(image.width.toDouble(), image.height.toDouble());
    final source = Alignment(pan, 0).inscribe(
      applyBoxFit(BoxFit.cover, pixels, size).source,
      Offset.zero & pixels,
    );
    final center = size.center(Offset.zero);
    final points = <Offset>[], uv = <Offset>[];
    final reference = (layer + 1) / 3;
    for (int y = 0; y <= cells; y++) {
      for (int x = 0; x <= cells; x++) {
        final u = x / cells, v = y / cells;
        final texture = Offset(
          source.left + u * source.width,
          source.top + v * source.height,
        );
        uv.add(texture);
        final inverseDepth = depthAt(
          texture.dx / pixels.width,
          texture.dy / pixels.height,
        );
        final position = Offset(u * size.width, v * size.height);
        if (move == 'forward') {
          points.add(
            center +
                (position - center) *
                    ((1 - .18 * time * reference) /
                        (1 - .18 * time * inverseDepth)),
          );
        } else {
          final delta =
              (move == 'left' ? 1 : -1) *
              24 *
              time *
              (inverseDepth - reference) /
              1.20;
          points.add(position + Offset(delta, 0));
        }
      }
    }
    final mesh = ui.Vertices(
      ui.VertexMode.triangles,
      points,
      textureCoordinates: uv,
      indices: indices,
    );
    final shader = ui.ImageShader(
      image,
      TileMode.clamp,
      TileMode.clamp,
      Matrix4.identity().storage,
      filterQuality: FilterQuality.low,
    );
    canvas.drawVertices(mesh, BlendMode.srcOver, Paint()..shader = shader);
    shader.dispose();
    mesh.dispose();
  }

  @override
  bool shouldRepaint(_DepthSurface old) =>
      old.image != image ||
      old.depth != depth ||
      old.time != time ||
      old.move != move ||
      old.layer != layer ||
      old.pan != pan;
}
