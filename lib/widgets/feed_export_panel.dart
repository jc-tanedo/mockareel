import 'package:flutter/material.dart';
import '../model/feed_timeline.dart';
import '../model/project.dart';

class FeedExportPanel extends StatelessWidget {
  final ReelProject project;
  final bool busy;
  final VoidCallback onExport;
  final VoidCallback onBackup;

  const FeedExportPanel({
    super.key,
    required this.project,
    required this.busy,
    required this.onExport,
    required this.onBackup,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final mutedStyle = textTheme.bodySmall?.copyWith(
      color: colors.onSurfaceVariant,
    );
    final seconds = FeedTimeline.duration(project).toStringAsFixed(1);
    final prefix = project.feed.hasSearch
        ? 'Typed search → '
        : project.feed.opening == 'home'
        ? 'Home screen → '
        : '';
    final suffix = project.feed.closeToHome ? ' → Home screen' : '';
    final flowLabel = '${prefix}Vertical feed$suffix';

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'READY FOR YOUR CLOSE-UP',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: colors.primary,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${project.clips.length} posts · $seconds seconds',
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '1080 × 1920 · 30 fps · MP4',
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: colors.secondaryContainer,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          flowLabel,
                          style: textTheme.labelSmall?.copyWith(
                            color: colors.onSecondaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (project.clips.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Add at least one photo or video in Posts.',
                    style: TextStyle(fontSize: 12, color: colors.primary),
                  ),
                ),
              Text(
                'Background music is optional. Source video audio is muted.',
                style: mutedStyle,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onBackup,
                icon: const Icon(Icons.inventory_2_outlined),
                label: const Text('Share project backup'),
              ),
              const SizedBox(height: 8),
              Text(
                'Changes save automatically on this device.',
                style: mutedStyle,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: project.clips.isEmpty || busy ? null : onExport,
              icon: const Icon(Icons.movie_creation_outlined),
              label: const Text('Render MP4'),
            ),
          ),
        ),
      ],
    );
  }
}
