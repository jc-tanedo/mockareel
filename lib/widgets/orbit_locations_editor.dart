import 'package:flutter/material.dart';
import '../model/project.dart';
import '../pages/maps_web_search_page.dart';
import '../services/open_orbit_map.dart';
import '../services/project_store.dart';
import 'editor_section_card.dart';
import 'orbit_capture.dart';
import 'orbit_map.dart';
import 'orbit_location_picker.dart';
import 'output_theme_picker.dart';

class OrbitLocationsEditor extends StatefulWidget {
  final ReelProject project;
  final ProjectStore store;
  final OrbitLocation? selected;
  final ValueChanged<OrbitLocation?> onSelect;
  final ValueChanged<OrbitLocation> onPickClips;
  final VoidCallback onSettings, onChanged, onUseGps;
  final bool importing;
  const OrbitLocationsEditor({
    super.key,
    required this.project,
    required this.store,
    required this.selected,
    required this.onSelect,
    required this.onPickClips,
    required this.onUseGps,
    required this.onSettings,
    required this.onChanged,
    required this.importing,
  });

  @override
  State<OrbitLocationsEditor> createState() => _OrbitLocationsEditorState();
}

class _OrbitLocationsEditorState extends State<OrbitLocationsEditor> {
  bool _capturing = false;
  bool get _busy => _capturing || widget.importing;
  List<OrbitLocation> get locations => widget.project.streetview.locations;

  void _add(PlaceDetails place) {
    final location = OrbitLocation(place: place);
    locations.add(location);
    widget.onSelect(location);
    widget.onChanged();
  }

  Future<void> _search({OrbitLocation? replace}) async {
    final value = await MapsWebSearchPage.search(
      context,
      initial: replace?.label ?? '',
    );
    if (!mounted || value == null) return;
    if (replace == null) {
      _add(value.place);
    } else if (replace.mapPath == null) {
      replace.place = value.place;
      _updateClips(replace);
    } else {
      await _capture(replace, replacement: value.place);
    }
  }

  void _updateClips(OrbitLocation location) {
    for (final c in widget.project.clips.where(
      (c) => c.streetview.locationId == location.id,
    )) {
      location.assign(c);
    }
    widget.onChanged();
  }

  Future<void> _capture(
    OrbitLocation location, {
    PlaceDetails? replacement,
  }) async {
    if (_busy) return;
    setState(() => _capturing = true);
    try {
      final place =
          replacement ?? PlaceDetails.fromJson(location.place.toJson());
      final result = await captureOrbit(context, place);
      if (!mounted || result == null) return;
      final file = await writeMapAsset(
        widget.store,
        'orbit-${newId()}.json',
        result.bytes,
      );
      if (!mounted || !locations.contains(location)) {
        await file.delete();
        return;
      }
      location.place = place;
      location.mapPath = file.path;
      _updateClips(location);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.coverage)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not capture map: $e')));
      }
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Widget _field(
    OrbitLocation location,
    String label,
    String value,
    ValueChanged<String> change,
  ) => TextFormField(
    key: ValueKey((location.id, location.place, label)),
    enabled: !_busy,
    initialValue: value,
    decoration: InputDecoration(labelText: label),
    onChanged: (v) {
      change(v);
      _updateClips(location);
    },
  );

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final clips = widget.project.clips.where(
      (c) => c.streetview.locationId == selected?.id,
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                EditorSectionCard(
                  title: const Text('Journey locations'),
                  children: [
                    if (selected != null)
                      OrbitLocationPicker(
                        locations: locations,
                        selected: selected,
                        label: 'Selected location',
                        onChanged: _busy ? null : widget.onSelect,
                      ),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: _busy ? null : () => _search(),
                          icon: const Icon(Icons.add_location_alt_outlined),
                          label: const Text('Add location'),
                        ),
                        if (locations.isEmpty)
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => _add(
                                    PlaceDetails(
                                      name: 'Tokyo Station',
                                      address: 'Marunouchi, Tokyo',
                                      latitude: OpenOrbitMap.tokyoLat,
                                      longitude: OpenOrbitMap.tokyoLon,
                                    ),
                                  ),
                            child: const Text('Use Tokyo Station'),
                          ),
                      ],
                    ),
                  ],
                ),
                if (selected != null)
                  EditorSectionCard(
                    title: Text(selected.label),
                    subtitle: Text(
                      clips.isEmpty
                          ? 'No clips here yet'
                          : '${clips.length} ${clips.length == 1 ? 'clip' : 'clips'} · ${clips.first.name}${clips.length > 1 ? '…' : ''}',
                    ),
                    children: [
                      FilledButton.icon(
                        onPressed: _busy
                            ? null
                            : () => widget.onPickClips(selected),
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                        label: Text(
                          widget.importing
                              ? 'Importing clips…'
                              : 'Add clips here',
                        ),
                      ),
                      if (selected.mapPath case final path?)
                        SizedBox(
                          height: 170,
                          child: ClipRect(
                            child: OrbitMap(
                              key: ValueKey(path),
                              path: path,
                              progress: 0,
                              dark: widget.project.darkOutput,
                            ),
                          ),
                        ),
                      Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _busy ? null : () => _capture(selected),
                            icon: const Icon(Icons.map_outlined),
                            label: Text(
                              _capturing
                                  ? 'Capturing…'
                                  : selected.mapPath == null
                                  ? 'Capture map'
                                  : 'Replace captured map',
                            ),
                          ),
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => _search(replace: selected),
                            child: const Text('Change location'),
                          ),
                          if (clips.isEmpty)
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () {
                                      locations.remove(selected);
                                      widget.onSelect(locations.firstOrNull);
                                      widget.onChanged();
                                    },
                              child: const Text('Remove location'),
                            ),
                        ],
                      ),
                      _field(
                        selected,
                        'Place name',
                        selected.place.name,
                        (v) => selected.place.name = v,
                      ),
                      _field(
                        selected,
                        'Address',
                        selected.place.address,
                        (v) => selected.place.address = v,
                      ),
                    ],
                  ),
                if (locations.isEmpty)
                  TextButton.icon(
                    onPressed: _busy ? null : widget.onUseGps,
                    icon: const Icon(Icons.my_location),
                    label: const Text('Use locations from media GPS'),
                  ),
                OutputThemePicker(
                  project: widget.project,
                  onChanged: widget.onChanged,
                ),
                TextButton.icon(
                  onPressed: _busy ? null : widget.onSettings,
                  icon: const Icon(Icons.key),
                  label: const Text('Google 3D tile settings'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
