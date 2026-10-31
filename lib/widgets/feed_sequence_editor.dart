import 'package:flutter/material.dart';
import '../model/feed.dart';
import '../model/project.dart';
import 'editor_section_card.dart';
import 'home_apps_editor.dart';

class FeedSequenceEditor extends StatelessWidget {
  final ReelProject project;
  final bool busy;
  final VoidCallback onPickHome;
  final VoidCallback onChanged;

  const FeedSequenceEditor({
    super.key,
    required this.project,
    required this.busy,
    required this.onPickHome,
    required this.onChanged,
  });

  ReelFeed get feed => project.feed;

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
      key: ValueKey('feed-seq-$label-${project.id}'),
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

  @override
  Widget build(BuildContext context) {
    final muted = _mutedStyle(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        EditorSectionCard(
          title: const Text('Opening scene'),
          children: [
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'search', label: Text('Search')),
                ButtonSegment(value: 'home', label: Text('Home screen')),
                ButtonSegment(value: 'feed', label: Text('Feed')),
              ],
              selected: {feed.opening},
              onSelectionChanged: (s) {
                feed.opening = s.first;
                onChanged();
              },
            ),
            const SizedBox(height: 18),
            if (feed.opening == 'search') ...[
              _field(
                'Search query',
                feed.search,
                (v) => feed.search = v,
                max: 100,
              ),
              Text(
                'Leave empty to start directly in the feed.',
                style: muted,
              ),
              const SizedBox(height: 16),
              _slider(
                'Typing',
                feed.typingSeconds,
                .5,
                6,
                (v) => feed.typingSeconds = v,
              ),
              _slider(
                'Loading',
                feed.loadingSeconds,
                .2,
                3,
                (v) => feed.loadingSeconds = v,
              ),
            ],
            if (feed.opening == 'home')
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'The home screen holds, then the app opens into your first post.',
                  style: muted,
                ),
              ),
          ],
        ),
        EditorSectionCard(
          title: const Text('Feed transitions'),
          children: [
            _slider(
              'Swipe duration',
              project.slideSeconds,
              .15,
              .8,
              (v) => project.slideSeconds = v,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Close app to home screen'),
              subtitle: const Text(
                'Shrink the last post back into the app icon.',
              ),
              value: feed.closeToHome,
              onChanged: (v) {
                feed.closeToHome = v;
                onChanged();
              },
            ),
          ],
        ),
        EditorSectionCard(
          title: const Text('Home screen & status bar'),
          children: [
            const SizedBox(height: 12),
            DropdownButtonFormField<HomeOs>(
              isExpanded: true,
              initialValue: feed.homeOs,
              decoration: const InputDecoration(labelText: 'Home screen OS'),
              items: [
                for (final os in HomeOs.values)
                  DropdownMenuItem(
                    value: os,
                    child: Text(
                      os.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (os) {
                if (os != null) {
                  feed.homeOs = os;
                  onChanged();
                }
              },
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Show mock app icons'),
              subtitle: const Text(
                'Includes the dock and launcher navigation. Turn off for screenshots that already have icons.',
              ),
              value: feed.showIcons,
              onChanged: (v) {
                feed.showIcons = v;
                onChanged();
              },
            ),
            if (feed.homeOs == HomeOs.android || feed.homeOs == HomeOs.pixel)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  feed.homeOs == HomeOs.pixel
                      ? 'Show date'
                      : 'Show home clock & date',
                ),
                value: feed.showClock,
                onChanged: (v) {
                  feed.showClock = v;
                  onChanged();
                },
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Show home status bar'),
              value: feed.showStatus,
              onChanged: (v) {
                feed.showStatus = v;
                onChanged();
              },
            ),
            if (feed.homeOs != HomeOs.iphone)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  feed.homeOs == HomeOs.pixel
                      ? 'Show weather'
                      : 'Show home widgets',
                ),
                value: feed.showWidget,
                onChanged: (v) {
                  feed.showWidget = v;
                  onChanged();
                },
              ),
            _field(
              'Status bar time',
              feed.time,
              (v) => feed.time = v,
              max: 8,
            ),
            _field('Date', feed.date, (v) => feed.date = v, max: 50),
            if (feed.homeOs == HomeOs.iphone) ...[
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: feed.iphonePeriod,
                decoration: const InputDecoration(
                  labelText: 'Status bar time period',
                ),
                items: const [
                  DropdownMenuItem(value: 'AM', child: Text('AM')),
                  DropdownMenuItem(value: 'PM', child: Text('PM')),
                  DropdownMenuItem(
                    value: '',
                    child: Text('24-hour / no suffix'),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) {
                    feed.iphonePeriod = v;
                    onChanged();
                  }
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Classic iOS uses a full app grid and the status-bar clock, with no large clock or dashboard widgets.',
                  style: muted,
                ),
              ),
            ],
            if (feed.homeOs == HomeOs.pixel || feed.homeOs == HomeOs.oneUi)
              _field(
                'Weather temperature',
                feed.weatherTemperature,
                (v) => feed.weatherTemperature = v,
                max: 8,
              ),
            if (feed.homeOs == HomeOs.oneUi) ...[
              _field(
                'Weather location',
                feed.weatherLocation,
                (v) => feed.weatherLocation = v,
                max: 40,
              ),
              _field(
                'Briefing pill',
                feed.briefTitle,
                (v) => feed.briefTitle = v,
                max: 30,
              ),
              _field(
                'Health pill',
                feed.healthTitle,
                (v) => feed.healthTitle = v,
                max: 30,
              ),
            ],

            if (feed.homeOs == HomeOs.android)
              _field(
                'Widget title',
                feed.widgetTitle,
                (v) => feed.widgetTitle = v,
                max: 70,
              ),
            if (feed.homeOs == HomeOs.android)
              _field(
                'Widget note',
                feed.widgetText,
                (v) => feed.widgetText = v,
                max: 80,
              ),
            _slider(
              'Home screen hold',
              feed.homeSeconds,
              .5,
              6,
              (v) => feed.homeSeconds = v,
            ),
            OutlinedButton.icon(
              onPressed: busy ? null : onPickHome,
              icon: const Icon(Icons.wallpaper),
              label: Text(
                feed.homeMedia == null
                    ? 'Choose home photo / video'
                    : 'Replace home photo / video',
              ),
            ),
            if (feed.homeMedia != null)
              TextButton.icon(
                onPressed: () {
                  feed.showIcons = false;
                  feed.showClock = false;
                  feed.showWidget = false;
                  feed.showStatus = false;
                  onChanged();
                },
                icon: const Icon(Icons.layers_clear_outlined),
                label: const Text('Use media without overlays'),
              ),
            if (feed.homeMedia != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  feed.homeMedia!.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  feed.homeMedia!.isTimed
                      ? 'Animated wallpaper · loops to fit'
                      : 'Photo wallpaper',
                ),
                trailing: IconButton(
                  tooltip: 'Remove home media',
                  onPressed: () {
                    feed.homeMedia = null;
                    onChanged();
                  },
                  icon: const Icon(Icons.close),
                ),
              ),
            if (feed.homeOs != HomeOs.android)
              HomeAppsEditor(
                key: ValueKey(feed.homeOs),
                settings: feed,
                onChanged: onChanged,
              )
            else
              EditorControlGroup(
                title: const Text('App labels'),
                subtitle: const Text(
                  'Eight generic tiles; the fourth opens the feed.',
                ),
                children: [
                  for (var i = 0; i < 8; i++)
                    _field(
                      'App ${i + 1}',
                      i < feed.appLabels.length ? feed.appLabels[i] : 'App',
                      (v) {
                        while (feed.appLabels.length < 8) {
                          feed.appLabels.add('App');
                        }
                        feed.appLabels[i] = v;
                      },
                      max: 16,
                    ),
                  for (var i = 0; i < 8; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: DropdownButtonFormField<int>(
                        isExpanded: true,
                        key: ValueKey('app-icon-$i'),
                        initialValue: i < feed.appIcons.length
                            ? feed.appIcons[i]
                            : i,
                        decoration: InputDecoration(
                          labelText: 'App ${i + 1} icon',
                        ),
                        items: [
                          for (var n = 0; n < 12; n++)
                            DropdownMenuItem(
                              value: n,
                              child: Text(
                                const [
                                  'Photos',
                                  'Camera',
                                  'Notes',
                                  'Music note',
                                  'Weather',
                                  'Sound',
                                  'Messages',
                                  'Settings',
                                  'Map',
                                  'Mail',
                                  'Clock',
                                  'Video',
                                ][n],
                              ),
                            ),
                        ],
                        onChanged: (n) {
                          if (n == null) return;
                          while (feed.appIcons.length < 8) {
                            feed.appIcons.add(feed.appIcons.length);
                          }
                          feed.appIcons[i] = n;
                          onChanged();
                        },
                      ),
                    ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
