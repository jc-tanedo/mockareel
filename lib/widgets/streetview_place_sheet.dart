import 'package:flutter/material.dart';
import '../model/project.dart';
import '../model/streetview_layout.dart';
import 'story_tags.dart';

class StreetviewPlaceSheet extends StatelessWidget {
  final StreetviewMedia settings;
  final bool dark, map;
  const StreetviewPlaceSheet({
    super.key,
    required this.settings,
    required this.dark,
    required this.map,
  });

  static List<PlaceAction> actions(PlaceDetails place, {required bool map}) =>
      place.actionOverrides ??
      [
        PlaceAction(kind: 'directions', label: 'Directions'),
        PlaceAction(kind: 'start', label: 'Start'),
        if (map) ...[
          PlaceAction(kind: 'ask', label: 'Ask'),
          if (place.phone.isNotEmpty) PlaceAction(kind: 'call', label: 'Call'),
          if (place.website.isNotEmpty)
            PlaceAction(kind: 'directory', label: 'Directory')
          else
            PlaceAction(kind: 'save', label: 'Save'),
        ] else ...[
          PlaceAction(kind: 'share', label: 'Share'),
          PlaceAction(kind: 'save', label: 'Save'),
          PlaceAction(kind: 'add_label', label: 'Add label'),
        ],
      ];

  @override
  Widget build(BuildContext context) {
    final ink = dark ? Colors.white : const Color(0xff202124);
    final title = !map && settings.streetviewTitle.isNotEmpty
        ? settings.streetviewTitle
        : settings.place.name.isEmpty
        ? 'Dropped pin'
        : settings.place.name;
    return Container(
      height: StreetviewLayout.sheetHeight,
      decoration: BoxDecoration(
        color: dark ? const Color(0xff111111) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        children: [
          Container(
            width: 30,
            height: 3,
            margin: const EdgeInsets.only(top: 6, bottom: 6),
            decoration: BoxDecoration(
              color: dark ? Colors.white30 : Colors.black26,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                for (final icon in [
                  Icons.bookmark_border,
                  Icons.share_outlined,
                  Icons.close,
                ]) ...[
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: dark
                          ? Colors.white10
                          : Colors.black.withValues(alpha: .04),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 14, color: ink),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  for (final action in actions(settings.place, map: map))
                    Padding(
                      padding: const EdgeInsets.only(right: 7),
                      child: Container(
                        height: 29,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: action.kind == 'directions'
                              ? const Color(0xff65c5cf)
                              : dark
                              ? const Color(0xff003e46)
                              : const Color(0xffd7f1f3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              placeActionIcon(action.kind),
                              size: 13,
                              color: action.kind == 'directions'
                                  ? const Color(0xff00333c)
                                  : dark
                                  ? const Color(0xffb2f2f6)
                                  : const Color(0xff00545d),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              action.label,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w500,
                                color: action.kind == 'directions'
                                    ? const Color(0xff00333c)
                                    : dark
                                    ? const Color(0xffb2f2f6)
                                    : const Color(0xff00545d),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
