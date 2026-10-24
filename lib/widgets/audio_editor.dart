import 'dart:math';
import 'package:flutter/material.dart';
import '../model/project.dart';
import '../model/feed.dart';

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
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (preview != null) preview!,
        const SizedBox(height: 12),
        const Text(
          'SOUNDTRACK',
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 2,
            color: Colors.white54,
          ),
        ),
        const SizedBox(height: 12),
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
        const SizedBox(height: 12),
        if (m != null) ...[
          Card(
            child: ListTile(
              leading: const Icon(Icons.music_note, color: Color(0xff9c93ff)),
              title: Text(m.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                '${m.sourceDuration.toStringAsFixed(1)}s source · ${(project.isFeed ? FeedTimeline.duration(project) : project.duration).toStringAsFixed(1)}s reel',
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
          const SizedBox(height: 16),
          Text('Volume · ${(m.volume * 100).round()}%'),
          Slider(
            value: m.volume,
            onChanged: (v) {
              m.volume = v;
              onChanged();
            },
          ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Timing & loop'),
            children: [
              Text('Start music at · ${m.trimStart.toStringAsFixed(1)}s'),
              Slider(
                value: m.trimStart,
                max: max(.001, m.sourceDuration - .1),
                onChanged: (v) {
                  m.trimStart = v;
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
          const Text(
            'Press play above to hear the soundtrack with your reel. Original clip audio is muted.',
            style: TextStyle(color: Colors.white54, height: 1.5),
          ),
        ] else
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Add music from your device, or continue to Export for a silent reel.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, height: 1.6),
            ),
          ),
      ],
    );
  }
}
