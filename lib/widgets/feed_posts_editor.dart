import 'dart:io';
import 'package:flutter/material.dart';
import '../model/project.dart';
import 'editor_section_card.dart';
import 'editor_workspace.dart';

class FeedPostsEditor extends StatelessWidget {
  final ReelProject project;
  final int selectedIndex;
  final int postTool;
  final bool busy;
  final VoidCallback onPickMedia;
  final ValueChanged<int> onSelectPost;
  final ValueChanged<int> onSelectTool;
  final VoidCallback onRemovePost;
  final ValueChanged<int> onMovePost;
  final ValueChanged<ReelClip> onPickAvatar;
  final VoidCallback onChanged;

  const FeedPostsEditor({
    super.key,
    required this.project,
    required this.selectedIndex,
    required this.postTool,
    required this.busy,
    required this.onPickMedia,
    required this.onSelectPost,
    required this.onSelectTool,
    required this.onRemovePost,
    required this.onMovePost,
    required this.onPickAvatar,
    required this.onChanged,
  });

  TextStyle? _mutedStyle(BuildContext context) {
    final theme = Theme.of(context);
    return theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
  }

  Widget _field(
    String label,
    String value,
    ValueChanged<String> change, {
    int lines = 1,
    int max = 180,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      key: ValueKey('feed-post-$label-$selectedIndex-${project.id}'),
      initialValue: value,
      maxLength: max,
      maxLines: lines,
      decoration: InputDecoration(labelText: label, counterText: ''),
      onChanged: (v) {
        change(v);
        onChanged();
      },
    ),
  );

  Widget _slider(
    String label,
    double value,
    double lo,
    double hi,
    ValueChanged<double> change, {
    int precision = 1,
  }) => EditorSlider(
    label: label,
    valueLabel:
        '${value.toStringAsFixed(precision)}${label == 'Zoom' ? '×' : 's'}',
    value: value.clamp(lo, hi),
    min: lo,
    max: hi > lo ? hi : lo + .001,
    onChanged: (v) {
      change(v);
      onChanged();
    },
  );

  List<Widget> _postFields(BuildContext context, ReelClip c) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final post = c.post;
    return switch (postTool) {
      0 => [
        _field('Username', post.username, (v) => post.username = v, max: 40),
        Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: colors.secondaryContainer,
              foregroundColor: colors.onSecondaryContainer,
              backgroundImage: post.avatarPath != null
                  ? FileImage(File(post.avatarPath!))
                  : null,
              child: post.avatarPath == null ? const Icon(Icons.person) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: busy ? null : () => onPickAvatar(c),
                child: const Text('Choose profile photo'),
              ),
            ),
            if (post.avatarPath != null)
              IconButton(
                tooltip: 'Remove profile photo',
                onPressed: () {
                  post.avatarPath = null;
                  onChanged();
                },
                icon: const Icon(Icons.close),
              ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Verified badge'),
          value: post.verified,
          onChanged: (v) {
            post.verified = v;
            onChanged();
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Already following'),
          subtitle: const Text('Hide the follow plus on the profile photo.'),
          value: post.following,
          onChanged: (v) {
            post.following = v;
            onChanged();
          },
        ),
      ],
      1 => [
        _field(
          'Post title',
          post.title,
          (v) => post.title = v,
          lines: 2,
          max: 100,
        ),
        _field(
          'Caption & hashtags',
          post.caption,
          (v) => post.caption = v,
          lines: 4,
          max: 400,
        ),
        _field('Sound label', post.sound, (v) => post.sound = v, max: 80),
        Text(
          'The sound label is decorative. '
          'Choose actual background music in Audio.',
          style: _mutedStyle(context),
        ),
      ],
      2 => [
        _field('Likes', post.likes, (v) => post.likes = v, max: 12),
        _field('Comments', post.comments, (v) => post.comments = v, max: 12),
        _field('Saves', post.saves, (v) => post.saves = v, max: 12),
        _field('Shares', post.shares, (v) => post.shares = v, max: 12),
      ],
      _ => [
        _slider('Post duration', c.duration, c.minDuration, c.maxDuration, (v) {
          c.duration = v;
          c.normalize();
        }, precision: c.isGif ? 2 : 1),
        if (c.isGif)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Loop GIF'),
            subtitle: const Text(
              'Repeat the animation to fill the post duration',
            ),
            value: c.loopGif,
            onChanged: (v) {
              c.setGifLoop(v);
              onChanged();
            },
          ),
        if (c.isTimed && c.maxTrimStart > .001)
          _slider('Trim start', c.trimStart, 0, c.maxTrimStart, (v) {
            c.trimStart = v;
            c.normalize();
          }, precision: c.isGif ? 2 : 1),
        _slider('Zoom', c.zoom, 1, 3, (v) => c.zoom = v),
        Text('Horizontal crop', style: textTheme.bodySmall),
        Slider(
          value: c.panX,
          min: -1,
          max: 1,
          onChanged: (v) {
            c.panX = v;
            onChanged();
          },
        ),
        Row(
          children: [
            IconButton(
              tooltip: 'Move post earlier',
              onPressed: selectedIndex > 0 ? () => onMovePost(-1) : null,
              icon: const Icon(Icons.arrow_upward),
            ),
            IconButton(
              tooltip: 'Move post later',
              onPressed: selectedIndex < project.clips.length - 1
                  ? () => onMovePost(1)
                  : null,
              icon: const Icon(Icons.arrow_downward),
            ),
          ],
        ),
      ],
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${project.clips.length} posts',
                  style: textTheme.labelMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: busy ? null : onPickMedia,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add media'),
              ),
            ],
          ),
        ),
        if (project.clips.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    key: ValueKey(
                      'select-$selectedIndex-${project.clips.length}',
                    ),
                    initialValue: selectedIndex,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Selected post',
                      isDense: true,
                    ),
                    items: [
                      for (var i = 0; i < project.clips.length; i++)
                        DropdownMenuItem(
                          value: i,
                          child: Text(
                            '${i + 1}. ${project.clips[i].name}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (i) {
                      if (i != null) onSelectPost(i);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: busy ? null : onRemovePost,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Remove post'),
                ),
              ],
            ),
          ),
          InspectorTabs(
            labels: const ['Identity', 'Caption', 'Stats', 'Timing & frame'],
            selected: postTool,
            onSelected: onSelectTool,
          ),
          Expanded(
            child: ListView(
              key: ValueKey(
                'post-${project.clips[selectedIndex].id}-tool-$postTool',
              ),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
              children: _postFields(context, project.clips[selectedIndex]),
            ),
          ),
        ] else
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: colors.secondaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.swipe_up_outlined,
                          size: 30,
                          color: colors.onSecondaryContainer,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'One post per photo or video',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add your media, then edit the poster, '
                        'caption and counts for each post.',
                        textAlign: TextAlign.center,
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: busy ? null : onPickMedia,
                        icon: const Icon(Icons.add),
                        label: const Text('Add photos & videos'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
