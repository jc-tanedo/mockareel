import 'package:flutter/material.dart';
import '../model/project.dart';

class OrbitLocationPicker extends StatelessWidget {
  final List<OrbitLocation> locations;
  final OrbitLocation? selected;
  final String label;
  final ValueChanged<OrbitLocation>? onChanged;
  const OrbitLocationPicker({
    super.key,
    required this.locations,
    required this.selected,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<OrbitLocation>(
    key: ValueKey(selected?.id),
    initialValue: selected,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    hint: const Text('Choose a location'),
    items: [
      for (final location in locations)
        DropdownMenuItem(
          value: location,
          child: Text(location.label, overflow: TextOverflow.ellipsis),
        ),
    ],
    onChanged: onChanged == null
        ? null
        : (location) {
            if (location != null) onChanged!(location);
          },
  );
}
