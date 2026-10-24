import 'package:flutter/material.dart';
import '../model/feed.dart';
import 'home_app_icon.dart';

class HomeAppsEditor extends StatefulWidget {
  final FeedSettings settings;
  final VoidCallback onChanged;
  const HomeAppsEditor({
    super.key,
    required this.settings,
    required this.onChanged,
  });
  @override
  State<HomeAppsEditor> createState() => _HomeAppsEditorState();
}

class _HomeAppsEditorState extends State<HomeAppsEditor> {
  int _selected = 0;
  bool _dock = false;
  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    final apps = _dock ? s.homeDock : s.homeApps;
    _selected = _selected.clamp(0, apps.length - 1);
    final app = apps[_selected];
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: const Text('Home apps & dock'),
      subtitle: Text(
        '${s.homeApps.length} grid slots · ${s.homeDock.length} dock apps',
      ),
      children: [
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          key: ValueKey('launch-${s.homeOs.name}-${s.launchSlot}'),
          initialValue: s.launchSlot,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Feed launch tile'),
          items: [
            for (var i = 0; i < s.homeApps.length; i++)
              DropdownMenuItem(
                value: i,
                child: Text(
                  '${i + 1}. ${s.homeApps[i].label.isEmpty ? 'Empty slot' : s.homeApps[i].label}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (i) {
            if (i == null) return;
            s.moveLaunch(i);
            _selected = i;
            _dock = false;
            setState(() {});
            widget.onChanged();
          },
        ),
        const SizedBox(height: 8),
        const Text(
          'Moves the feed app to this tile; the opening and closing animations follow it.',
          style: TextStyle(fontSize: 11, color: Colors.white54),
        ),
        const SizedBox(height: 16),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('App grid')),
            ButtonSegment(value: true, label: Text('Dock')),
          ],
          selected: {_dock},
          onSelectionChanged: (v) => setState(() {
            _dock = v.first;
            _selected = 0;
          }),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<int>(
          key: ValueKey('home-app-select-$_dock-$_selected-${s.launchSlot}'),
          initialValue: _selected,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Edit app'),
          items: [
            for (var i = 0; i < apps.length; i++)
              DropdownMenuItem(
                value: i,
                child: Text(
                  '${i + 1}. ${apps[i].label.isEmpty ? 'Empty slot' : apps[i].label}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (i) {
            if (i != null) setState(() => _selected = i);
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: HomeAppIcon(glyph: app.glyph, os: s.homeOs, date: s.date),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                key: ValueKey(
                  'label-${s.homeOs.name}-$_dock-$_selected-${s.launchSlot}',
                ),
                initialValue: app.label,
                maxLength: 18,
                decoration: const InputDecoration(
                  labelText: 'App label',
                  counterText: '',
                ),
                onChanged: (v) {
                  app.label = v;
                  widget.onChanged();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<HomeGlyph>(
          key: ValueKey(
            'glyph-${s.homeOs.name}-$_dock-$_selected-${s.launchSlot}',
          ),
          initialValue: app.glyph,
          decoration: const InputDecoration(labelText: 'App icon'),
          items: [
            for (final glyph in HomeGlyph.values)
              DropdownMenuItem(value: glyph, child: Text(_label(glyph))),
          ],
          onChanged: (glyph) {
            if (glyph != null) {
              app.glyph = glyph;
              widget.onChanged();
            }
          },
        ),
        if (!_dock)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Leave a label blank to hide a grid tile. The launch tile stays visible.',
              style: TextStyle(fontSize: 11, color: Colors.white54),
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }

  String _label(HomeGlyph glyph) => switch (glyph) {
    HomeGlyph.appStore => 'App Store',
    HomeGlyph.playStore => 'Play Store',
    HomeGlyph.itunes => 'iTunes Store',
    HomeGlyph.books => 'iBooks',
    HomeGlyph.tiktok => 'TikTok',
    _ => glyph.name[0].toUpperCase() + glyph.name.substring(1),
  };
}
