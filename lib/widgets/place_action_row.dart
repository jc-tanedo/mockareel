import 'package:flutter/material.dart';
import '../model/project.dart';
import 'output_palette.dart';
import 'story_tags.dart';

class PlaceActionRow extends StatelessWidget {
  final List<PlaceAction> actions;
  final OutputPalette colors;

  const PlaceActionRow({
    super.key,
    required this.actions,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final action in actions)
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: action.kind == 'directions'
                    ? colors.accent
                    : colors.pale,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    placeActionIcon(action.kind),
                    size: 11,
                    color: action.kind == 'directions'
                        ? colors.primaryText
                        : colors.accent,
                  ),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      action.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 8,
                        fontWeight: FontWeight.w500,
                        color: action.kind == 'directions'
                            ? colors.primaryText
                            : colors.accent,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
