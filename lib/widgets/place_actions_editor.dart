import 'package:flutter/material.dart';
import '../model/project.dart';
import 'story_tags.dart';

class PlaceActionsEditor extends StatefulWidget {
  final PlaceDetails place;
  final bool expanded;
  final VoidCallback onChanged;
  const PlaceActionsEditor({
    super.key,
    required this.place,
    this.expanded = false,
    required this.onChanged,
  });
  @override
  State<PlaceActionsEditor> createState() => _PlaceActionsEditorState();
}

class _PlaceActionsEditorState extends State<PlaceActionsEditor> {
  PlaceDetails get place => widget.place;
  VoidCallback get onChanged => widget.onChanged;
  int _revision = 0;
  void _structureChanged() {
    setState(() => _revision++);
    onChanged();
  }

  void _customize() => place.actionOverrides ??= place.suggestedActions;
  @override
  Widget build(BuildContext context) => ExpansionTile(
    initiallyExpanded: widget.expanded,
    tilePadding: EdgeInsets.zero,
    title: const Text('Template buttons'),
    subtitle: const Text('Suggested from this place · fully editable'),
    children: [
      for (var i = 0; i < place.actions.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              DropdownButton<String>(
                value: place.actions[i].kind,
                items: [
                  for (final kind in [
                    'directions',
                    'menu',
                    'call',
                    'website',
                    'save',
                    'order',
                    'custom',
                  ])
                    DropdownMenuItem(
                      value: kind,
                      child: Icon(placeActionIcon(kind), semanticLabel: kind),
                    ),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  _customize();
                  place.actionOverrides![i].kind = v;
                  _structureChanged();
                },
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  key: ValueKey('action-${place.placeId}-$_revision-$i'),
                  initialValue: place.actions[i].label,
                  decoration: InputDecoration(
                    labelText: 'Button ${i + 1} label',
                  ),
                  maxLength: 20,
                  buildCounter:
                      (
                        _, {
                        required currentLength,
                        required isFocused,
                        maxLength,
                      }) => null,
                  onChanged: (v) {
                    _customize();
                    place.actionOverrides![i].label = v;
                    onChanged();
                  },
                ),
              ),
              IconButton(
                tooltip: 'Remove button ${i + 1}',
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () {
                  _customize();
                  place.actionOverrides!.removeAt(i);
                  _structureChanged();
                },
              ),
            ],
          ),
        ),
      Row(
        children: [
          TextButton.icon(
            onPressed: place.actions.length >= 4
                ? null
                : () {
                    _customize();
                    place.actionOverrides!.add(
                      PlaceAction(kind: 'custom', label: 'Action'),
                    );
                    onChanged();
                  },
            icon: const Icon(Icons.add),
            label: const Text('Add button'),
          ),
          TextButton(
            onPressed: () {
              place.actionOverrides = null;
              place.menuOverride = null;
              place.footerOverride = null;
              _structureChanged();
            },
            child: const Text('Reset suggestions'),
          ),
        ],
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Show Menu tab'),
        value: place.hasMenu,
        onChanged: (v) {
          place.menuOverride = v;
          onChanged();
        },
      ),
      TextFormField(
        key: ValueKey('footer-${place.placeId}-$_revision'),
        initialValue: place.footer,
        maxLength: 40,
        decoration: const InputDecoration(labelText: 'Bottom button label'),
        onChanged: (v) {
          place.footerOverride = v;
          onChanged();
        },
      ),
      const SizedBox(height: 12),
      const Text(
        'These buttons are part of the rendered design; they are not interactive links in the exported video.',
        style: TextStyle(fontSize: 12, color: Colors.white54),
      ),
    ],
  );
}
