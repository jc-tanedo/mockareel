import 'dart:math';
import 'package:flutter/material.dart';
import '../model/orbit_media_pose.dart';
import '../model/orbit_scene.dart';
import 'orbit_map.dart';

/// North-up orthographic projection for interactive wall selection.
class OrbitWallPickerLayout {
  final OrbitScene scene;
  final Size size;
  final Offset worldCenter;
  final double scale;
  final List<OrbitWallMount> walls;

  OrbitWallPickerLayout._(
    this.scene,
    this.size,
    this.worldCenter,
    this.scale,
    this.walls,
  );

  factory OrbitWallPickerLayout.fit(OrbitScene scene, Size size) {
    final walls = scene.walls.values.toList(growable: false);
    var minX = -60.0, maxX = 60.0, minY = -60.0, maxY = 60.0;
    void include(Offset p) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }

    for (final w in walls) {
      final halfW = OrbitWallMount.defaultWidth * w.sizeFactor * .5;
      include(w.center - w.tangent * halfW + w.normal * 16);
      include(w.center + w.tangent * halfW + w.normal * 16);
    }
    const pad = 28.0;
    final rawSpan = max(maxX - minX + pad * 2, maxY - minY + pad * 2);
    final span = rawSpan.clamp(160.0, 480.0);
    final center = Offset((minX + maxX) / 2, (minY + maxY) / 2);
    final scale = min(size.width, size.height) / span;
    return OrbitWallPickerLayout._(scene, size, center, scale, walls);
  }

  Offset project(Offset world) => Offset(
    size.width / 2 + (world.dx - worldCenter.dx) * scale,
    size.height / 2 + (world.dy - worldCenter.dy) * scale,
  );

  (Offset, Offset) segment(OrbitWallMount wall) {
    final half = OrbitWallMount.defaultWidth * wall.sizeFactor * .5;
    return (
      project(wall.center - wall.tangent * half),
      project(wall.center + wall.tangent * half),
    );
  }

  Offset badgeCenter(OrbitWallMount wall) {
    final raw = project(wall.center) + wall.normal * 14.0;
    return Offset(
      raw.dx.clamp(14.0, max(14.0, size.width - 14.0)),
      raw.dy.clamp(14.0, max(14.0, size.height - 14.0)),
    );
  }

  String? hitTest(Offset tap, {double maxDistance = 30}) {
    String? bestId;
    var best = maxDistance;
    for (final wall in walls) {
      final dBadge = (tap - badgeCenter(wall)).distance;
      final (a, b) = segment(wall);
      final dSeg = _pointToSegmentDistance(tap, a, b);
      final d = min(dBadge, dSeg);
      if (d <= best) {
        best = d;
        bestId = wall.id;
      }
    }
    return bestId;
  }

  static double _pointToSegmentDistance(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final lenSq = ab.distanceSquared;
    if (lenSq <= 1e-6) return (p - a).distance;
    final t = ((p - a).dx * ab.dx + (p - a).dy * ab.dy) / lenSq;
    final clamped = a + ab * t.clamp(0.0, 1.0);
    return (p - clamped).distance;
  }
}

Future<void> showOrbitWallPicker({
  required BuildContext context,
  required OrbitScene scene,
  required String? selectedWallId,
  required Map<String, int> siblingWalls,
  required bool dark,
  required ValueChanged<String> onSelected,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => OrbitWallPickerSheet(
    scene: scene,
    selectedWallId: selectedWallId,
    siblingWalls: siblingWalls,
    dark: dark,
    onSelected: onSelected,
  ),
);

class OrbitWallPickerSheet extends StatefulWidget {
  final OrbitScene scene;
  final String? selectedWallId;
  final Map<String, int> siblingWalls;
  final bool dark;
  final ValueChanged<String> onSelected;
  const OrbitWallPickerSheet({
    super.key,
    required this.scene,
    required this.selectedWallId,
    required this.siblingWalls,
    required this.dark,
    required this.onSelected,
  });

  @override
  State<OrbitWallPickerSheet> createState() => _OrbitWallPickerSheetState();
}

class _OrbitWallPickerSheetState extends State<OrbitWallPickerSheet> {
  late String? _currentId =
      widget.scene.wallFor(widget.selectedWallId)?.id ??
      widget.scene.wallMount?.id;
  late final Map<String, int> _siblings = Map.of(widget.siblingWalls);

  void _pick(String wallId) {
    if (wallId == _currentId) return;
    final previous = _currentId;
    setState(() {
      final displaced = _siblings.remove(wallId);
      if (displaced != null &&
          previous != null &&
          widget.scene.walls.length >= 2 &&
          widget.scene.walls.containsKey(previous)) {
        _siblings[previous] = displaced;
      }
      _currentId = wallId;
    });
    widget.onSelected(wallId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final walls = widget.scene.walls.values.toList(growable: false);
    final currentWall = _currentId;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pick building wall',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.scene.describeWall(currentWall),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.tonal(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 140,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(
                    color: widget.dark
                        ? const Color(0xff233747)
                        : const Color(0xffcad9cf),
                  ),
                  OrbitMapView(
                    scene: widget.scene,
                    failed: false,
                    camera: OrbitMediaPose.at(
                      'media',
                      .65,
                      scene: widget.scene,
                      wallId: currentWall,
                    ),
                    dark: widget.dark,
                    zoom: OrbitMediaPose.at(
                      'media',
                      .65,
                      scene: widget.scene,
                      wallId: currentWall,
                    ).zoom,
                  ),
                  Positioned(
                    left: 10,
                    top: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Wall camera preview',
                        style: TextStyle(fontSize: 11, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 200,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final layout = OrbitWallPickerLayout.fit(
                    widget.scene,
                    Size(constraints.maxWidth, constraints.maxHeight),
                  );
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (details) {
                      final hit = layout.hitTest(details.localPosition);
                      if (hit != null) _pick(hit);
                    },
                    child: CustomPaint(
                      painter: _WallPickerPainter(
                        layout: layout,
                        selectedWallId: currentWall,
                        siblingWalls: _siblings,
                        dark: widget.dark,
                        primaryColor: colors.primary,
                        onPrimaryColor: colors.onPrimary,
                        siblingColor: colors.tertiaryContainer,
                        onSiblingColor: colors.onTertiaryContainer,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: walls.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final wall = walls[index];
                final sibling = _siblings[wall.id];
                final selected = wall.id == currentWall;
                return ChoiceChip(
                  selected: selected,
                  label: Text(
                    sibling == null
                        ? 'Wall ${index + 1}'
                        : 'Wall ${index + 1} · Clip $sibling',
                  ),
                  onSelected: (_) => _pick(wall.id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _WallPickerPainter extends CustomPainter {
  final OrbitWallPickerLayout layout;
  final String? selectedWallId;
  final Map<String, int> siblingWalls;
  final bool dark;
  final Color primaryColor, onPrimaryColor, siblingColor, onSiblingColor;

  _WallPickerPainter({
    required this.layout,
    required this.selectedWallId,
    required this.siblingWalls,
    required this.dark,
    required this.primaryColor,
    required this.onPrimaryColor,
    required this.siblingColor,
    required this.onSiblingColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scene = layout.scene;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawColor(
      dark ? const Color(0xff1e2d3b) : const Color(0xffe9ebe4),
      BlendMode.src,
    );
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(layout.scale);
    canvas.translate(-layout.worldCenter.dx, -layout.worldCenter.dy);
    final visible = canvas.getLocalClipBounds();
    final brush = Paint();
    for (final buildings in [false, true]) {
      for (final feature in scene.shapes) {
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
            : (dark ? const Color(0xff425263) : Colors.white);
        canvas.drawPath(feature.outline, brush);
      }
    }
    canvas.restore();

    final pin = layout.project(Offset.zero);
    canvas.drawCircle(pin, 5.5, Paint()..color = Colors.white);
    canvas.drawCircle(pin, 3.8, Paint()..color = Colors.red);

    for (var i = 0; i < layout.walls.length; i++) {
      final wall = layout.walls[i];
      final selected = wall.id == selectedWallId;
      final siblingClip = siblingWalls[wall.id];
      final (a, b) = layout.segment(wall);
      final center = layout.project(wall.center);
      final badge = layout.badgeCenter(wall);
      final lineColor = selected
          ? primaryColor
          : siblingClip != null
          ? siblingColor
          : (dark ? Colors.white70 : const Color(0xff355064));

      canvas.drawLine(
        a,
        b,
        Paint()
          ..color = lineColor
          ..strokeWidth = selected ? 5.0 : 3.2
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawLine(
        center,
        badge,
        Paint()
          ..color = lineColor.withValues(alpha: .75)
          ..strokeWidth = 1.6,
      );
      final bg = selected
          ? primaryColor
          : siblingClip != null
          ? siblingColor
          : (dark ? const Color(0xff293949) : Colors.white);
      final fg = selected
          ? onPrimaryColor
          : siblingClip != null
          ? onSiblingColor
          : (dark ? Colors.white : Colors.black87);
      final radius = selected ? 12.0 : 10.5;
      if (selected) {
        canvas.drawCircle(
          badge,
          radius + 3.5,
          Paint()..color = primaryColor.withValues(alpha: .28),
        );
      }
      canvas.drawCircle(badge, radius, Paint()..color = bg);
      canvas.drawCircle(
        badge,
        radius,
        Paint()
          ..color = selected ? Colors.white : lineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = selected ? 1.8 : 1.1,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: siblingClip != null ? '${i + 1}·C$siblingClip' : '${i + 1}',
          style: TextStyle(
            color: fg,
            fontSize: siblingClip != null ? 8.5 : 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, badge - Offset(tp.width / 2, tp.height / 2));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WallPickerPainter old) =>
      old.layout.scene != layout.scene ||
      old.selectedWallId != selectedWallId ||
      old.dark != dark ||
      old.primaryColor != primaryColor;
}
