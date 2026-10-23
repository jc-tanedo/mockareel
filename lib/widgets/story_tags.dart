import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../model/project.dart';

class StoryTagLayer extends StatefulWidget {
  final List<StoryTag> tags;
  final String? selectedId;
  final ValueChanged<StoryTag>? onSelect;
  final VoidCallback? onChanged;
  const StoryTagLayer({
    super.key,
    required this.tags,
    this.selectedId,
    this.onSelect,
    this.onChanged,
  });
  @override
  State<StoryTagLayer> createState() => _StoryTagLayerState();
}

class _StoryTagLayerState extends State<StoryTagLayer> {
  List<StoryTag> get tags => widget.tags;
  String? get selectedId => widget.selectedId;
  ValueChanged<StoryTag>? get onSelect => widget.onSelect;
  VoidCallback? get onChanged => widget.onChanged;
  Offset _grab = Offset.zero;
  void _begin(BuildContext context, StoryTag tag, DragStartDetails d) {
    final box = context.findRenderObject()! as RenderBox;
    _grab =
        box.globalToLocal(d.globalPosition) - Offset(tag.x * 360, tag.y * 640);
    onSelect?.call(tag);
  }

  void _move(BuildContext context, StoryTag tag, DragUpdateDetails d) {
    final box = context.findRenderObject()! as RenderBox;
    final point = box.globalToLocal(d.globalPosition) - _grab;
    tag.x = point.dx / 360;
    tag.y = point.dy / 640;
    tag.normalize();
    onChanged!();
  }

  @override
  Widget build(BuildContext context) => SizedBox.expand(
    child: Builder(
      builder: (canvasContext) => Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          for (final tag in tags)
            Positioned.fill(
              child: CustomSingleChildLayout(
                delegate: _TagPosition(tag.x, tag.y),
                child: Transform.rotate(
                  angle: tag.rotation,
                  child: GestureDetector(
                    dragStartBehavior: DragStartBehavior.down,
                    onTap: onSelect == null ? null : () => onSelect!(tag),
                    onHorizontalDragStart: onChanged == null
                        ? null
                        : (d) => _begin(canvasContext, tag, d),
                    onVerticalDragStart: onChanged == null
                        ? null
                        : (d) => _begin(canvasContext, tag, d),
                    onHorizontalDragUpdate: onChanged == null
                        ? null
                        : (d) => _move(canvasContext, tag, d),
                    onVerticalDragUpdate: onChanged == null
                        ? null
                        : (d) => _move(canvasContext, tag, d),
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 300),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: tag.style == 'badge'
                            ? Colors.black
                            : tag.style == 'highlight'
                            ? const Color(0xffffe36e)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(
                          tag.style == 'highlight' ? 2 : 7,
                        ),
                        border: tag.id == selectedId
                            ? Border.all(
                                color: const Color(0xff9c93ff),
                                width: 1.5,
                              )
                            : null,
                      ),
                      child: Text(
                        tag.text,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: tag.size,
                          height: 1.15,
                          fontWeight: tag.style == 'serif'
                              ? FontWeight.w500
                              : FontWeight.w700,
                          fontFamily: tag.style == 'serif' ? 'serif' : 'Roboto',
                          color: tag.style == 'highlight'
                              ? Colors.black
                              : Color(tag.color),
                          shadows: tag.style == 'plain' || tag.style == 'serif'
                              ? const [
                                  Shadow(
                                    blurRadius: 4,
                                    color: Colors.black,
                                    offset: Offset(0, 1),
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

IconData placeActionIcon(String kind) => switch (kind) {
  'directions' => Icons.directions,
  'menu' => Icons.restaurant_menu,
  'call' => Icons.call_outlined,
  'website' => Icons.language,
  'save' => Icons.bookmark_border,
  'order' => Icons.shopping_bag_outlined,
  _ => Icons.touch_app_outlined,
};

class _TagPosition extends SingleChildLayoutDelegate {
  final double x, y;
  _TagPosition(this.x, this.y);
  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.loose(Size(300, constraints.maxHeight));
  @override
  Offset getPositionForChild(Size size, Size childSize) => Offset(
    x * size.width - childSize.width / 2,
    y * size.height - childSize.height / 2,
  );
  @override
  bool shouldRelayout(_TagPosition oldDelegate) =>
      oldDelegate.x != x || oldDelegate.y != y;
}
