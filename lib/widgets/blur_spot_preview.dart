import 'dart:math';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../model/media_edits.dart';

/// Source-space handles with finger-sized hit areas independent of blur radius.
class BlurSpotPreview extends StatefulWidget {
  final Size sourceSize;
  final Widget image;
  final List<BlurSpot> spots;
  final String? selected;
  final ValueChanged<BlurSpot> onSelect;
  final VoidCallback onChanged;
  const BlurSpotPreview({
    super.key,
    required this.sourceSize,
    required this.image,
    required this.spots,
    required this.selected,
    required this.onSelect,
    required this.onChanged,
  });
  @override
  State<BlurSpotPreview> createState() => _BlurSpotPreviewState();
}

class _BlurSpotPreviewState extends State<BlurSpotPreview> {
  final _image = GlobalKey();
  OverlayEntry? _magnifier;
  BlurSpot? _dragging;
  Offset _grabOffset = Offset.zero, _finger = Offset.zero;
  Size _fitted = Size.zero;

  void _endDrag() {
    _dragging = null;
    _magnifier?.remove();
    _magnifier?.dispose();
    _magnifier = null;
  }

  void _finish() {
    final changed = _dragging != null;
    setState(_endDrag);
    if (changed) widget.onChanged();
  }

  @override
  void dispose() {
    _endDrag();
    super.dispose();
  }

  @override
  void didUpdateWidget(BlurSpotPreview old) {
    super.didUpdateWidget(old);
    if (_dragging != null && !widget.spots.contains(_dragging)) _endDrag();
  }

  void _start(BlurSpot spot, Offset global) {
    _endDrag();
    final box = _image.currentContext!.findRenderObject()! as RenderBox;
    _grabOffset =
        Offset(spot.x * _fitted.width, spot.y * _fitted.height) -
        box.globalToLocal(global);
    _finger = global;
    _dragging = spot;
    setState(() {});
    widget.onSelect(spot);
    _magnifier = OverlayEntry(builder: _lens);
    Overlay.of(context, rootOverlay: true).insert(_magnifier!);
  }

  void _move(BlurSpot spot, Offset global) {
    final box = _image.currentContext!.findRenderObject()! as RenderBox;
    final point = box.globalToLocal(global) + _grabOffset;
    spot.x = (point.dx / _fitted.width).clamp(0, 1);
    spot.y = (point.dy / _fitted.height).clamp(0, 1);
    _finger = global;
    setState(() {});
    _magnifier?.markNeedsBuild();
  }

  Widget _lens(BuildContext context) {
    final spot = _dragging;
    final image = _image.currentContext?.findRenderObject() as RenderBox?;
    if (spot == null || image == null || !image.attached) {
      return const SizedBox();
    }
    final overlay =
        Overlay.of(this.context, rootOverlay: true).context.findRenderObject()!
            as RenderBox;
    final focal = overlay.globalToLocal(
      image.localToGlobal(
        Offset(spot.x * _fitted.width, spot.y * _fitted.height),
      ),
    );
    final finger = overlay.globalToLocal(_finger);
    const size = Size(124, 104);
    final media = MediaQuery.of(context);
    final left = (finger.dx - size.width / 2).clamp(
      8.0,
      max(8.0, overlay.size.width - size.width - 8),
    );
    final safeTop = media.padding.top + 8;
    var top = finger.dy - size.height - 54;
    if (top < safeTop) top = finger.dy + 54;
    top = top.clamp(
      safeTop,
      max(
        safeTop,
        overlay.size.height - media.viewInsets.bottom - size.height - 8,
      ),
    );
    return Positioned(
      left: left.toDouble(),
      top: top.toDouble(),
      child: IgnorePointer(
        child: Semantics(
          label: 'Blur placement magnifier',
          child: RawMagnifier(
            size: size,
            magnificationScale: 2,
            clipBehavior: Clip.antiAlias,
            focalPointOffset:
                focal - Offset(left + size.width / 2, top + size.height / 2),
            decoration: const MagnifierDecoration(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)),
                side: BorderSide(color: Color(0xffb1a6ff), width: 2),
              ),
              shadows: [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: const Center(
              child: Icon(Icons.add, size: 20, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      _fitted = applyBoxFit(
        BoxFit.contain,
        widget.sourceSize,
        bounds.biggest,
      ).destination;
      final origin = Offset(
        (bounds.maxWidth - _fitted.width) / 2,
        (bounds.maxHeight - _fitted.height) / 2,
      );
      return Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            left: origin.dx,
            top: origin.dy,
            width: _fitted.width,
            height: _fitted.height,
            child: SizedBox(key: _image, child: widget.image),
          ),
          // The selected handle wins where enlarged hit targets overlap.
          for (final spot in [
            ...widget.spots.where((s) => s.id != widget.selected),
            ...widget.spots.where((s) => s.id == widget.selected),
          ])
            _handle(spot, widget.spots.indexOf(spot), origin, bounds.biggest),
        ],
      );
    },
  );
  Widget _handle(BlurSpot spot, int index, Offset origin, Size area) {
    final radius = spot.radius * min(_fitted.width, _fitted.height);
    final center =
        origin + Offset(spot.x * _fitted.width, spot.y * _fitted.height);
    final width = min(area.width, max(64.0, radius * 2 + 24));
    final height = min(area.height, max(64.0, radius * 2 + 24));
    final left = (center.dx - width / 2).clamp(
      0.0,
      max(0.0, area.width - width),
    );
    final top = (center.dy - height / 2).clamp(
      0.0,
      max(0.0, area.height - height),
    );
    return Positioned(
      key: ValueKey(spot.id),
      left: left.toDouble(),
      top: top.toDouble(),
      width: width,
      height: height,
      child: Semantics(
        label: 'Blur spot ${index + 1}',
        selected: spot.id == widget.selected,
        child: GestureDetector(
          dragStartBehavior: DragStartBehavior.down,
          behavior: HitTestBehavior.opaque,
          onTap: () => widget.onSelect(spot),
          onPanStart: (e) => _start(spot, e.globalPosition),
          onPanUpdate: (e) => _move(spot, e.globalPosition),
          onPanEnd: (_) => _finish(),
          onPanCancel: _finish,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: center.dx - left - radius,
                top: center.dy - top - radius,
                width: radius * 2,
                height: radius * 2,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: .06),
                    border: Border.all(
                      color: spot.id == widget.selected
                          ? const Color(0xffb1a6ff)
                          : Colors.white,
                      width: 2,
                    ),
                  ),
                ),
              ),
              if (_dragging?.id != spot.id)
                Positioned(
                  left: center.dx - left - 10,
                  top: center.dy - top - 10,
                  child: const Icon(
                    Icons.open_with,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
