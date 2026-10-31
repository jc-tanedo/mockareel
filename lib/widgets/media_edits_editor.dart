import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../model/project.dart';
import '../services/media_edits.dart';
import '../services/native_renderer.dart';

class MediaEditsEditor extends StatefulWidget {
  final ReelClip clip;
  final VoidCallback onChanged;
  const MediaEditsEditor({
    super.key,
    required this.clip,
    required this.onChanged,
  });
  @override
  State<MediaEditsEditor> createState() => _MediaEditsEditorState();
}

class _MediaEditsEditorState extends State<MediaEditsEditor> {
  String? _selected;
  String _stamp = '';
  bool _expanded = false;
  late Future<String> _poster;
  late Future<Size> _size;
  MediaEdits get edits => widget.clip.edits;
  @override
  void initState() {
    super.initState();
    _stamp = EditedMedia.stamp(widget.clip);
  }

  Future<Size> _dimensions() async {
    if (widget.clip.isVideo) {
      final info = await NativeRenderer().inspect(widget.clip.path);
      return Size(
        (info['width'] as num).toDouble(),
        (info['height'] as num).toDouble(),
      );
    }
    final buffer = await ui.ImmutableBuffer.fromFilePath(widget.clip.path);
    try {
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      try {
        return Size(descriptor.width.toDouble(), descriptor.height.toDouble());
      } finally {
        descriptor.dispose();
      }
    } finally {
      buffer.dispose();
    }
  }

  void _refresh() {
    _stamp = EditedMedia.stamp(widget.clip);
    if (_expanded) _poster = NativeRenderer().poster(widget.clip);
  }

  void _change() {
    setState(_refresh);
    widget.onChanged();
  }

  @override
  void didUpdateWidget(MediaEditsEditor old) {
    super.didUpdateWidget(old);
    if (_stamp != EditedMedia.stamp(widget.clip)) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.clip.supportsBlur
        ? edits.spots.where((s) => s.id == _selected).firstOrNull
        : null;
    return ExpansionTile(
      onExpansionChanged: (value) {
        setState(() {
          _expanded = value;
          if (value) {
            _size = _dimensions();
            _refresh();
          }
        });
      },
      title: const Text('Media effects'),
      subtitle: Text(
        widget.clip.supportsBlur
            ? 'Fisheye, pincushion and blur spots'
            : 'Fisheye and pincushion',
      ),
      tilePadding: EdgeInsets.zero,
      children: [
        if (_expanded) ...[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Lens effect'),
            value: edits.fisheye,
            onChanged: (v) {
              edits.fisheye = v;
              _change();
            },
          ),
          if (edits.fisheye) ...[
            DropdownButtonFormField<String>(
              initialValue: edits.lens,
              decoration: const InputDecoration(labelText: 'Lens type'),
              items: const [
                DropdownMenuItem(value: 'fisheye', child: Text('Fisheye')),
                DropdownMenuItem(
                  value: 'pincushion',
                  child: Text('Pincushion'),
                ),
              ],
              onChanged: (value) {
                edits.lens = value!;
                _change();
              },
            ),
            Text(
              '${edits.lens == 'pincushion' ? 'Pincushion' : 'Fisheye'} strength · ${(edits.strength * 100).round()}%',
            ),
            Slider(
              value: edits.strength,
              onChanged: (v) {
                edits.strength = v;
                _change();
              },
            ),
          ],
          SizedBox(
            height: 260,
            child: FutureBuilder<Size>(
              future: _size,
              builder: (context, snapshot) {
                final size = snapshot.data ?? const Size(9, 16);
                return LayoutBuilder(
                  builder: (context, bounds) {
                    final fitted = applyBoxFit(
                      BoxFit.contain,
                      size,
                      bounds.biggest,
                    ).destination;
                    return Center(
                      child: SizedBox(
                        width: fitted.width,
                        height: fitted.height,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            FutureBuilder<String>(
                              future: _poster,
                              builder: (context, image) => Stack(
                                fit: StackFit.expand,
                                children: [
                                  if (image.hasData)
                                    Image.file(
                                      File(image.data!),
                                      fit: BoxFit.contain,
                                    )
                                  else
                                    const ColoredBox(color: Colors.black26),
                                  if (image.connectionState !=
                                      ConnectionState.done)
                                    const Align(
                                      alignment: Alignment.bottomCenter,
                                      child: LinearProgressIndicator(),
                                    ),
                                  if (image.hasError)
                                    Center(
                                      child: TextButton(
                                        onPressed: () => setState(_refresh),
                                        child: const Text(
                                          'Retry media effects',
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            for (
                              var i = 0;
                              widget.clip.supportsBlur &&
                                  i < edits.spots.length;
                              i++
                            )
                              _handle(edits.spots[i], i, fitted),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (widget.clip.supportsBlur) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: edits.spots.length >= MediaEdits.maxSpots
                        ? null
                        : () {
                            final spot = BlurSpot();
                            edits.spots.add(spot);
                            _selected = spot.id;
                            _change();
                          },
                    icon: const Icon(Icons.blur_on),
                    label: Text(
                      'Add blur spot (${edits.spots.length}/${MediaEdits.maxSpots})',
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Remove selected blur spot',
                  onPressed: selected == null
                      ? null
                      : () {
                          edits.spots.remove(selected);
                          _selected = edits.spots.firstOrNull?.id;
                          _change();
                        },
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            if (edits.spots.isNotEmpty)
              Wrap(
                spacing: 6,
                children: [
                  for (var i = 0; i < edits.spots.length; i++)
                    ChoiceChip(
                      label: Text('Spot ${i + 1}'),
                      selected: edits.spots[i].id == _selected,
                      onSelected: (_) =>
                          setState(() => _selected = edits.spots[i].id),
                    ),
                ],
              ),
            if (selected != null) ...[
              const SizedBox(height: 8),
              const Text(
                'Drag the circle to position the blur. Adjust its size below.',
              ),
              Slider(
                value: selected.radius,
                min: .025,
                max: .3,
                semanticFormatterCallback: (v) =>
                    'Spot size ${(v * 200).round()} percent',
                onChanged: (v) {
                  selected.radius = v;
                  _change();
                },
              ),
            ],
          ] else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Blur spots are available for photos.'),
            ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _handle(BlurSpot spot, int index, Size fitted) {
    final radius = spot.radius * min(fitted.width, fitted.height);
    return Positioned(
      left: spot.x * fitted.width - radius,
      top: spot.y * fitted.height - radius,
      width: radius * 2,
      height: radius * 2,
      child: Semantics(
        label: 'Blur spot ${index + 1}',
        selected: spot.id == _selected,
        child: GestureDetector(
          dragStartBehavior: DragStartBehavior.down,
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _selected = spot.id),
          onPanStart: (_) => setState(() => _selected = spot.id),
          onPanUpdate: (event) {
            spot.x = (spot.x + event.delta.dx / fitted.width).clamp(0, 1);
            spot.y = (spot.y + event.delta.dy / fitted.height).clamp(0, 1);
            _change();
          },
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: .06),
              border: Border.all(
                color: spot.id == _selected
                    ? const Color(0xffb1a6ff)
                    : Colors.white,
                width: 2,
              ),
            ),
            child: const Icon(Icons.open_with, size: 16, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
