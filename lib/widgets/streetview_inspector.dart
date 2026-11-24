import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../features/streetview_3d/data/open_orbit_map.dart';
import '../features/streetview_3d/data/orbit_location_defaults.dart';
import '../features/streetview_3d/data/photo_walk.dart';
import '../features/streetview_3d/presentation/orbit_capture.dart';
import '../features/streetview_3d/presentation/orbit_coverage.dart';
import '../model/maps_web_result.dart';
import '../model/project.dart';
import '../model/streetview_layout.dart';
import '../pages/maps_web_header_page.dart';
import '../pages/maps_web_search_page.dart';
import '../services/media_edits.dart';
import '../services/project_store.dart';
import 'editor_section_card.dart';
import 'media_edits_editor.dart';
import 'place_actions_editor.dart';
import 'streetview_chrome.dart';

class StreetviewInspector extends StatefulWidget {
  final ReelProject project;
  final ReelClip clip;
  final ProjectStore store;
  final VoidCallback onSettings;
  final VoidCallback onChanged;
  const StreetviewInspector({
    super.key,
    required this.project,
    required this.clip,
    required this.store,
    required this.onSettings,
    required this.onChanged,
  });
  @override
  State<StreetviewInspector> createState() => _StreetviewInspectorState();
}

enum _InspectorTask { captureMap, preparePhoto }

class _StreetviewInspectorState extends State<StreetviewInspector> {
  _InspectorTask? _task;
  bool get _busy => _task != null;
  int _revision = 0;
  StreetviewMedia get _s => widget.clip.streetview;
  Future<void> _move(String move) async {
    final clip = widget.clip;
    if (move == 'hold' || clip.streetview.walkLayers.length == 3) {
      clip.streetview.walkMove = move;
      widget.onChanged();
      return;
    }
    final stamp = EditedMedia.stamp(clip);
    setState(() => _task = _InspectorTask.preparePhoto);
    try {
      final walk = await PhotoWalk.prepare(clip, widget.store.root!);
      if (!mounted || widget.clip != clip || EditedMedia.stamp(clip) != stamp) {
        for (final path in walk.layers) {
          await File(path).delete();
        }
        return;
      }
      clip.streetview.walkLayers = walk.layers;
      clip.streetview.walkDepth = walk.depth;
      clip.streetview.walkMove = move;
      widget.onChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not prepare photo: $e')));
      }
    } finally {
      if (mounted) setState(() => _task = null);
    }
  }

  Future<void> _location() async {
    final clip = widget.clip;
    final value = await Navigator.of(context).push<MapsWebImport>(
      MaterialPageRoute(
        builder: (_) => MapsWebSearchPage(initial: _s.place.name),
      ),
    );
    if (value == null || !mounted || widget.clip != clip) return;
    await _capture(replacement: value.place);
  }

  Future<void> _capture({PlaceDetails? replacement}) async {
    if (_busy || (replacement == null && !_s.canCaptureMap)) return;
    final clip = widget.clip;
    final original = _s.place;
    final place = replacement ?? PlaceDetails.fromJson(original.toJson());
    final orbit = widget.project.isStreetview3d;
    setState(() => _task = _InspectorTask.captureMap);
    File? pending;
    try {
      late final List<int> bytes;
      String? coverage;
      if (orbit) {
        final result = await captureOrbit(context, place);
        if (result == null) return;
        coverage = result.coverage;
        bytes = result.bytes;
      } else {
        final png = await Navigator.of(context).push<Uint8List>(
          MaterialPageRoute(
            builder: (_) => MapsWebHeaderPage(
              place: place,
              aspectRatio: 360 / StreetviewLayout.mapHeight,
              showHeaderGuide: false,
            ),
          ),
        );
        if (png == null) return;
        bytes = png;
      }
      if (!mounted || widget.clip != clip || _s.place != original) return;
      final name = orbit
          ? 'orbit-${newId()}.json'
          : 'streetview-${newId()}.png';
      pending = await widget.store.writeMapAsset(name, bytes);
      if (!mounted || widget.clip != clip || _s.place != original) return;

      if (replacement != null) {
        _s.place = place;
        _s.locationOrigin = '';
        _s.locationSelected = true;
        _revision++;
      } else {
        original.latitude = place.latitude;
        original.longitude = place.longitude;
      }
      _s.mapPath = pending.path;
      pending = null;
      if (orbit) {
        OrbitLocationDefaults.inherit(widget.project.clips);
        widget.project.streetview.adoptClipLocations(widget.project.clips);
      }
      widget.onChanged();
      if (coverage != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(coverage)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not capture map: $e')));
      }
    } finally {
      if (mounted) setState(() => _task = null);
      if (pending != null && await pending.exists()) await pending.delete();
    }
  }

  Widget _field(String label, String value, ValueChanged<String> change) =>
      TextFormField(
        key: ValueKey('${widget.clip.id}-$label-$_revision'),
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        onChanged: (v) {
          change(v);
          widget.onChanged();
        },
      );
  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> change,
  ) => EditorSlider(
    label: label,
    valueLabel: '${value.toStringAsFixed(2)}s',
    value: value,
    min: min,
    max: max,
    onChanged: (v) {
      change(v);
      widget.onChanged();
    },
  );
  Widget _amount(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> change, {
    bool percent = false,
  }) => EditorSlider(
    label: label,
    valueLabel:
        '${(percent ? value * 100 : value).toStringAsFixed(1)}${percent ? '%' : '°'}',
    value: value,
    min: min,
    max: max,
    onChanged: (v) {
      change(v);
      widget.onChanged();
    },
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
      if (!widget.project.isStreetview3d ||
          widget.project.streetview.locationFor(widget.clip) == null)
        EditorSectionCard(
          title: const Text('Media location'),
          subtitle: const Text('Location and captured map for this media'),
          children: [
            FilledButton.icon(
              onPressed: _busy ? null : _location,
              icon: const Icon(Icons.search),
              label: const Text('Select this media’s location'),
            ),
            if (widget.project.isStreetview3d)
              TextButton.icon(
                onPressed: _busy ? null : widget.onSettings,
                icon: const Icon(Icons.key),
                label: const Text('Google 3D tile settings'),
              ),
            if (widget.project.isStreetview3d)
              TextButton.icon(
                icon: const Icon(Icons.location_city),
                label: const Text('Use Tokyo Station'),
                onPressed: _busy
                    ? null
                    : () => _capture(
                        replacement: PlaceDetails(
                          name: 'Tokyo Station',
                          address: 'Marunouchi, Tokyo',
                          latitude: OpenOrbitMap.tokyoLat,
                          longitude: OpenOrbitMap.tokyoLon,
                        ),
                      ),
              ),
            if (_s.canCaptureMap || _task == _InspectorTask.captureMap)
              TextButton.icon(
                onPressed: _busy ? null : _capture,
                icon: const Icon(Icons.map_outlined),
                label: Text(
                  _task == _InspectorTask.captureMap
                      ? 'Capturing…'
                      : _s.mapPath == null
                      ? 'Capture map'
                      : 'Replace captured map',
                ),
              ),
            if (widget.project.isStreetview3d &&
                _s.place.latitude != null &&
                _s.place.longitude != null)
              Text(
                [
                  if (_s.locationOrigin == 'media')
                    'Media GPS'
                  else if (_s.locationOrigin == 'previous')
                    'Previous media'
                  else
                    'Selected pin',
                  '${_s.place.latitude!.toStringAsFixed(5)}, ${_s.place.longitude!.toStringAsFixed(5)}',
                ].join(' · '),
              ),
            if (widget.project.isStreetview3d && _s.mapPath != null)
              OrbitCoverage(path: _s.mapPath!),
            _field('Place name', _s.place.name, (v) => _s.place.name = v),
            _field('Address', _s.place.address, (v) => _s.place.address = v),
          ],
        ),
      if (!widget.project.isStreetview3d)
        EditorSectionCard(
          title: const Text('Map place details and buttons'),
          subtitle: const Text('Place information and rendered actions'),
          children: [
            _field('Category', _s.place.category, (v) => _s.place.category = v),
            _field('Rating', _s.place.rating, (v) => _s.place.rating = v),
            PlaceActionsEditor(
              key: ValueKey(_revision),
              place: _s.place,
              embedded: true,
              suggestedActions: StreetviewPlaceSheet.actions(
                _s.place,
                map: true,
              ),
              onChanged: widget.onChanged,
            ),
          ],
        ),
      MediaEditsEditor(
        key: ValueKey('effects-${widget.clip.id}'),
        clip: widget.clip,
        onChanged: () {
          if (widget.project.isStreetview3d) {
            _s.walkLayers = [];
            _s.walkDepth = [];
            _s.walkMove = 'hold';
          }
          widget.onChanged();
        },
      ),
      EditorSectionCard(
        title: const Text('Transition to next media'),
        subtitle: Text(
          widget.project.isStreetview3d && _s.transition == 'arrow'
              ? 'The camera moves toward the next location.'
              : 'How this media leads into the next',
        ),
        children: [
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _s.transition,
            decoration: const InputDecoration(labelText: 'Transition type'),
            items: [
              DropdownMenuItem(
                value: 'arrow',
                child: Text(
                  widget.project.isStreetview3d
                      ? 'Dolly to next location'
                      : 'Arrow movement',
                ),
              ),
              const DropdownMenuItem(
                value: 'map',
                child: Text('Return to Maps'),
              ),
            ],
            onChanged: (v) {
              _s.transition = v!;
              widget.onChanged();
            },
          ),
          if (_s.transition == 'arrow') ...[
            DropdownButtonFormField<String>(
              isExpanded: true,
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
        ],
      ),
      if (widget.project.isStreetview3d && !widget.clip.isTimed)
        EditorSectionCard(
          title: const Text('Photo walkthrough'),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final move in const {
                  'hold': 'Hold still',
                  'left': 'Step left',
                  'right': 'Step right',
                  'forward': 'Walk forward',
                }.entries)
                  ChoiceChip(
                    label: Text(move.value),
                    selected: _s.walkMove == move.key,
                    onSelected: _busy ? null : (_) => _move(move.key),
                  ),
              ],
            ),
            if (_task == _InspectorTask.preparePhoto) ...[
              const LinearProgressIndicator(),
              const Text('Preparing photo walkthrough…'),
            ] else if (_s.walkLayers.isEmpty)
              const Text(
                'Choosing a move prepares this photo on your phone. First use downloads a 64 MB depth model.',
              ),
          ],
        ),
      if (!widget.project.isStreetview3d)
        EditorSectionCard(
          title: const Text('Camera motion'),
          subtitle: const Text('Movement for this media'),
          children: [
            _switch('Slow zoom', _s.slowZoom, (v) => _s.slowZoom = v),
            if (_s.slowZoom)
              _amount(
                'Zoom amount',
                _s.zoomAmount,
                0,
                .2,
                (v) => _s.zoomAmount = v,
                percent: true,
              ),
            _switch('Slow pan', _s.slowPan, (v) => _s.slowPan = v),
            if (_s.slowPan)
              _amount(
                'Pan distance',
                _s.panAmount,
                -.08,
                .08,
                (v) => _s.panAmount = v,
                percent: true,
              ),
            _switch('Slow turntable', _s.turntable, (v) => _s.turntable = v),
            if (_s.turntable) ...[
              _amount(
                'Turn angle',
                _s.turntableDegrees,
                0,
                15,
                (v) => _s.turntableDegrees = v,
              ),
              _switch(
                'Reverse turn direction',
                _s.turntableReverse,
                (v) => _s.turntableReverse = v,
              ),
            ],
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Camera movements carry the navigation arrows with the scene.',
              ),
            ),
          ],
        ),
      EditorSectionCard(
        title: Text(
          widget.project.isStreetview3d
              ? 'Orbit labels and controls'
              : 'Street View overlays',
        ),
        subtitle: const Text('Labels and visibility for this media'),
        children: [
          _field('Capture date / age', _s.date, (v) => _s.date = v),
          _field(
            'Street View place title',
            _s.streetviewTitle,
            (v) => _s.streetviewTitle = v,
          ),
          if (!widget.project.isStreetview3d) ...[
            _field('View badge', _s.aerialLabel, (v) => _s.aerialLabel = v),
            _field('Nearby label', _s.nearbyLabel, (v) => _s.nearbyLabel = v),

            _field(
              'Source attribution',
              _s.attribution,
              (v) => _s.attribution = v,
            ),
          ],
          _switch('Top controls', _s.showControls, (v) => _s.showControls = v),
          _switch('Navigation arrows', _s.showArrows, (v) => _s.showArrows = v),
          _switch(
            widget.project.isStreetview3d ? 'Location label' : 'Place sheet',
            _s.showLocation,
            (v) => _s.showLocation = v,
          ),
        ],
      ),
      EditorSectionCard(
        title: const Text('Journey timing and ending'),
        subtitle: const Text('Applies to the whole journey'),
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
