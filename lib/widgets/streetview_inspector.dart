import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../model/project.dart';
import '../model/maps_web_result.dart';
import '../pages/maps_web_search_page.dart';
import '../pages/maps_web_header_page.dart';
import '../services/project_store.dart';
import 'place_actions_editor.dart';
import 'media_edits_editor.dart';

class StreetviewInspector extends StatefulWidget {
  final ReelProject project;
  final ReelClip clip;
  final ProjectStore store;
  final VoidCallback onChanged;
  const StreetviewInspector({
    super.key,
    required this.project,
    required this.clip,
    required this.store,
    required this.onChanged,
  });
  @override
  State<StreetviewInspector> createState() => _StreetviewInspectorState();
}

class _StreetviewInspectorState extends State<StreetviewInspector> {
  bool _busy = false;
  int _revision = 0;
  StreetviewMedia get _s => widget.clip.streetview;
  Future<void> _location() async {
    final value = await Navigator.of(context).push<MapsWebImport>(
      MaterialPageRoute(
        builder: (_) => MapsWebSearchPage(initial: _s.place.name),
      ),
    );
    if (value == null || !mounted) return;
    _revision++;
    _s.place = value.place;
    _s.locationSelected = true;
    _s.mapPath = null;
    widget.onChanged();
    await _capture();
  }

  Future<void> _capture() async {
    if (_busy || !_s.canCaptureMap) return;
    setState(() => _busy = true);
    try {
      final bytes = await Navigator.of(context).push<Uint8List>(
        MaterialPageRoute(
          builder: (_) => MapsWebHeaderPage(
            place: _s.place,
            aspectRatio: 360 / 370,
            showHeaderGuide: false,
          ),
        ),
      );
      if (bytes == null || !mounted) return;
      final file = File(
        '${widget.store.root!.path}/media/streetview-${newId()}.png',
      );
      await file.writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      _s.mapPath = file.path;
      widget.onChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not capture map: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(String label, String value, ValueChanged<String> change) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: TextFormField(
          key: ValueKey('${widget.clip.id}-$label-$_revision'),
          initialValue: value,
          decoration: InputDecoration(labelText: label),
          onChanged: (v) {
            change(v);
            widget.onChanged();
          },
        ),
      );
  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> change,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('$label · ${value.toStringAsFixed(2)}s'),
      Slider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        onChanged: (v) {
          change(v);
          widget.onChanged();
        },
      ),
    ],
  );
  Widget _switch(String label, bool value, ValueChanged<bool> change) =>
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        value: value,
        onChanged: (v) {
          change(v);
          widget.onChanged();
        },
      );
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      FilledButton.icon(
        onPressed: _busy ? null : _location,
        icon: const Icon(Icons.search),
        label: const Text('Select this media’s location'),
      ),
      if (_s.canCaptureMap)
        TextButton.icon(
          onPressed: _busy ? null : _capture,
          icon: const Icon(Icons.map_outlined),
          label: Text(
            _busy
                ? 'Capturing…'
                : _s.mapPath == null
                ? 'Capture map'
                : 'Replace captured map',
          ),
        ),
      _field('Place name', _s.place.name, (v) => _s.place.name = v),
      _field('Address', _s.place.address, (v) => _s.place.address = v),
      MediaEditsEditor(
        key: ValueKey('effects-${widget.clip.id}'),
        clip: widget.clip,
        onChanged: widget.onChanged,
      ),
      ExpansionTile(
        title: const Text('Map place details and buttons'),
        children: [
          _field('Category', _s.place.category, (v) => _s.place.category = v),
          _field('Rating', _s.place.rating, (v) => _s.place.rating = v),
          PlaceActionsEditor(
            key: ValueKey(_revision),
            place: _s.place,
            onChanged: widget.onChanged,
          ),
        ],
      ),
      const Divider(),
      const Text('Transition to next media'),
      DropdownButtonFormField<String>(
        initialValue: _s.transition,
        items: const [
          DropdownMenuItem(value: 'arrow', child: Text('Arrow movement')),
          DropdownMenuItem(value: 'map', child: Text('Return to Maps')),
        ],
        onChanged: (v) {
          _s.transition = v!;
          widget.onChanged();
        },
      ),
      if (_s.transition == 'arrow') ...[
        DropdownButtonFormField<String>(
          initialValue: _s.arrow,
          decoration: const InputDecoration(labelText: 'Navigation arrow'),
          items: const [
            DropdownMenuItem(value: 'left', child: Text('Left')),
            DropdownMenuItem(value: 'right', child: Text('Right')),
          ],
          onChanged: (v) {
            _s.arrow = v!;
            widget.onChanged();
          },
        ),
      ],
      _slider(
        _s.transition == 'arrow'
            ? 'Movement including tap'
            : 'Back control including tap',
        _s.transitionSeconds,
        .2,
        2,
        (v) => _s.transitionSeconds = v,
      ),
      _switch('Slow pan / zoom', _s.panZoom, (v) => _s.panZoom = v),
      ExpansionTile(
        title: const Text('Street View overlays'),
        children: [
          _field('Capture date / age', _s.date, (v) => _s.date = v),
          _field('Copyright', _s.copyright, (v) => _s.copyright = v),
          _field(
            'More dates label',
            _s.moreDatesLabel,
            (v) => _s.moreDatesLabel = v,
          ),
          _field(
            'Source attribution',
            _s.attribution,
            (v) => _s.attribution = v,
          ),
          _switch('Top controls', _s.showControls, (v) => _s.showControls = v),
          _switch('Navigation arrows', _s.showArrows, (v) => _s.showArrows = v),
          _switch(
            'Location and date card',
            _s.showLocation,
            (v) => _s.showLocation = v,
          ),
        ],
      ),
      ExpansionTile(
        title: const Text('Journey timing and ending'),
        children: [
          _slider(
            'Opening map',
            widget.project.streetview.openingMapSeconds,
            .5,
            30,
            (v) => widget.project.streetview.openingMapSeconds = v,
          ),
          _slider(
            'Later map screens',
            widget.project.streetview.laterMapSeconds,
            .5,
            30,
            (v) => widget.project.streetview.laterMapSeconds = v,
          ),
          _switch(
            'End by returning to the last map',
            widget.project.streetview.endOnMap,
            (v) => widget.project.streetview.endOnMap = v,
          ),
        ],
      ),
    ],
  );
}
