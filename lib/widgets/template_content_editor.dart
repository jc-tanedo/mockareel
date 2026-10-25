import 'package:flutter/material.dart';
import '../model/project.dart';

class TemplateContentEditor extends StatelessWidget {
  final ReelProject project;
  final bool loading, showHeader, showReview, expanded, useApiHeaders;
  final VoidCallback onChanged, onLoadMap, onUploadMap;
  const TemplateContentEditor({
    super.key,
    required this.project,
    required this.loading,
    this.showHeader = true,
    this.useApiHeaders = false,
    this.showReview = true,
    this.expanded = false,
    required this.onChanged,
    required this.onLoadMap,
    required this.onUploadMap,
  });
  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (showHeader)
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          initiallyExpanded: true,
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
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Icon(Icons.check_circle_outline),
                  title: Text('Map image ready for preview and export'),
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
                  IconButton(
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
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ],
            const SizedBox(height: 12),
          ],
        ),
      if (showReview)
        ExpansionTile(
          initiallyExpanded: expanded,
          tilePadding: EdgeInsets.zero,
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
            const SizedBox(height: 8),
            Row(
              children: [
                const Expanded(
                  child: Text('Review rating', style: TextStyle(fontSize: 12)),
                ),
                for (var i = 1; i <= 5; i++)
                  IconButton(
                    tooltip: '$i star review',
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(
                      minWidth: 30,
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
            const SizedBox(height: 8),
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
            const Text(
              'Blank text keeps the review hidden. The review card replaces the lower details area while retaining your place buttons above the gallery.',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
    ],
  );
}
