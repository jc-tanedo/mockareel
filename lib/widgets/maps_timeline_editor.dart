import 'package:flutter/material.dart';
import '../model/project.dart';
import '../services/project_store.dart';
import 'editor_section_card.dart';
import 'editor_workspace.dart';
import 'media_frame.dart';
import 'streetview_inspector.dart';

class MapsTimelineEditor extends StatelessWidget {
  final ReelProject project;
  final int selectedIndex;
  final int timelineTool;
  final bool importing;
  final ProjectStore store;
  final VoidCallback onPickMedia;
  final Widget addMediaButton;
  final ValueChanged<int> onSelectClip;
  final ValueChanged<int> onSelectTool;
  final ValueChanged<int> onRemoveClip;
  final void Function(int index, int delta) onMoveClip;
  final VoidCallback onChanged;
  final VoidCallback onPreviewUpdated;

  const MapsTimelineEditor({
    super.key,
    required this.project,
    required this.selectedIndex,
    required this.timelineTool,
    required this.importing,
    required this.store,
    required this.onPickMedia,
    required this.addMediaButton,
    required this.onSelectClip,
    required this.onSelectTool,
    required this.onRemoveClip,
    required this.onMoveClip,
    required this.onChanged,
    required this.onPreviewUpdated,
  });

  Widget _framingControl(
    String label,
    double value,
    double min,
    double max,
    String valueLabel,
    ValueChanged<double> change,
  ) => EditorSlider(
    label: label,
    valueLabel: valueLabel,
    value: value.clamp(min, max),
    min: min,
    max: max > min ? max : min + .001,
    onChanged: change,
  );

  static Widget buildClipStrip({
    required BuildContext context,
    required ReelProject project,
    required int selectedIndex,
    required ValueChanged<int> onSelectClip,
  }) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: 74,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: project.clips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final c = project.clips[i];
          final active = i == selectedIndex;
          return Semantics(
            label: 'Clip ${i + 1}: ${c.name}',
            selected: active,
            button: true,
            child: Tooltip(
              message: c.name,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => onSelectClip(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: (c.duration * 12).clamp(78, 150),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: active ? colors.primary : colors.outlineVariant,
                      width: active ? 2 : 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipPoster(clip: c),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black87],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 6,
                          top: 5,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: active ? colors.primary : Colors.black54,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${i + 1}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: active ? colors.onPrimary : Colors.white,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 6,
                          right: 4,
                          bottom: 5,
                          child: Text(
                            '${c.duration.toStringAsFixed(c.isGif ? 2 : 1)}s',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: active
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: active ? colors.primary : Colors.white70,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _motionInspector(BuildContext context) {
    final mutedStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EditorSectionCard(
          title: const Text('Opening scroll reveal'),
          children: [
            _framingControl(
              'Reveal duration',
              project.sheetIntroSeconds,
              0,
              2,
              '${project.sheetIntroSeconds.toStringAsFixed(1)}s',
              (v) {
                project.sheetIntroSeconds = v < .1 ? 0 : v;
                onPreviewUpdated();
                onChanged();
              },
            ),
            Text(
              'Set to zero to start with the sheet already in position.',
              style: mutedStyle,
            ),
          ],
        ),
        EditorSectionCard(
          title: const Text('Left-scroll snap'),
          children: [
            _framingControl(
              'Slide speed',
              project.slideSeconds,
              .15,
              .8,
              '${project.slideSeconds.toStringAsFixed(2)}s',
              (v) {
                project.slideSeconds = v;
                onChanged();
              },
            ),
            Text(
              'Slide time is included in each clip’s duration.',
              style: mutedStyle,
            ),
            TextButton(
              onPressed: () {
                for (final c in project.clips) {
                  c.duration = 1.56;
                  c.normalize();
                }
                project.slideSeconds = .35;
                onPreviewUpdated();
                onChanged();
              },
              child: const Text('Use reference pace · 1.56s per card'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _clipCard(BuildContext context, int index) {
    final clip = project.clips[index];
    return EditorSectionCard(
      key: ValueKey(clip.id),
      title: Text(timelineTool == 0 ? 'Media timing' : 'Media framing'),
      children: [
        if (timelineTool == 0) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  'Duration · '
                  '${clip.duration.toStringAsFixed(clip.isGif ? 2 : 1)}s',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: 'Move clip earlier',
                onPressed: index == 0 ? null : () => onMoveClip(index, -1),
                icon: const Icon(Icons.chevron_left, size: 18),
              ),
              IconButton(
                tooltip: 'Move clip later',
                onPressed: index == project.clips.length - 1
                    ? null
                    : () => onMoveClip(index, 1),
                icon: const Icon(Icons.chevron_right, size: 18),
              ),
            ],
          ),
          Slider(
            value: clip.duration,
            min: clip.minDuration,
            max: clip.maxDuration,
            onChanged: (v) {
              clip.duration = v;
              clip.normalize();
              onChanged();
            },
          ),
          if (clip.isGif)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Loop GIF'),
              subtitle: const Text(
                'Repeat the animation to fill the clip duration',
              ),
              value: clip.loopGif,
              onChanged: (v) {
                clip.setGifLoop(v);
                onChanged();
              },
            ),
          if (clip.isTimed && clip.maxTrimStart > .001) ...[
            Text(
              'Start at '
              '${clip.trimStart.toStringAsFixed(clip.isGif ? 2 : 1)}s of '
              '${clip.sourceDuration.toStringAsFixed(clip.isGif ? 2 : 1)}s',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            Slider(
              value: clip.trimStart,
              max: clip.maxTrimStart,
              onChanged: (v) {
                clip.trimStart = v;
                clip.normalize();
                onChanged();
              },
            ),
          ],
          TextFormField(
            key: ValueKey('caption-${clip.id}'),
            initialValue: clip.caption,
            maxLength: 120,
            decoration: const InputDecoration(
              labelText: 'Caption (optional)',
              counterText: '',
            ),
            onChanged: (v) {
              clip.caption = v;
              onChanged();
            },
          ),
        ],
        if (timelineTool == 1)
          Column(
            children: [
              if (!project.isStreetview)
                _framingControl(
                  'Card width',
                  clip.cardWidth,
                  .45,
                  1,
                  '${(clip.cardWidth * 328).round()} px',
                  (v) {
                    clip.cardWidth = v;
                    onChanged();
                  },
                ),
              if (!project.isStreetview)
                _framingControl(
                  'Card height',
                  clip.cardHeight,
                  .55,
                  1,
                  '${(clip.cardHeight * 250).round()} px',
                  (v) {
                    clip.cardHeight = v;
                    onChanged();
                  },
                ),
              _framingControl(
                'Zoom',
                clip.zoom,
                1,
                3,
                '${clip.zoom.toStringAsFixed(2)}×',
                (v) {
                  clip.zoom = v;
                  onChanged();
                },
              ),
              _framingControl(
                'Horizontal crop',
                clip.panX,
                -1,
                1,
                '${(clip.panX * 100).round()}%',
                (v) {
                  clip.panX = v;
                  onChanged();
                },
              ),
            ],
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, bounds) {
        final colors = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;
        final compact =
            bounds.maxHeight < 240 ||
            MediaQuery.viewInsetsOf(context).bottom > 0;
        final durationLabel = project.duration.toStringAsFixed(
          project.isStreetview ? 2 : 1,
        );
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: compact && project.clips.isNotEmpty
                        ? DropdownButton<int>(
                            value: selectedIndex,
                            isExpanded: true,
                            underline: const SizedBox(),
                            items: [
                              for (var i = 0; i < project.clips.length; i++)
                                DropdownMenuItem(
                                  value: i,
                                  child: Text(
                                    '${i + 1}. ${project.clips[i].name}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: textTheme.bodySmall,
                                  ),
                                ),
                            ],
                            onChanged: (i) {
                              if (i != null) onSelectClip(i);
                            },
                          )
                        : Text(
                            '${project.clips.length} clips · '
                            '$durationLabel seconds',
                            style: textTheme.labelMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                  ),
                  TextButton.icon(
                    onPressed: importing ? null : onPickMedia,
                    icon: const Icon(Icons.add, size: 17),
                    label: Text(importing ? 'Importing…' : 'Add media'),
                  ),
                ],
              ),
            ),
            if (project.clips.isNotEmpty) ...[
              if (!compact)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: buildClipStrip(
                    context: context,
                    project: project,
                    selectedIndex: selectedIndex,
                    onSelectClip: onSelectClip,
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: InspectorTabs(
                      labels: const ['Timing', 'Frame', 'Motion'],
                      selected: timelineTool,
                      onSelected: onSelectTool,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove clip ${selectedIndex + 1}',
                    icon: Icon(
                      Icons.delete_outline,
                      size: 19,
                      color: colors.onSurfaceVariant,
                    ),
                    onPressed: () => onRemoveClip(selectedIndex),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
              Expanded(
                child: ListView(
                  key: ValueKey('timeline-inspector-$timelineTool'),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  children: [
                    if (timelineTool == 2 && project.isStreetview)
                      StreetviewInspector(
                        key: ValueKey(project.clips[selectedIndex].id),
                        project: project,
                        clip: project.clips[selectedIndex],
                        store: store,
                        onChanged: onChanged,
                      )
                    else if (timelineTool == 2)
                      _motionInspector(context)
                    else
                      _clipCard(
                        context,
                        selectedIndex.clamp(0, project.clips.length - 1),
                      ),
                  ],
                ),
              ),
            ] else
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: colors.secondaryContainer.withValues(
                            alpha: .55,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.video_collection_outlined,
                          color: colors.onSecondaryContainer,
                          size: 30,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Start with your photos & videos',
                      textAlign: TextAlign.center,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add media, tap a clip to edit it, then set the pace.',
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    addMediaButton,
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
