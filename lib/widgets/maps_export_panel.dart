import 'package:flutter/material.dart';
import '../model/project.dart';
import '../model/streetview_timeline.dart';
import 'editor_section_card.dart';

class MapsExportPanel extends StatelessWidget {
  final ReelProject project;
  final bool importing;
  final VoidCallback onExport;
  final void Function(bool snapshot) onExportPng;
  final VoidCallback onBackup;
  final VoidCallback onSetupHeader;

  const MapsExportPanel({
    super.key,
    required this.project,
    required this.importing,
    required this.onExport,
    required this.onExportPng,
    required this.onBackup,
    required this.onSetupHeader,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final needsMap = project.isStreetview
        ? StreetviewTimeline.scenes(project)
              .where((s) => s.kind == 'map' || s.kind == 'ending-map')
              .any(
                (s) => project.clips[s.mediaIndex].streetview.mapPath == null,
              )
        : project.headerMode == 'map' && project.mapHeaderPath == null;
    final durationLabel = project.duration.toStringAsFixed(
      project.isStreetview ? 2 : 1,
    );
    final musicLabel = project.music == null ? 'Silent' : 'With music';

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: colors.secondaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.hd_outlined,
                          color: colors.onSecondaryContainer,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '1080 × 1920',
                              style: textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Vertical MP4 · H.264 · $musicLabel',
                              style: textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${project.clips.length} clips · '
                              '$durationLabel seconds',
                              style: textTheme.labelMedium?.copyWith(
                                color: colors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (project.clips.isEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Add at least one photo or video in Timeline '
                          'to export.',
                          style: textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (needsMap)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: colors.secondaryContainer.withValues(alpha: .45),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.map_outlined,
                        size: 18,
                        color: colors.onSecondaryContainer,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          project.isStreetview
                              ? 'Capture the journey’s map screens in Place.'
                              : 'Your map header needs an image.',
                          style: textTheme.bodySmall?.copyWith(
                            color: colors.onSecondaryContainer,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: onSetupHeader,
                        child: const Text('Set up header'),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
              EditorSectionCard(
                title: const Text('Still images'),
                subtitle: const Text('Transparent template or full snapshot'),
                children: [
                  OutlinedButton.icon(
                    onPressed: needsMap ? null : () => onExportPng(false),
                    icon: const Icon(Icons.layers_outlined),
                    label: const Text('Transparent template PNG'),
                  ),
                  OutlinedButton.icon(
                    onPressed: project.clips.isEmpty || needsMap
                        ? null
                        : () => onExportPng(true),
                    icon: const Icon(Icons.image_outlined),
                    label: const Text('Full snapshot PNG'),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
              const Divider(height: 24),
              TextButton.icon(
                onPressed: onBackup,
                icon: const Icon(Icons.inventory_2_outlined, size: 18),
                label: const Text('Share project backup'),
              ),
              Text(
                'Your project and media autosave on this device.',
                textAlign: TextAlign.center,
                style: textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: project.clips.isEmpty || importing || needsMap
                  ? null
                  : onExport,
              icon: const Icon(Icons.file_download_outlined),
              label: const Text('Render MP4'),
            ),
          ),
        ),
      ],
    );
  }
}
