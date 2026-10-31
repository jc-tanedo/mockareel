import 'editor_section_card.dart';
import 'package:flutter/material.dart';
import '../model/project.dart';

class OutputThemePicker extends StatelessWidget {
  final ReelProject project;
  final VoidCallback onChanged;
  const OutputThemePicker({
    super.key,
    required this.project,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) => EditorSectionCard(
    title: const Text('Output theme'),
    children: [
      SegmentedButton<bool>(
        segments: const [
          ButtonSegment(
            value: false,
            icon: Icon(Icons.light_mode_outlined),
            label: Text('Light'),
            tooltip: 'Light output',
          ),
          ButtonSegment(
            value: true,
            icon: Icon(Icons.dark_mode_outlined),
            label: Text('Dark'),
            tooltip: 'Dark output',
          ),
        ],
        selected: {project.darkOutput},
        onSelectionChanged: (v) {
          project.darkOutput = v.first;
          onChanged();
        },
      ),
    ],
  );
}
