import 'editor_section_card.dart';
import 'package:flutter/material.dart';
import '../model/project.dart';

class TemplateContentEditor extends StatelessWidget {
  final ReelProject project;
  final bool loading, showHeader, showReview, useApiHeaders;
  final VoidCallback onChanged, onLoadMap, onUploadMap;
  const TemplateContentEditor({
    super.key,
    required this.project,
    required this.loading,
    this.showHeader = true,
    this.useApiHeaders = false,
    this.showReview = true,
    required this.onChanged,
    required this.onLoadMap,
    required this.onUploadMap,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      children: [
        if (showHeader)
          EditorSectionCard(
            title: const Text('Header image'),
            subtitle: const Text('Google map or your own map image'),
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'map',
                    icon: Icon(Icons.map_outlined),
                    label: Text('Map'),
                  ),
                  ButtonSegment(
                    value: 'photo',
                    icon: Icon(Icons.photo_outlined),
                    label: Text('Photo'),
                  ),
                ],
                selected: {project.headerMode},
                onSelectionChanged: (v) {
                  project.headerMode = v.first;
                  onChanged();
                },
              ),
              if (project.headerMode == 'map') ...[
                const SizedBox(height: 12),
                if (project.mapHeaderPath != null)
                  Container(
                    decoration: BoxDecoration(
                      color: colors.secondaryContainer.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                      ),
                      dense: true,
                      leading: Icon(
                        Icons.check_circle_outline,
                        color: colors.primary,
                      ),
                      title: const Text(
                        'Map image ready for preview and export',
                      ),
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: loading ? null : onLoadMap,
                        icon: const Icon(Icons.map),
                        label: Text(loading ? 'Loading…' : 'Load Google map'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.outlined(
                      tooltip: 'Upload map image',
                      onPressed: loading ? null : onUploadMap,
                      icon: const Icon(Icons.upload_file),
                    ),
                  ],
                ),
                if (useApiHeaders)
                  Row(
                    children: [
                      const Text('Map zoom'),
                      Expanded(
                        child: Slider(
                          min: 8,
                          max: 20,
                          divisions: 12,
                          value: project.mapZoom.clamp(8, 20).toDouble(),
                          label: '${project.mapZoom}',
                          onChanged: loading
                              ? null
                              : (v) {
                                  project.mapZoom = v.round();
                                  onChanged();
                                },
                        ),
                      ),
                      Text('${project.mapZoom}'),
                    ],
                  ),
                Text(
                  useApiHeaders
                      ? 'Load again after changing zoom. Using Maps Static API. Switch to key-free browser capture in Advanced · Google Maps.'
                      : 'No key needed. Frame the map in the browser and save it as your header. Optional API mode is in Advanced · Google Maps. You can also upload a map image.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
              const SizedBox(height: 4),
            ],
          ),
        if (showReview)
          EditorSectionCard(
            title: const Text('Featured review (optional)'),
            subtitle: Text(
              project.review.visible
                  ? 'Included in output'
                  : 'Hidden until review text is added',
            ),
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Include featured review'),
                value: project.review.enabled,
                onChanged: (v) {
                  project.review.enabled = v;
                  onChanged();
                },
              ),
              TextFormField(
                key: ValueKey('review-author-${project.id}'),
                initialValue: project.review.author,
                maxLength: 60,
                decoration: const InputDecoration(
                  labelText: 'Reviewer name (optional)',
                ),
                onChanged: (v) {
                  project.review.author = v;
                  onChanged();
                },
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Review rating',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  for (var i = 1; i <= 5; i++)
                    IconButton(
                      tooltip: '$i star review',
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 40,
                      ),
                      icon: Icon(
                        i <= project.review.rating
                            ? Icons.star
                            : Icons.star_border,
                        color: const Color(0xffedb928),
                        size: 22,
                      ),
                      onPressed: () {
                        project.review.rating = i;
                        onChanged();
                      },
                    ),
                ],
              ),
              const SizedBox(height: 4),
              TextFormField(
                key: ValueKey('review-text-${project.id}'),
                initialValue: project.review.text,
                maxLength: 280,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Featured review text',
                  hintText: 'Add a review to show it below the gallery',
                ),
                onChanged: (v) {
                  project.review.text = v;
                  onChanged();
                },
              ),
              Text(
                'Blank text keeps the review hidden. The review card replaces the lower details area while retaining your place buttons above the gallery.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ],
          ),
      ],
    );
  }
}
