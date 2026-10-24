import 'package:flutter/material.dart';

const _accent = Color(0xffb1a6ff);

/// A stable preview stage and a separate scrolling inspector, like a media editor.
class EditorWorkspace extends StatefulWidget {
  final Widget Function(double maxHeight) previewBuilder;
  final Widget inspector;
  final String hint;
  final bool hasPlaybackControls, keyboardVisible;
  final double previewFraction;
  const EditorWorkspace({
    super.key,
    required this.previewBuilder,
    required this.inspector,
    this.hint = 'LIVE PREVIEW',
    this.hasPlaybackControls = true,
    this.keyboardVisible = false,
    this.previewFraction = .56,
  });
  @override
  State<EditorWorkspace> createState() => _EditorWorkspaceState();
}

class _EditorWorkspaceState extends State<EditorWorkspace> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final keyboard =
          widget.keyboardVisible || MediaQuery.viewInsetsOf(context).bottom > 0;
      final wide = bounds.maxWidth >= 680;
      final hidePreview = keyboard || (!wide && bounds.maxHeight < 260);
      final stageHeight = wide
          ? bounds.maxHeight
          : _expanded
          ? bounds.maxHeight
          : (bounds.maxHeight * widget.previewFraction).clamp(150.0, 380.0);
      Widget stage() => ColoredBox(
        color: const Color(0xff101012),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 2, 12, 4),
          child: Column(
            children: [
              SizedBox(
                height: 28,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.hint,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 9,
                          letterSpacing: 1.4,
                          color: Colors.white38,
                        ),
                      ),
                    ),

                    const Text(
                      '9:16',
                      style: TextStyle(fontSize: 10, color: Colors.white54),
                    ),
                    if (!wide)
                      IconButton(
                        tooltip: _expanded
                            ? 'Show editing controls'
                            : 'Expand preview',
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        iconSize: 17,
                        onPressed: () => setState(() => _expanded = !_expanded),
                        icon: Icon(
                          _expanded
                              ? Icons.close_fullscreen
                              : Icons.open_in_full,
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: widget.previewBuilder(
                    (stageHeight - (widget.hasPlaybackControls ? 88 : 40))
                        .clamp(60.0, 900.0),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      final sideBySide = wide && !keyboard;
      // Keep one Flex and a stable inspector element while the keyboard changes
      // orientation. Replacing Row with Column recreates focused text fields.
      return Flex(
        direction: sideBySide ? Axis.horizontal : Axis.vertical,
        children: [
          if (sideBySide)
            Expanded(flex: 5, child: stage())
          else if (!hidePreview)
            SizedBox(height: stageHeight, child: stage()),
          if (sideBySide)
            const VerticalDivider(width: 1)
          else if (!_expanded || hidePreview)
            const Divider(height: 1),
          if (sideBySide || !_expanded || hidePreview)
            Expanded(
              key: const ValueKey('workspace-inspector'),
              flex: sideBySide ? 4 : 1,
              child: widget.inspector,
            ),
        ],
      );
    },
  );
}

class InspectorTabs extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;
  const InspectorTabs({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
  });
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 12,
                    color: selected == i ? _accent : Colors.white60,
                  ),
                ),
                selected: selected == i,
                showCheckmark: false,
                selectedColor: const Color(0xff322c48),
                backgroundColor: Colors.transparent,
                side: BorderSide(
                  color: selected == i
                      ? const Color(0xff514674)
                      : Colors.transparent,
                ),
                onSelected: (_) => onSelected(i),
              ),
            ),
        ],
      ),
    ),
  );
}
