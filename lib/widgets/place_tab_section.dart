import 'package:flutter/material.dart';
import '../model/project.dart';
import 'output_palette.dart';

class PlaceTabSection extends StatelessWidget {
  final PlaceDetails place;
  final OutputPalette colors;

  const PlaceTabSection({
    super.key,
    required this.place,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final tab in [
              'Overview',
              if (place.hasMenu) 'Menu',
              'Reviews',
              'Photos',
              'Updates',
            ])
              Container(
                padding: const EdgeInsets.only(bottom: 7),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: tab == 'Overview'
                          ? colors.accent
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  tab,
                  style: TextStyle(
                    fontSize: 8,
                    color: tab == 'Overview' ? colors.accent : colors.muted,
                    height: 1.2,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          height: 28,
          decoration: BoxDecoration(
            color: colors.pale,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.open_in_new, color: colors.accent, size: 12),
              const SizedBox(width: 6),
              Text(
                place.footer,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: colors.accent,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 17),
        Row(
          children: [
            Icon(Icons.schedule, color: colors.muted, size: 12),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                place.hours.isEmpty ? 'Hours not set' : place.hours,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  color: colors.muted,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
