import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../services/open_orbit_map.dart';
import '../services/static_map.dart';
import '../widgets/orbit_capture.dart';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../model/project.dart';
import '../model/template_layout.dart';
import '../services/maps_editor_actions.dart';
import '../services/export_background_session.dart';
import '../services/maps_export_pipeline.dart';
import '../services/media_importer.dart';
import '../services/orbit_location_defaults.dart';
import '../services/native_renderer.dart';
import '../services/project_store.dart';
import '../widgets/export_monitor.dart';
import '../widgets/maps_editor_scaffold.dart';
import '../widgets/orbit_locations_editor.dart';
import '../widgets/maps_key_dialog.dart';
import '../widgets/offscreen_capture_stage.dart';
import '../widgets/place_form_controllers.dart';
import '../widgets/reel_preview.dart';
import 'exported_video_page.dart';

class MapsEditorPage extends StatefulWidget {
  final ProjectStore? store;
  final ReelProject? initialProject;
  final Future<String> Function(double, double) fetchGeometry;
  const MapsEditorPage({
    super.key,
    this.store,
    this.initialProject,
    this.fetchGeometry = OpenOrbitMap.fetch,
  });
  @override
  State<MapsEditorPage> createState() => _MapsEditorPageState();
}

class _MapsEditorPageState extends State<MapsEditorPage>
    with WidgetsBindingObserver {
  late final ProjectStore _store = widget.store ?? ProjectStore();
  final _renderer = NativeRenderer(), _captureKey = GlobalKey();
  final _form = PlaceFormControllers();
  final _backgroundExport = ExportBackgroundSession();
  ReelProject _project = ReelProject();
  int _placeTool = 0, _timelineTool = 0, _tab = 0;
  int _selected = 0, _captureIndex = 0, _editRevision = 0;
  bool _ready = false,
      _importing = false,
      _exporting = false,
      _dirty = false,
      _cancelled = false,
      _useApiHeaders = false,
      _captureSnapshot = false;
  double? _progress, _capturePosition;
  double _exportPosition = 0;
  ExportPhase _exportPhase = ExportPhase.preparing;
  String _exportFormat = 'H.264 · 1080 × 1920 · 30 fps';
  String _key = '', _status = '', _previewRevision = 'initial';
  String? _captureHeroPath;
  Map<String, String> _capturePosters = {};
  Timer? _autosave;
  OrbitLocation? _location;
  OrbitLocation? _fetchingGeometry;
  final _failedPins = <(String, double?, double?)>{};
  (String, double?, double?) _pin(OrbitLocation l) =>
      (l.id, l.place.latitude, l.place.longitude);

  Future<void> _fetchMissingGeometry() async {
    if (!_ready || !_project.isStreetview3d || _fetchingGeometry != null) {
      return;
    }
    final locations = _project.streetview.locations;
    final location = locations
        .where(
          (l) =>
              l.mapPath == null &&
              l.place.latitude != null &&
              l.place.longitude != null &&
              !_failedPins.contains(_pin(l)),
        )
        .firstOrNull;
    if (location == null) return;
    final key = _pin(location);
    bool current() =>
        mounted &&
        locations.contains(location) &&
        location.mapPath == null &&
        _pin(location) == key;
    setState(() => _fetchingGeometry = location);
    try {
      final json = await widget.fetchGeometry(key.$2!, key.$3!);
      if (!current()) return;
      final file = await writeMapAsset(
        _store,
        'orbit-${newId()}.json',
        utf8.encode(json),
      );
      if (!current()) {
        await file.delete();
        return;
      }
      final overview =
          _useApiHeaders && _key.isNotEmpty && location.overviewPath == null
          ? await _fetchGoogleOverview(location.place)
          : null;
      if (!current()) {
        await file.delete();
        if (overview != null) await overview.delete();
        return;
      }
      if (overview != null) {
        if (location.overviewPath == null) {
          location.overviewPath = overview.path;
        } else {
          await overview.delete();
        }
      }
      location.mapPath = file.path;
      for (final clip in _project.clips.where(
        (c) => c.streetview.locationId == location.id,
      )) {
        clip.streetview.mapPath ??= file.path;
      }
      _change();
    } catch (_) {
      if (current()) _failedPins.add(key);
    } finally {
      if (mounted) {
        setState(() => _fetchingGeometry = null);
        unawaited(_fetchMissingGeometry());
      }
    }
  }

  Future<File?> _fetchGoogleOverview(PlaceDetails place) async {
    final service = StaticMapService();
    try {
      final bytes = await service.load(place, _key, portrait: true);
      return await writeMapAsset(_store, 'overview-${newId()}.png', bytes);
    } on Exception {
      return null;
    } finally {
      service.dispose();
    }
  }

  static const _buildKey = String.fromEnvironment('MAPS_API_KEY');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_ready && _dirty && state != AppLifecycleState.resumed) {
      unawaited(_save(silent: true));
    }
  }

  Future<void> _initialize() async {
    try {
      await _store.initialize();
      final project = widget.initialProject ?? await _store.restore();
      final settings = await MapsAdvancedSettings.load(defaultKey: _buildKey);
      if (!mounted) return;
      _key = settings.key;
      _useApiHeaders = settings.useApiHeaders;
      var located = false;
      if (project.isStreetview3d) {
        located = await OrbitLocationDefaults.read(
          project.clips,
          _renderer.mediaCoordinates,
        );
        located = OrbitLocationDefaults.inherit(project.clips) || located;
        located =
            project.streetview.adoptClipLocations(project.clips) || located;
        if (!mounted) return;
      }
      _setProject(project);
      setState(() => _ready = true);
      if (located) _change();
      unawaited(_fetchMissingGeometry());
      // File checks may take a while on restored projects. Show the editor
      // immediately and repair only references that still match the saved path.
      for (final l in List.of(project.streetview.locations)) {
        final overview = l.overviewPath, map = l.mapPath;
        if (overview != null &&
            !await File(overview).exists() &&
            l.overviewPath == overview) {
          if (!mounted) return;
          l.overviewPath = null;
          _change();
        }
        if (map != null && !await File(map).exists() && l.mapPath == map) {
          if (!mounted) return;
          l.mapPath = null;
          for (final c in project.clips.where(
            (c) =>
                c.streetview.locationId == l.id && c.streetview.mapPath == map,
          )) {
            c.streetview.mapPath = null;
          }
          _change();
        }
      }
      // Older projects may keep a stale clip-specific copy of a valid
      // location capture. Restore only broken links after checking the files.
      if (project.isStreetview3d) {
        final checked = <String, bool>{};
        for (final clip in List.of(project.clips)) {
          final location = project.streetview.locationFor(clip);
          final path = clip.streetview.mapPath;
          if (location == null || path == null || path == location.mapPath) {
            continue;
          }
          final exists = checked[path] ??= await File(path).exists();
          if (!mounted) return;
          if (!exists &&
              clip.streetview.mapPath == path &&
              clip.streetview.locationId == location.id) {
            clip.streetview.mapPath = location.mapPath;
            _change();
          }
        }
      }
    } catch (e) {
      if (mounted) setState(() => _status = 'Storage error: $e');
    }
  }

  void _setProject(ReelProject project) {
    _project = project;
    _location = project.streetview.locations.firstOrNull;
    _selected = _captureIndex = 0;
    _captureHeroPath = _capturePosition = null;
    _captureSnapshot = false;
    _capturePosters = {};
    _form.populate(project.place);
    _dirty = false;
    _previewRevision = newId();
  }

  void _change() {
    if (!mounted) return;
    _form.saveTo(_project.place);
    _editRevision++;
    unawaited(_fetchMissingGeometry());
    setState(() => _dirty = true);
    _autosave?.cancel();
    _autosave = Timer(
      const Duration(milliseconds: 700),
      () => _save(silent: true),
    );
  }

  Future<bool> _save({bool silent = false}) async {
    _autosave?.cancel();
    try {
      final revision = _editRevision;
      await _store.save(_project);
      if (!mounted || revision != _editRevision) return false;
      setState(() => _dirty = false);
      if (!silent) _toast('Project and media saved on this device');
      return true;
    } catch (_) {
      _toast('Could not save project. Check device storage.');
      return false;
    }
  }

  void _toast(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _runImport(Future<void> Function() action) async {
    if (_importing) return;
    setState(() => _importing = true);
    try {
      await action();
    } catch (e) {
      _toast(MapsEditorActions.formatError(e));
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  void _applyMapHeader(String path, String source) {
    _project.mapHeaderPath = path;
    _project.mapSource = source;
    _project.headerMode = 'map';
    _previewRevision = newId();
    _change();
  }

  Future<void> _loadMap() => _runImport(_loadMapHeader);

  // The place-import operation already holds the import guard when it requests
  // its automatic header. Share the work without acquiring that guard twice.
  Future<void> _loadMapHeader() => MapsEditorActions.loadMap(
    project: _project,
    store: _store,
    useApiHeaders: _useApiHeaders,
    apiKey: _key,
    context: context,
    precache: _precache,
    onApplyHeader: _applyMapHeader,
  );

  Future<void> _uploadMap() => _runImport(
    () => MapsEditorActions.uploadMap(
      isActive: () => mounted,
      store: _store,
      precache: _precache,
      onApplyHeader: _applyMapHeader,
    ),
  );

  Future<void> _pickMusic() => _runImport(
    () => MapsEditorActions.pickMusic(
      isActive: () => mounted,
      project: _project,
      store: _store,
      renderer: _renderer,
      onChanged: () {
        _previewRevision = newId();
        _change();
      },
    ),
  );

  Future<void> _pickMedia() async {
    if (!_project.isStreetview3d) return _importClips();
    final locations = _project.streetview.locations;
    if (locations.isEmpty) {
      _goToStep(0);
      _toast('Choose a location for your clips first.');
      return;
    }
    final choice = await showDialog<({OrbitLocation? target})>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Where should these clips appear?'),
        children: [
          for (final location in locations)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, (target: location)),
              child: Text(location.label),
            ),
          SimpleDialogOption(
            onPressed: () =>
                Navigator.pop(context, (target: null as OrbitLocation?)),
            child: const Text('Use media GPS'),
          ),
        ],
      ),
    );
    if (!mounted || choice == null) return;
    await _importClips(choice.target);
  }

  Future<void> _importClips([OrbitLocation? target]) => _runImport(
    () => MapsEditorActions.pickMedia(
      isActive: () => mounted,
      project: _project,
      store: _store,
      renderer: _renderer,
      location: target,
      onAdded: (index) {
        _selected = index;
        if (_project.isStreetview3d) {
          _project.streetview.adoptClipLocations(_project.clips);
          _location =
              _project.streetview.locationFor(_project.clips[index]) ??
              _location;
          _tab = 1;
        }
        _previewRevision = newId();
        _change();
      },
      onToast: _toast,
    ),
  );

  Future<void> _settings() async {
    final value = await MapsAdvancedSettings.show(
      context,
      initialKey: _key,
      useApiHeaders: _useApiHeaders,
    );
    if (value != null) {
      await value.save();
      if (mounted) {
        setState(() {
          _key = value.key;
          _useApiHeaders = value.useApiHeaders;
        });
      }
    }
  }

  Future<void> _findPlace() => _runImport(
    () => MapsEditorActions.findPlace(
      context: context,
      project: _project,
      form: _form,
      getApiKey: () => _key,
      getUseApiHeaders: () => _useApiHeaders,
      onRequestApiKey: _settings,
      onLoadMap: _loadMapHeader,
      onChanged: _change,
    ),
  );

  Future<void> _rename() => MapsEditorActions.renameProject(
    context: context,
    project: _project,
    onChanged: _change,
  );

  Future<void> _backup() async {
    try {
      await MapsEditorActions.shareBackup(
        project: _project,
        store: _store,
        onSave: () => _save(silent: true),
      );
    } catch (e) {
      _toast('Could not share backup: ${MapsEditorActions.formatError(e)}');
    }
  }

  Future<void> _precache(String path) async {
    if (!mounted) return;
    await MediaImporter.precacheMediaImage(path, context);
  }

  Future<Uint8List> _capturePng() async {
    if (_cancelled || !mounted) throw const FormatException('Export cancelled');
    return OffscreenCaptureStage.capturePng(
      _captureKey,
      pixelRatio: TemplateLayout.exportScale,
    );
  }

  void _updateState(VoidCallback fn) {
    if (mounted) {
      setState(fn);
      if (_exporting) unawaited(_backgroundExport.update(_status, _progress));
    }
  }

  MapsExportPipeline _createPipeline() => MapsExportPipeline(
    project: _project,
    store: _store,
    renderer: _renderer,
    onPrecache: _precache,
    onCapturePng: _capturePng,
    onStatus: (s) => _updateState(() => _status = s),
    onProgress: (v) => _updateState(() => _progress = v),
    onPhase: (p) => _updateState(() => _exportPhase = p),
    onPosition: (p) => _updateState(() => _exportPosition = p),
    onCaptureIndex: (i) => _updateState(() => _captureIndex = i),
    onCapturePosition: (p) => _updateState(() => _capturePosition = p),
    onCaptureSnapshot: (s) => _updateState(() => _captureSnapshot = s),
    onCapturePosters: (p) => _updateState(() => _capturePosters = p),
    onCaptureHeroPath: (h) => _updateState(() => _captureHeroPath = h),
    isCancelled: () => _cancelled || !mounted,
  );

  Future<void> _runExport({
    required String format,
    required String initialStatus,
    required Future<void> Function(MapsExportPipeline pipeline) action,
  }) async {
    if (_exporting) return;
    setState(() {
      _exporting = true;
      _status = initialStatus;
      _cancelled = false;
      _exportPhase = ExportPhase.preparing;
      _exportPosition = 0;
      _exportFormat = format;
      _progress = null;
      _previewRevision = newId();
    });
    var complete = false;
    try {
      final notifications = await _backgroundExport.start(_project.title);
      if (notifications == false) {
        _toast(
          'Enable notifications in Android settings to see export progress.',
        );
      }
      if (!await _save(silent: true)) return;
      await action(_createPipeline());
      complete = !_cancelled;
    } catch (e) {
      _toast(MapsEditorActions.formatError(e));
    } finally {
      await _backgroundExport.finish(complete: complete);
      if (mounted) {
        setState(() {
          _exporting = false;
          _capturePosition = null;
          _captureSnapshot = false;
          _capturePosters = {};
          _progress = null;
        });
      }
    }
  }

  Future<void> _exportPng(bool snapshot) => _runExport(
    format: 'PNG · 1080 × 1920',
    initialStatus: 'Preparing image…',
    action: (p) => p.runExportPng(snapshot: snapshot, selectedIndex: _selected),
  );

  Future<void> _export() => _runExport(
    format: 'H.264 · 1080 × 1920 · 30 fps',
    initialStatus: 'Preparing media…',
    action: (pipeline) async {
      if (_project.clips.isEmpty) return;
      final path = await pipeline.runExport();
      if (!mounted || _cancelled) return;
      await _backgroundExport.finish(complete: true);
      if (!mounted) return;
      setState(() {
        _status = 'Export complete';
        _exportPhase = ExportPhase.finishing;
        _progress = 1;
      });
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ExportedVideoPage(path: path, renderer: _renderer),
        ),
      );
    },
  );

  void _removeClip(int i) {
    _project.clips.removeAt(i);
    _selected = min(i, max(0, _project.clips.length - 1));
    _captureIndex = 0;
    _previewRevision = newId();
    _change();
  }

  void _selectClip(int i) => setState(() {
    _selected = i;
    _previewRevision = newId();
  });

  void _goToPlaceHeader(int? missingClip) {
    if (missingClip == null) {
      _placeTool = 2;
    } else {
      _selected = missingClip;
    }
    if (_project.isStreetview3d && missingClip != null) {
      final target = _project.streetview.locationFor(
        _project.clips[missingClip],
      );
      if (target == null) {
        _timelineTool = 2;
        _goToStep(1);
        return;
      }
      _location = target;
    }
    _goToStep(0);
  }

  void _updatePreview() => _previewRevision = newId();

  Future<void> _back() async {
    if (await _save(silent: true) &&
        mounted &&
        !_exporting &&
        ModalRoute.of(context)?.isCurrent == true) {
      Navigator.of(context).pop();
    }
  }

  void _onMenuSelected(String action) {
    if (action == 'settings') _settings();
    if (action == 'rename') _rename();
    if (action == 'backup') _backup();
    if (action == 'projects') _back();
  }

  void _cancelExport() {
    setState(() {
      _cancelled = true;
      _status = 'Cancelling export…';
    });
    _renderer.cancel();
  }

  Widget _previewCanvas({double? position}) => ReelCanvas(
    project: _project,
    position:
        position ??
        _capturePosition ??
        _project.startOf(_captureIndex) +
            TemplateLayout.transitionDuration(_project, _captureIndex),
    animateIntro: _capturePosition != null,
    overlayOnly: !_captureSnapshot,
    posterOnly: true,
    heroPath: _captureHeroPath,
    posters: _capturePosters,
  );

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autosave?.cancel();
    if (_exporting) _renderer.cancel();
    _form.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return Scaffold(
        body: Center(
          child: _status.isEmpty
              ? const CircularProgressIndicator()
              : Text(_status),
        ),
      );
    }
    return MapsEditorScaffold(
      locationsEditor: _project.isStreetview3d
          ? OrbitLocationsEditor(
              fetchGeometry: widget.fetchGeometry,
              project: _project,
              store: _store,
              selected: _location ?? _project.streetview.locations.firstOrNull,
              googleConfigured: _key.isNotEmpty,
              fetchingGeometry: _fetchingGeometry,
              failedGeometry: (l) => _failedPins.contains(_pin(l)),
              retryGeometry: (l) {
                _failedPins.remove(_pin(l));
                unawaited(_fetchMissingGeometry());
              },
              onUseGps: () => _importClips(),
              importing: _importing,
              onSelect: (location) => setState(() => _location = location),
              onChanged: _change,
              onSettings: _settings,
              onPickClips: _importClips,
            )
          : null,
      tab: _tab,
      project: _project,
      store: _store,
      dirty: _dirty,
      exporting: _exporting,
      importing: _importing,
      selected: _selected,
      placeTool: _placeTool,
      timelineTool: _timelineTool,
      useApiHeaders: _useApiHeaders,
      apiKey: _key,
      form: _form,
      status: _status,
      exportPhase: _exportPhase,
      progress: _progress,
      exportPosition: _exportPosition,
      exportFormat: _exportFormat,
      cancelled: _cancelled,
      onCancelExport: _cancelExport,
      onBack: _back,
      onRename: _rename,
      onSave: _save,
      onMenuSelected: _onMenuSelected,
      onGoToStep: _goToStep,
      onSelectPlaceTool: (i) => setState(() => _placeTool = i),
      onSelectTimelineTool: (i) => setState(() => _timelineTool = i),
      onSelectClip: _selectClip,
      onRemoveClip: _removeClip,
      onMoveClip: _move,
      onFindPlace: _findPlace,
      onLoadMap: _loadMap,
      onUploadMap: _uploadMap,
      onGoToTimeline: () => _goToStep(1),
      onGoToPlaceHeader: _goToPlaceHeader,
      onPickMedia: _pickMedia,
      onPickMusic: _pickMusic,
      onExport: _export,
      onExportPng: _exportPng,
      onBackup: _backup,
      onChanged: _change,
      onPreviewUpdated: _updatePreview,
      previewBuilder: (height) => _preview(maxHeight: height),
      captureStage: OffscreenCaptureStage(
        captureKey: _captureKey,
        child: _previewCanvas(),
      ),
      exportPreview: _previewCanvas(position: _exportPosition),
    );
  }

  Widget _preview({double maxHeight = 420}) => _exporting
      ? SizedBox(height: maxHeight)
      : TimelinePreview(
          key: ValueKey(_previewRevision),
          project: _project,
          selected: _selected,
          startAtBeginning: _project.isStreetview && _selected == 0,
          maxHeight: maxHeight,
        );

  void _goToStep(int step) => setState(() {
    _tab = step;
    _previewRevision = newId();
  });

  void _move(int index, int delta) {
    final clip = _project.clips.removeAt(index);
    _project.clips.insert(index + delta, clip);
    _selected = index + delta;
    _previewRevision = newId();
    _change();
  }
}
