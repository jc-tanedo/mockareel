import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../model/project.dart';
import '../services/media_edits.dart';
import '../services/native_renderer.dart';
import 'blur_spot_preview.dart';
import 'editor_section_card.dart';

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
  Future<String>? _poster;
  Future<Size>? _size;
  bool get _showPreview =>
      edits.fisheye || (widget.clip.supportsBlur && edits.spots.isNotEmpty);
  MediaEdits get edits => widget.clip.edits;
  @override
  void initState() {
    super.initState();
    _refresh();
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
    if (_showPreview) {
      _size ??= _dimensions();
      _size!.ignore();
      _poster = NativeRenderer().poster(widget.clip);
      _poster!.ignore();
    }
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
    return EditorSectionCard(
      title: const Text('Media effects'),
      subtitle: Text(
        widget.clip.supportsBlur
            ? 'Fisheye, pincushion and blur spots'
            : 'Fisheye and pincushion',
      ),
      children: [
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
            isExpanded: true,
            initialValue: edits.lens,
            decoration: const InputDecoration(labelText: 'Lens type'),
            items: const [
              DropdownMenuItem(value: 'fisheye', child: Text('Fisheye')),
              DropdownMenuItem(value: 'pincushion', child: Text('Pincushion')),
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
        if (_showPreview)
          SizedBox(
            height: 260,
            child: FutureBuilder<Size>(
              future: _size,
              builder: (context, snapshot) {
                final size = snapshot.data ?? const Size(9, 16);
                return BlurSpotPreview(
                  key: ValueKey(widget.clip.id),
                  sourceSize: size,
                  spots: widget.clip.supportsBlur ? edits.spots : const [],
                  selected: _selected,
                  onSelect: (spot) => setState(() => _selected = spot.id),
                  onChanged: _change,
                  image: FutureBuilder<String>(
                    future: _poster,
                    builder: (context, image) => Stack(
                      fit: StackFit.expand,
                      children: [
                        if (image.hasData)
                          Image.file(
                            File(image.data!),
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(Icons.image_not_supported_outlined),
                            ),
                          )
                        else
                          const ColoredBox(color: Colors.black26),
                        if (image.connectionState != ConnectionState.done)
                          const Align(
                            alignment: Alignment.bottomCenter,
                            child: LinearProgressIndicator(),
                          ),
                        if (image.hasError)
                          Center(
                            child: TextButton(
                              onPressed: () => setState(_refresh),
                              child: const Text('Retry media effects'),
                            ),
                          ),
                      ],
                    ),
                  ),
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
      ],
    );
  }
}
