import 'dart:math';
import 'package:flutter/material.dart';
import '../model/project.dart';
import '../model/template_layout.dart';
import 'reel_preview.dart';
import 'story_tags.dart';
import 'editor_workspace.dart';

class TextEditor extends StatefulWidget {
  final ReelProject project;
  final int selectedClip;
  final bool keyboardVisible;
  final VoidCallback onChanged;
  const TextEditor({
    super.key,
    required this.project,
    required this.onChanged,
    this.selectedClip = 0,
    this.keyboardVisible = false,
  });
  @override
  State<TextEditor> createState() => _TextEditorState();
}

class _TextEditorState extends State<TextEditor> {
  String? _selected;
  StoryTag? get _tag {
    for (final t in widget.project.tags) {
      if (t.id == _selected) return t;
    }
    return null;
  }

  void _change() {
    setState(() {});
    widget.onChanged();
  }

  Future<void> _write([StoryTag? existing]) async {
    final controller = TextEditingController(text: existing?.text ?? '');
    final text = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            22,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 22,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Text(
                    'Aa',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('Write your story')),
                  TextButton(
                    onPressed: () =>
                        Navigator.pop(context, controller.text.trim()),
                    child: const Text('Done'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                autofocus: true,
                maxLength: 160,
                maxLines: 4,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
                decoration: const InputDecoration(
                  hintText: 'Say something…',
                  border: InputBorder.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    // The route may still be animating out; let its TextField release the controller.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    controller.dispose();
    if (!mounted || text == null || text.isEmpty) return;
    if (existing != null) {
      existing.text = text;
    } else {
      final tag = StoryTag(
        text: text,
        y: (.26 + widget.project.tags.length * .07).clamp(.1, .9),
      );
      widget.project.tags.add(tag);
      _selected = tag.id;
    }
    _change();
  }

  @override
  Widget build(BuildContext context) {
    final tag = _tag;
    return EditorWorkspace(
      keyboardVisible: widget.keyboardVisible,
      hasPlaybackControls: false,
      hint: 'DRAG TEXT TO POSITION',
      previewBuilder: (height) => Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: height),
          child: AspectRatio(
            aspectRatio: 9 / 16,
            child: FittedBox(
              child: SizedBox(
                width: 360,
                height: 640,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ReelCanvas(
                        project: widget.project,
                        position:
                            widget.project.startOf(widget.selectedClip) +
                            TemplateLayout.transitionDuration(
                              widget.project,
                              widget.selectedClip,
                            ),
                        animateIntro: false,
                        showTags: false,
                      ),
                    ),
                    Positioned.fill(
                      child: StoryTagLayer(
                        tags: widget.project.tags,
                        selectedId: _selected,
                        onSelect: (t) => setState(() => _selected = t.id),
                        onChanged: _change,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      inspector: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'TEXT & TAGS',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 2,
                    color: Colors.white54,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: () => _write(),
                icon: const Icon(Icons.text_fields),
                label: const Text('Add text'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const SizedBox(height: 12),
          const Text(
            'Drag text to move it. Tap a tag to style it.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            children: [
              for (final t in widget.project.tags)
                ChoiceChip(
                  label: Text(
                    t.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  selected: _selected == t.id,
                  onSelected: (_) => setState(() => _selected = t.id),
                ),
            ],
          ),
          if (tag != null) ...[
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _write(tag),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit text'),
                  ),
                ),
                IconButton(
                  tooltip: 'Duplicate tag',
                  onPressed: () {
                    final copy = StoryTag.fromJson({
                      ...tag.toJson(),
                      'id': newId(),
                      'y': min(.95, tag.y + .06),
                    });
                    widget.project.tags.add(copy);
                    _selected = copy.id;
                    _change();
                  },
                  icon: const Icon(Icons.copy),
                ),
                IconButton(
                  tooltip: 'Delete tag',
                  onPressed: () {
                    widget.project.tags.remove(tag);
                    _selected = null;
                    _change();
                  },
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              children: [
                for (final style in ['badge', 'plain', 'highlight', 'serif'])
                  ChoiceChip(
                    label: Text(style),
                    selected: tag.style == style,
                    onSelected: (_) {
                      tag.style = style;
                      _change();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              children: [
                for (final color in [
                  0xffffffff,
                  0xff111111,
                  0xffffe36e,
                  0xffff8bba,
                  0xff93c8ff,
                  0xff8cf0c9,
                ])
                  InkWell(
                    onTap: () {
                      tag.color = color;
                      _change();
                    },
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Color(color),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: tag.color == color
                              ? const Color(0xff9c93ff)
                              : Colors.white24,
                          width: 3,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Transform'),
              children: [
                Text('Size · ${tag.size.round()}'),
                Slider(
                  value: tag.size,
                  min: 10,
                  max: 48,
                  onChanged: (v) {
                    tag.size = v;
                    _change();
                  },
                ),
                Text('Rotation · ${(tag.rotation * 180 / pi).round()}°'),
                Slider(
                  value: tag.rotation,
                  min: -pi,
                  max: pi,
                  onChanged: (v) {
                    tag.rotation = v;
                    _change();
                  },
                ),
                TextButton(
                  onPressed: () {
                    tag.x = .5;
                    tag.y = .5;
                    tag.rotation = 0;
                    _change();
                  },
                  child: const Text('Center on canvas'),
                ),
              ],
            ),
          ] else if (widget.project.tags.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Add a headline, location tag, or a little context. Each text layer can be moved and styled independently.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54),
              ),
            ),
        ],
      ),
    );
  }
}
