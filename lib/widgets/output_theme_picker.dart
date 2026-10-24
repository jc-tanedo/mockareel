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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'OUTPUT THEME',
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 1.5,
            color: Colors.white54,
          ),
        ),
        const SizedBox(height: 8),
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
    ),
  );
}
