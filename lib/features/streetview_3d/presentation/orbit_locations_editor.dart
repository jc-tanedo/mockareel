import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:mockareel/model/project.dart';
import 'package:mockareel/model/streetview_layout.dart';
import 'package:mockareel/model/streetview_timeline.dart';
import 'package:mockareel/pages/maps_web_header_page.dart';
import 'package:mockareel/pages/maps_web_search_page.dart';
import 'package:mockareel/services/project_store.dart';
import 'package:mockareel/widgets/editor_section_card.dart';
import 'package:mockareel/widgets/output_theme_picker.dart';
import '../data/open_orbit_map.dart';
import '../model/orbit_scene.dart';
import 'orbit_capture.dart';
import 'orbit_journey_canvas.dart';
import 'orbit_location_picker.dart';
import 'orbit_map.dart';

class OrbitLocationsEditor extends StatefulWidget {
  final ReelProject project;
  final ProjectStore store;
  final Future<String> Function(double, double) fetchGeometry;
  final OrbitLocation? selected, fetchingGeometry;
  final bool Function(OrbitLocation) failedGeometry;
  final ValueChanged<OrbitLocation> retryGeometry;
  final ValueChanged<OrbitLocation?> onSelect;
  final ValueChanged<OrbitLocation> onPickClips;
  final VoidCallback onSettings, onChanged, onUseGps;
  final bool importing, googleConfigured;
  const OrbitLocationsEditor({
    super.key,
    required this.project,
    required this.store,
    required this.fetchGeometry,
    required this.selected,
    required this.fetchingGeometry,
    required this.failedGeometry,
    required this.retryGeometry,
    required this.onSelect,
    required this.onPickClips,
    required this.onUseGps,
    required this.onSettings,
    required this.onChanged,
    required this.importing,
    required this.googleConfigured,
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
    } else {
      replace.place = value.place;
      replace.mapPath = null;
      replace.overviewPath = null;
      _updateClips(replace);
      widget.retryGeometry(replace);
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

  Future<void> _capture(OrbitLocation location, {bool findWall = false}) async {
    if (_busy) return;
    setState(() => _capturing = true);
    try {
      final place = PlaceDetails.fromJson(location.place.toJson());
      final previousPath = location.mapPath;
      final previousPlace = location.place;
      ({List<int> bytes, String coverage})? result;
      if (findWall) {
        final data = await widget.fetchGeometry(
          place.latitude!,
          place.longitude!,
        );
        if (!mounted) return;
        final geometry = OrbitScene.decode(data);
        if (geometry.wallMount == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No suitable wall found. Your current capture is still in use.',
              ),
            ),
          );
          return;
        }
        result = (bytes: utf8.encode(data), coverage: geometry.coverage);
      } else {
        result = await captureOrbit(context, place, findPin: false);
      }
      if (!mounted || result == null) return;
      final file = await widget.store.writeMapAsset(
        'orbit-${newId()}.json',
        result.bytes,
      );
      if (!mounted ||
          !locations.contains(location) ||
          location.place != previousPlace ||
          location.mapPath != previousPath) {
        await file.delete();
        return;
      }
      location.place = place;
      location.mapPath = file.path;
      for (final clip in widget.project.clips) {
        final settings = clip.streetview;
        if (settings.locationId == location.id &&
            (settings.mapPath == null || settings.mapPath == previousPath)) {
          settings.mapPath = file.path;
          settings.place.latitude = place.latitude;
          settings.place.longitude = place.longitude;
        }
      }
      widget.onChanged();
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

  Future<void> _overview(OrbitLocation location) async {
    setState(() => _capturing = true);
    try {
      final bytes = await Navigator.of(context).push<Uint8List>(
        MaterialPageRoute(
          builder: (_) => MapsWebHeaderPage(
            place: location.place,
            aspectRatio: 360 / StreetviewLayout.mapHeight,
            showHeaderGuide: false,
          ),
        ),
      );
      if (!mounted || bytes == null) return;
      final file = await widget.store.writeMapAsset(
        'overview-${newId()}.png',
        bytes,
      );
      if (!mounted || !locations.contains(location)) {
        await file.delete();
        return;
      }
      location.overviewPath = file.path;
      widget.onChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save the 2D map: $e')),
        );
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
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: widget.fetchingGeometry == selected
                            ? const SizedBox.square(
                                dimension: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                selected.mapPath != null
                                    ? Icons.check_circle_outline
                                    : Icons.warning_amber_rounded,
                              ),
                        title: Text(
                          selected.mapPath != null
                              ? '3D geometry saved'
                              : widget.fetchingGeometry == selected
                              ? (selected.place.hasCoordinates
                                    ? 'Fetching 3D geometry…'
                                    : 'Finding pin coordinates…')
                              : widget.failedGeometry(selected) &&
                                    selected.place.hasCoordinates
                              ? 'Geometry download failed'
                              : !selected.place.hasCoordinates
                              ? 'Pin coordinates needed'
                              : 'Waiting for geometry',
                        ),
                        subtitle: selected.mapPath == null
                            ? const Text(
                                'Geometry is required for 3D preview and export.',
                              )
                            : OrbitSceneBuilder(
                                path:
                                    clips.firstOrNull?.streetview.mapPath ??
                                    selected.mapPath,
                                builder: (scene, failed) => Text(
                                  scene?.describeWall(
                                        clips.firstOrNull?.streetview.wallId,
                                      ) ??
                                      (failed
                                          ? 'Could not read the saved geometry.'
                                          : 'Checking media placement…'),
                                ),
                              ),
                      ),
                      if (selected.mapPath case final path?)
                        SizedBox(
                          height: clips.isEmpty ? 170 : 220,
                          child: ClipRect(
                            child: clips.isEmpty
                                ? OrbitMap(
                                    path: path,
                                    progress: 0,
                                    dark: widget.project.darkOutput,
                                  )
                                : OrbitJourneyCanvas(
                                    project: widget.project,
                                    position:
                                        StreetviewTimeline.mediaStart(
                                          widget.project,
                                          widget.project.clips.indexOf(
                                            clips.first,
                                          ),
                                        ) +
                                        clips.first.duration / 2,
                                    playing: false,
                                    overlayOnly: false,
                                    posterOnly: true,
                                    posters: const {},
                                  ),
                          ),
                        ),
                      if (selected.mapPath != null &&
                          selected.place.latitude != null &&
                          selected.place.longitude != null)
                        OrbitSceneBuilder(
                          path: selected.mapPath,
                          builder: (scene, _) =>
                              scene != null && scene.wallMount == null
                              ? Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton.icon(
                                    onPressed: _busy
                                        ? null
                                        : () => _capture(
                                            selected,
                                            findWall: true,
                                          ),
                                    icon: const Icon(Icons.location_city),
                                    label: Text(
                                      _capturing
                                          ? 'Loading geometry…'
                                          : 'Find a wall with open data',
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed:
                                _busy || widget.fetchingGeometry == selected
                                ? null
                                : selected.mapPath == null &&
                                      selected.place.hasCoordinates
                                ? () => widget.retryGeometry(selected)
                                : () => _capture(selected),
                            icon: const Icon(Icons.location_city),
                            label: Text(
                              selected.mapPath != null
                                  ? 'Replace 3D capture'
                                  : !selected.place.hasCoordinates
                                  ? 'Enter pin coordinates'
                                  : 'Retry geometry',
                            ),
                          ),
                          if (!selected.place.hasCoordinates &&
                              widget.failedGeometry(selected))
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => widget.retryGeometry(selected),
                              child: const Text('Retry pin lookup'),
                            ),
                          if (widget.googleConfigured &&
                              selected.place.hasCoordinates &&
                              widget.failedGeometry(selected))
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => _capture(selected),
                              child: const Text('Try Google 3D capture'),
                            ),
                          TextButton.icon(
                            onPressed: _busy ? null : () => _overview(selected),
                            icon: const Icon(Icons.map_outlined),
                            label: Text(
                              selected.overviewPath == null
                                  ? 'Capture Google 2D map'
                                  : 'Replace Google 2D map',
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
