import 'package:flutter/material.dart';
import '../model/maps_web_result.dart';

class MapsWebPlaceView extends StatelessWidget {
  final MapsWebSnapshot details;
  final int selectedReview;
  final ValueChanged<int?> onSelectReview;

  const MapsWebPlaceView({
    super.key,
    required this.details,
    required this.selectedReview,
    required this.onSelectReview,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final place = details.place!;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  place.name,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (place.category.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colors.secondaryContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          place.category,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colors.onSecondaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    if (place.rating.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star,
                            size: 16,
                            color: Color(0xffffcc66),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            place.rating,
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    if (place.reviewCount.isNotEmpty)
                      Text(
                        '${place.reviewCount} reviews',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                for (final field in [
                  (Icons.place_outlined, place.address),
                  (Icons.schedule, place.hours),
                  (Icons.phone_outlined, place.phone),
                  (Icons.language, place.website),
                ])
                  if (field.$2.isNotEmpty)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: Icon(field.$1, size: 20, color: colors.primary),
                      title: Text(
                        field.$2,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurface,
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'All imported details remain editable.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Map header: capture a Google map in Place → Header.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        if (details.reviews.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'Featured review',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Optional. Google may shorten the text; you can edit it '
            'after import.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Card(
            margin: EdgeInsets.zero,
            child: RadioGroup<int>(
              groupValue: selectedReview,
              onChanged: onSelectReview,
              child: Column(
                children: [
                  const RadioListTile<int>(
                    value: -1,
                    title: Text('No featured review'),
                  ),
                  for (var i = 0; i < details.reviews.length; i++)
                    RadioListTile<int>(
                      value: i,
                      title: Text(
                        details.reviews[i].author.isEmpty
                            ? 'Review ${i + 1}'
                            : details.reviews[i].author,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      secondary: Text(
                        '${details.reviews[i].rating}/5',
                        style: TextStyle(
                          color: colors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        details.reviews[i].text,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
