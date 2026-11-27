import '../model/feed_timeline.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import '../model/project.dart';
import 'editor_section_card.dart';

class AudioEditor extends StatelessWidget {
  final ReelProject project;
  final Widget? preview;
  final bool importing;
  final VoidCallback onPick, onChanged;
  const AudioEditor({
    super.key,
    required this.project,
    this.preview,
    required this.importing,
    required this.onPick,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    final m = project.music;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (preview != null) preview!,
        EditorSectionCard(
          title: const Text('Soundtrack'),
          subtitle: const Text(
            'Background audio mixed into your exported reel',
          ),
          children: [
            FilledButton.icon(
              onPressed: importing ? null : onPick,
              icon: const Icon(Icons.library_music_outlined),
              label: Text(
                importing
                    ? 'Importing audio…'
                    : m == null
                    ? 'Choose background music'
                    : 'Replace music',
              ),
            ),
            if (m != null) ...[
              Container(
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colors.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 2,
                  ),
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: colors.secondaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.music_note,
                      size: 20,
                      color: colors.onSecondaryContainer,
                    ),
                  ),
                  title: Text(
                    m.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface,
                    ),
                  ),
                  subtitle: Text(
                    '${m.sourceDuration.toStringAsFixed(1)}s source · ${(project.isFeed ? FeedTimeline.duration(project) : project.duration).toStringAsFixed(1)}s reel',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  trailing: IconButton(
                    tooltip: 'Remove music',
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      project.music = null;
                      onChanged();
                    },
                  ),
                ),
              ),
              EditorSlider(
                label: 'Volume',
                valueLabel: '${(m.volume * 100).round()}%',
                value: m.volume,
                min: 0,
                max: 1,
                onChanged: (v) {
                  m.volume = v;
                  onChanged();
                },
              ),
              Text(
                'Press play above to hear your soundtrack and clip audio mix.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ] else
              Text(
                'Add music from your device, or continue to Export for a silent reel.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
          ],
        ),
        if (m != null)
          EditorSectionCard(
            title: const Text('Timing & loop'),
            children: [
              EditorSlider(
                label: 'Start music at',
                valueLabel: '${m.trimStart.toStringAsFixed(1)}s',
                value: m.trimStart,
                min: 0,
                max: max(.001, m.sourceDuration - .1),
                onChanged: (v) {
                  m.trimStart = v;
                  m.normalize();
                  onChanged();
                },
              ),
              EditorSlider(
                label: 'Fade out',
                valueLabel: m.fadeOutSeconds <= .05
                    ? 'Off'
                    : '${m.fadeOutSeconds.toStringAsFixed(1)}s',
                value: m.fadeOutSeconds,
                min: 0,
                max: 5,
                onChanged: (v) {
                  m.fadeOutSeconds = v < .05 ? 0 : v;
                  m.normalize();
                  onChanged();
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Loop to fit reel'),
                subtitle: const Text('Repeat from the selected start point'),
                value: m.loop,
                onChanged: (v) {
                  m.loop = v;
                  onChanged();
                },
              ),
            ],
          ),
        EditorSectionCard(
          title: const Text('Original clip audio'),
          subtitle: const Text(
            'Mix source audio from video clips with your soundtrack',
          ),
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Keep original video audio'),
              value: project.clipAudioVolume > 0,
              onChanged: (v) {
                project.clipAudioVolume = v ? .8 : 0;
                onChanged();
              },
            ),
            if (project.clipAudioVolume > 0) ...[
              EditorSlider(
                label: 'Clip audio volume',
                valueLabel: '${(project.clipAudioVolume * 100).round()}%',
                value: project.clipAudioVolume,
                min: 0,
                max: 1,
                onChanged: (v) {
                  project.clipAudioVolume = v < .02 ? 0 : v;
                  onChanged();
                },
              ),
              if (project.clips.any((c) => c.isVideo && !c.isGif))
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (var i = 0; i < project.clips.length; i++)
                      if (project.clips[i].isVideo && !project.clips[i].isGif)
                        FilterChip(
                          selected: !project.clips[i].muted,
                          avatar: Icon(
                            project.clips[i].muted
                                ? Icons.volume_off
                                : Icons.volume_up,
                            size: 16,
                          ),
                          label: Text('Clip ${i + 1}'),
                          onSelected: (_) {
                            project.clips[i].muted = !project.clips[i].muted;
                            onChanged();
                          },
                        ),
                  ],
                )
              else
                Text(
                  'Photos and GIFs are silent; video clips will play at this volume.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
            ],
          ],
        ),
      ],
    );
  }
}
