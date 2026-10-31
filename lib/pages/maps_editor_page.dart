import '../model/streetview_motion.dart';
import '../model/streetview_timeline.dart';
import '../services/gif_media.dart';
import '../services/media_importer.dart';
import '../widgets/maps_export_panel.dart';
import '../widgets/maps_place_editor.dart';
import '../widgets/maps_timeline_editor.dart';
import 'maps_web_search_page.dart';
import 'maps_web_header_page.dart';
import '../model/maps_web_result.dart';
import '../widgets/export_monitor.dart';
import '../widgets/maps_key_dialog.dart';
import '../widgets/project_name_dialog.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import '../model/template_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/project.dart';
import '../services/native_renderer.dart';
import '../services/static_map.dart';
import '../widgets/editor_workspace.dart';
import '../widgets/creation_steps.dart';
import '../services/project_store.dart';
import '../widgets/reel_preview.dart';
import '../widgets/media_frame.dart';
import '../widgets/text_editor.dart';
import '../widgets/audio_editor.dart';
import 'exported_video_page.dart';

class MapsEditorPage extends StatefulWidget {
  final ProjectStore? store;
  final ReelProject? initialProject;
  const MapsEditorPage({super.key, this.store, this.initialProject});
  @override
  State<MapsEditorPage> createState() => _MapsEditorPageState();
}

class _MapsEditorPageState extends State<MapsEditorPage>
    with WidgetsBindingObserver {
  late final ProjectStore _store = widget.store ?? ProjectStore();
  final _renderer = NativeRenderer();
  final _captureKey = GlobalKey();
  final _name = TextEditingController(),
      _category = TextEditingController(),
      _rating = TextEditingController(),
      _address = TextEditingController(),
      _localName = TextEditingController(),
      _reviews = TextEditingController(),
      _price = TextEditingController(),
      _hours = TextEditingController();
  ReelProject _project = ReelProject();
  int _placeTool = 0, _timelineTool = 0;
  int _tab = 0, _selected = 0, _captureIndex = 0, _editRevision = 0;
  bool _ready = false, _importing = false, _exporting = false, _dirty = false;
  double? _progress;
  bool _cancelled = false;
  ExportPhase _exportPhase = ExportPhase.preparing;
  double _exportPosition = 0;
  String _exportFormat = 'H.264 · 1080 × 1920 · 30 fps';
  bool _useApiHeaders = false;
  String _key = '', _status = '', _previewRevision = 'initial';
  String? _captureHeroPath;
  bool _captureSnapshot = false;
  double? _capturePosition;
  Map<String, String> _capturePosters = {};
  List<TextEditingController> get _controllers => [
    _name,
    _category,
    _rating,
    _address,
    _localName,
    _reviews,
    _price,
    _hours,
  ];
  Timer? _autosave;
  StreamSubscription<double>? _progressSubscription;
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
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      _key = prefs.getString('mapsApiKey') ?? _buildKey;
      _useApiHeaders = prefs.getBool('mapsUseApiHeaders') ?? false;
      _setProject(project);
      setState(() => _ready = true);
    } catch (e) {
      if (mounted) {
        setState(() => _status = 'Could not open project storage: $e');
      }
    }
  }

  void _setProject(ReelProject project) {
    _project = project;
    _selected = 0;
    _captureIndex = 0;
    _captureHeroPath = null;
    _captureSnapshot = false;
    _capturePosition = null;
    _capturePosters = {};
    _name.text = project.place.name;
    _category.text = project.place.category;
    _rating.text = project.place.rating;
    _address.text = project.place.address;
    _localName.text = project.place.localName;
    _reviews.text = project.place.reviewCount;
    _price.text = project.place.price;
    _hours.text = project.place.hours;
    _dirty = false;
    _previewRevision = newId();
  }

  void _change() {
    _project.place.name = _name.text;
    _project.place.category = _category.text;
    _project.place.rating = _rating.text;
    _project.place.address = _address.text;
    _project.place.localName = _localName.text;
    _project.place.reviewCount = _reviews.text;
    _project.place.price = _price.text;
    _project.place.hours = _hours.text;
    _editRevision++;
    setState(() => _dirty = true);
    _autosave?.cancel();
    _autosave = Timer(
      const Duration(milliseconds: 700),
      () => _save(silent: true),
    );
  }

  Future<void> _save({bool silent = false}) async {
    _autosave?.cancel();
    try {
      final revision = _editRevision;
      await _store.save(_project);
      if (!mounted) return;
      if (revision == _editRevision) setState(() => _dirty = false);
      if (!silent) _toast('Project and media saved on this device');
    } catch (_) {
      if (mounted) {
        _toast('Could not save project. Check available device storage.');
      }
    }
  }

  void _toast(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  String _error(Object e) => e is PlatformException
      ? e.message ?? e.code
      : e.toString().replaceFirst('Exception: ', '');

  Future<void> _loadMap() async {
    if (_importing) return;
    setState(() => _importing = true);
    final id = _project.id;
    final place = _project.place;
    final service = StaticMapService();
    File? file;
    try {
      final bytes = _useApiHeaders && _key.isNotEmpty
          ? await service.load(place, _key, zoom: _project.mapZoom)
          : await Navigator.of(context).push<Uint8List>(
              MaterialPageRoute(
                builder: (_) => MapsWebHeaderPage(place: place),
              ),
            );
      if (bytes == null) return;
      file = File('${_store.root!.path}/media/map_${newId()}.png');
      await file.writeAsBytes(bytes, flush: true);
      await _precache(file.path);
      if (!mounted || id != _project.id || !identical(place, _project.place)) {
        await file.delete();
        return;
      }
      _project.mapHeaderPath = file.path;
      _project.mapSource = _useApiHeaders && _key.isNotEmpty
          ? 'google'
          : 'browser';
      _project.headerMode = 'map';
      _previewRevision = newId();
      _change();
    } catch (e) {
      if (file != null && await file.exists()) await file.delete();
      _toast(_error(e));
    } finally {
      service.dispose();
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _uploadMap() async {
    if (_importing) return;
    setState(() => _importing = true);
    final id = _project.id;
    String? path;
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (file == null) return;
      path = await _store.retainMedia(file.path, file.name);
      await _precache(path);
      if (!mounted || id != _project.id) {
        await File(path).delete();
        return;
      }
      _project.mapHeaderPath = path;
      _project.mapSource = 'upload';
      _project.headerMode = 'map';
      _previewRevision = newId();
      _change();
    } catch (e) {
      if (path != null && await File(path).exists()) await File(path).delete();
      _toast(_error(e));
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _pickMusic() async {
    if (_importing) return;
    setState(() => _importing = true);
    try {
      final track = await MediaImporter.pickMusicTrack(
        store: _store,
        renderer: _renderer,
      );
      if (track != null && mounted) {
        _project.music = track;
        _previewRevision = newId();
        _change();
      }
    } catch (e) {
      _toast(_error(e));
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _pickMedia() async {
    if (_importing) return;
    setState(() => _importing = true);
    var failures = 0;
    try {
      final files = await ImagePicker().pickMultipleMedia();
      for (final file in files) {
        try {
          final clip = await MediaImporter.retainClip(
            file,
            store: _store,
            renderer: _renderer,
            defaultDuration: 3.5,
          );
          if (!mounted) return;
          _project.clips.add(clip);
          _selected = _project.clips.length - 1;
        } catch (_) {
          failures++;
        }
      }
      if (mounted) {
        _previewRevision = newId();
        _change();
      }
      if (failures > 0) {
        _toast(
          '$failures files could not be opened. Try JPG/PNG/GIF images or MP4 video.',
        );
      }
    } catch (e) {
      _toast(_error(e));
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _settings() async {
    final value = await showDialog<MapsAdvancedSettings>(
      context: context,
      builder: (_) =>
          MapsKeyDialog(initialValue: _key, useApiHeaders: _useApiHeaders),
    );
    if (value != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('mapsApiKey', value.key);
      await prefs.setBool('mapsUseApiHeaders', value.useApiHeaders);
      if (mounted) {
        setState(() {
          _key = value.key;
          _useApiHeaders = value.useApiHeaders;
        });
      }
    }
  }

  Future<void> _findPlace() async {
    final imported = await Navigator.of(context).push<MapsWebImport>(
      MaterialPageRoute(
        builder: (_) => MapsWebSearchPage(
          initial: _name.text,
          requestApiKey: () async {
            if (_key.isEmpty) await _settings();
            return _key.isEmpty ? null : _key;
          },
        ),
      ),
    );
    if (imported == null || !mounted) return;
    final place = imported.place;
    setState(() {
      _project.place = place;
      _project.review = imported.review ?? FeaturedReview(enabled: false);
      _project.mapHeaderPath = null;
      _name.text = place.name;
      _category.text = place.category;
      _rating.text = place.rating;
      _address.text = place.address;
      _localName.text = place.localName;
      _reviews.text = place.reviewCount;
      _price.text = place.price;
      _hours.text = place.hours;
      if (_project.title == 'Untitled reel') _project.title = place.name;
    });
    _change();
    if (_project.headerMode == 'map' && _key.isNotEmpty && _useApiHeaders) {
      await _loadMap();
    }
  }

  Future<void> _projects() async {
    await _save(silent: true);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _rename() async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => ProjectNameDialog(initialValue: _project.title),
    );
    if (result != null && result.isNotEmpty && mounted) {
      _project.title = result;
      _change();
    }
  }

  Future<void> _backup() async {
    try {
      await _save(silent: true);
      await MediaImporter.shareProjectBackup(_project, _store);
    } catch (e) {
      _toast('Could not share backup: ${_error(e)}');
    }
  }

  Future<void> _precache(String path) async {
    if (!mounted) return;
    await MediaImporter.precacheMediaImage(path, context);
  }

  Future<void> _prepareCapture({bool snapshot = false}) async {
    final hero = _project.headerMode == 'photo' ? _project.heroClip : null;
    String? heroPath = _project.headerMode == 'map'
        ? _project.mapHeaderPath
        : null;
    if (heroPath != null) await _precache(heroPath);
    if (!_project.isStreetview &&
        _project.headerMode == 'map' &&
        heroPath == null) {
      throw const FormatException(
        'Load a Google map or upload a map image in Place before exporting.',
      );
    }
    if (hero != null) {
      heroPath = await _renderer.poster(hero);
      await _precache(heroPath);
    }
    final paths = <String, String>{};
    if (snapshot) {
      for (final c in _project.clips) {
        if (_cancelled || !mounted) {
          throw const FormatException('Export cancelled');
        }
        paths[c.id] = await _renderer.poster(c);
        await _precache(paths[c.id]!);
        if (_project.isStreetview) {
          paths['${c.id}:end'] = await _renderer.poster(
            c,
            position: c.duration - .001,
          );
          await _precache(paths['${c.id}:end']!);
          if (c.streetview.mapPath != null) {
            await _precache(c.streetview.mapPath!);
          }
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _captureHeroPath = heroPath;
      _captureSnapshot = snapshot;
      _capturePosters = paths;
    });
  }

  Future<Uint8List> _capturePng() async {
    if (_cancelled || !mounted) throw const FormatException('Export cancelled');
    await SchedulerBinding.instance.endOfFrame;
    final boundary =
        _captureKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    final image = await boundary.toImage(
      pixelRatio: TemplateLayout.exportScale,
    );
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      return bytes!.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  Future<void> _exportPng(bool snapshot) async {
    if (_exporting) return;
    setState(() {
      _exporting = true;
      _status = 'Preparing image…';
      _cancelled = false;
      _exportPhase = ExportPhase.preparing;
      _exportPosition = _project.startOf(_selected);
      _exportFormat = 'PNG · 1080 × 1920';
      _progress = null;
      _previewRevision = newId();
    });
    try {
      await _save(silent: true);
      await _prepareCapture(snapshot: snapshot);
      if (!mounted) return;
      setState(() => _captureIndex = _selected);
      final bytes = await _capturePng();
      final kind = snapshot ? 'snapshot' : 'template';
      final file = File('${_store.root!.path}/exports/$kind-${newId()}.png');
      await file.writeAsBytes(bytes);
      if (_cancelled || !mounted) return;
      final subjectLabel = snapshot ? 'snapshot' : 'transparent template';
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          subject: '${_project.title} — $subjectLabel',
        ),
      );
    } catch (e) {
      _toast(_error(e));
    } finally {
      if (mounted) {
        setState(() {
          _exporting = false;
          _captureSnapshot = false;
          _capturePosters = {};
        });
      }
    }
  }

  Widget _framingControl(
    String label,
    double value,
    double min,
    double max,
    String display,
    ValueChanged<double> onChanged,
  ) => EditorSlider(
    label: label,
    valueLabel: display,
    value: value,
    min: min,
    max: max,
    onChanged: onChanged,
  );

  Future<void> _export() async {
    if (_project.clips.isEmpty || _exporting) return;
    setState(() {
      _exporting = true;
      _progress = null;
      _status = 'Preparing media…';
      _cancelled = false;
      _exportPhase = ExportPhase.preparing;
      _exportPosition = 0;
      _exportFormat = 'H.264 · 1080 × 1920 · 30 fps';
      _previewRevision = newId();
    });
    Directory? temp;
    try {
      await _save(silent: true);
      for (final clip in _project.clips) {
        if (!await File(clip.path).exists()) {
          throw Exception(
            '“${clip.name}” is missing. Remove or replace that clip.',
          );
        }
      }
      temp = await Directory(
        '${_store.root!.path}/exports/overlay_${newId()}',
      ).create();
      await _prepareCapture(snapshot: true);
      if (!mounted || _cancelled) {
        throw const FormatException('Export cancelled');
      }
      setState(() => _captureSnapshot = false);
      if (_project.isStreetview) {
        await _exportStreetview(temp);
        return;
      }
      final overlays = <String>[];
      for (var i = 0; i < _project.clips.length; i++) {
        if (!mounted) return;
        setState(() {
          _captureIndex = i;
          _exportPosition = _project.startOf(i);
          _status = 'Preparing clip ${i + 1} of ${_project.clips.length}…';
          _progress = .15 * i / _project.clips.length;
        });
        final data = await _capturePng();
        final file = File('${temp.path}/$i.png');
        await file.writeAsBytes(data);
        overlays.add(file.path);
      }
      final introFrames = <String>[];
      for (
        var frame = 0;
        frame <
            (min(_project.sheetIntroSeconds, _project.duration) * 30).ceil();
        frame++
      ) {
        if (!mounted) return;
        final position = frame / 30;
        setState(() {
          _capturePosition = position;
          _exportPosition = position;
          _status = 'Preparing opening animation…';
          _progress =
              .15 +
              .20 *
                  frame /
                  max(
                    1,
                    (min(_project.sheetIntroSeconds, _project.duration) * 30)
                        .ceil(),
                  );
          _captureIndex = max(0, _project.clipAt(position));
        });
        final file = File('${temp.path}/intro_$frame.png');
        await file.writeAsBytes(await _capturePng());
        introFrames.add(file.path);
      }
      if (mounted) {
        setState(() {
          _capturePosition = null;
          _exportPhase = ExportPhase.encoding;
          _exportPosition = 0;
          _progress = .35;
          _status = 'Encoding video…';
        });
      }
      if (_cancelled) throw const FormatException('Export cancelled');
      _progressSubscription = _renderer.progress.listen((value) {
        if (mounted) {
          setState(() {
            _progress = .35 + .65 * value;
            _exportPosition = _project.duration * value.clamp(0, 1);
            _status = 'Encoding video…';
          });
        }
      });
      final path = await _renderer.export(
        _project,
        overlays,
        introFrames: introFrames,
      );
      if (!mounted) return;
      if (_cancelled) return;
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
    } catch (e) {
      _toast(_error(e));
    } finally {
      await _progressSubscription?.cancel();
      _progressSubscription = null;
      if (temp != null && await temp.exists()) {
        await temp.delete(recursive: true);
      }
      if (mounted) {
        setState(() {
          _exporting = false;
          _capturePosition = null;
          _capturePosters = {};
          _progress = null;
        });
      }
    }
  }

  Future<void> _exportStreetview(Directory temp) async {
    final scenes = StreetviewTimeline.scenes(_project);
    final clips = <Map<String, dynamic>>[];
    final overlays = <String>[];
    final frames = <List<String>>[];
    for (var i = 0; i < scenes.length; i++) {
      final scene = scenes[i];
      final clip = _project.clips[scene.mediaIndex];
      if ((scene.kind == 'map' || scene.kind == 'ending-map') &&
          clip.streetview.mapPath == null) {
        throw FormatException(
          'Capture a map for “${clip.name}” before exporting.',
        );
      }
      final media = scene.kind == 'media';
      final animatedArrows =
          media && clip.streetview.showArrows && StreetviewMotion.active(clip);
      final count = media && !animatedArrows ? 1 : (scene.duration * 30).ceil();
      final paths = <String>[];
      for (var f = 0; f < count; f++) {
        if (_cancelled || !mounted) {
          throw const FormatException('Export cancelled');
        }
        setState(() {
          _captureSnapshot = false;
          _capturePosition = scene.start + f / 30;
          _exportPosition = _capturePosition!;
          _progress = .35 * (i + f / count) / scenes.length;
          _status = 'Preparing journey scene ${i + 1} of ${scenes.length}…';
        });
        final file = File('${temp.path}/streetview-$i-$f.png');
        await file.writeAsBytes(await _capturePng());
        paths.add(file.path);
      }
      overlays.add(paths.last);
      frames.add(media && !animatedArrows ? [] : paths);
      clips.add(
        media
            ? {
                ...clip.toJson(),
                'slowPanZoom': clip.streetview.panZoom,
                'cameraMotion': StreetviewMotion.native(clip),
              }
            : {
                ...clip.toJson(),
                'path': paths.first,
                'edits': <String, dynamic>{},
                'isVideo': false,
                'isGif': false,
                'duration': scene.duration,
                'trimStart': 0.0,
                'zoom': 1.0,
                'panX': 0.0,
              },
      );
    }
    if (_cancelled || !mounted) throw const FormatException('Export cancelled');
    setState(() {
      _exportPhase = ExportPhase.encoding;
      _status = 'Encoding video…';
      _exportPosition = 0;
      _capturePosition = null;
    });
    _progressSubscription = _renderer.progress.listen((v) {
      if (mounted) {
        setState(() {
          _progress = .35 + .65 * v;
          _exportPosition = _project.duration * v;
        });
      }
    });
    final path = await _renderer.exportFeed(
      clips: clips,
      overlays: overlays,
      frames: frames,
      transitions: List.filled(clips.length, 0),
      music: _project.music,
    );
    if (_cancelled || !mounted) return;
    setState(() {
      _exportPhase = ExportPhase.finishing;
      _progress = 1;
    });
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ExportedVideoPage(path: path, renderer: _renderer),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autosave?.cancel();
    _progressSubscription?.cancel();
    if (_exporting) _renderer.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
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
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return PopScope(
      canPop: !_exporting,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && _dirty) unawaited(_save(silent: true));
      },
      child: Stack(
        children: [
          // The capture surface is painted behind the opaque editor. It stays exactly
          // 360×640 logical pixels regardless of the phone screen or accessibility scale.
          Positioned(
            left: 0,
            top: 0,
            width: 360,
            height: 640,
            child: ExcludeSemantics(
              child: IgnorePointer(
                child: MediaQuery.withNoTextScaling(
                  child: RepaintBoundary(
                    key: _captureKey,
                    child: ReelCanvas(
                      project: _project,
                      position:
                          _capturePosition ??
                          _project.startOf(_captureIndex) +
                              TemplateLayout.transitionDuration(
                                _project,
                                _captureIndex,
                              ),
                      animateIntro: _capturePosition != null,
                      overlayOnly: !_captureSnapshot,
                      posterOnly: true,
                      heroPath: _captureHeroPath,
                      posters: _capturePosters,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Scaffold(
            appBar: AppBar(
              titleSpacing: 4,
              leading: IconButton(
                tooltip: 'Back to projects',
                onPressed: _exporting
                    ? null
                    : () async {
                        await _save(silent: true);
                        if (mounted && context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                icon: const Icon(Icons.arrow_back),
              ),
              title: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: _rename,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              _project.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.edit_outlined,
                            size: 13,
                            color: colors.onSurfaceVariant,
                          ),
                        ],
                      ),
                      Text(
                        _project.isStreetview
                            ? 'STREET VIEW JOURNEY · 9:16'
                            : 'MAPS PLACE STORY · 9:16',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: colors.primary,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                IconButton(
                  tooltip: 'Save project',
                  onPressed: _save,
                  icon: Icon(
                    _dirty ? Icons.save_outlined : Icons.check_circle_outline,
                    color: _dirty ? colors.primary : colors.onSurfaceVariant,
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'More project options',
                  icon: const Icon(Icons.more_vert),
                  onSelected: (action) {
                    switch (action) {
                      case 'settings':
                        _settings();
                      case 'rename':
                        _rename();
                      case 'backup':
                        _backup();
                      case 'projects':
                        _projects();
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'rename',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.drive_file_rename_outline),
                        title: Text('Rename project'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'settings',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.tune_outlined),
                        title: Text('Advanced · Google Maps'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'backup',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.ios_share_outlined),
                        title: Text('Share project backup'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'projects',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.folder_open_outlined),
                        title: Text('Open or import a project'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            body: Column(
              children: [
                if (MediaQuery.viewInsetsOf(context).bottom == 0)
                  CreationStepHeading(
                    step: _tab,
                    onNext: () => _goToStep(min(4, _tab + 1)),
                  ),
                Expanded(
                  child: _tab == 2
                      ? TextEditor(
                          keyboardVisible:
                              MediaQuery.viewInsetsOf(context).bottom > 0,
                          key: ValueKey(_project.id),
                          project: _project,
                          selectedClip: _selected,
                          onChanged: _change,
                        )
                      : EditorWorkspace(
                          key: ValueKey('workspace-$_tab'),
                          keyboardVisible:
                              MediaQuery.viewInsetsOf(context).bottom > 0,
                          previewFraction: _tab == 1
                              ? .48
                              : _tab == 4
                              ? .50
                              : .56,
                          previewBuilder: (height) =>
                              _preview(maxHeight: height),
                          inspector: switch (_tab) {
                            0 => MapsPlaceEditor(
                              project: _project,
                              placeTool: _placeTool,
                              importing: _importing,
                              useApiHeaders: _useApiHeaders,
                              apiKey: _key,
                              store: _store,
                              selectedClipIndex: _selected.clamp(
                                0,
                                max(0, _project.clips.length - 1),
                              ),
                              nameController: _name,
                              categoryController: _category,
                              addressController: _address,
                              ratingController: _rating,
                              localNameController: _localName,
                              reviewsController: _reviews,
                              priceController: _price,
                              hoursController: _hours,
                              onSelectPlaceTool: (i) {
                                setState(() => _placeTool = i);
                              },
                              onFindPlace: _findPlace,
                              onLoadMap: _loadMap,
                              onUploadMap: _uploadMap,
                              onGoToTimeline: () => _goToStep(1),
                              clipStrip: MapsTimelineEditor.buildClipStrip(
                                context: context,
                                project: _project,
                                selectedIndex: _selected,
                                onSelectClip: (i) => setState(() {
                                  _selected = i;
                                  _previewRevision = newId();
                                }),
                              ),
                              addMediaButton: _addMedia(),
                              onChanged: _change,
                              onPreviewUpdated: () {
                                _previewRevision = newId();
                              },
                            ),
                            1 => MapsTimelineEditor(
                              project: _project,
                              selectedIndex: _selected,
                              timelineTool: _timelineTool,
                              importing: _importing,
                              store: _store,
                              onPickMedia: _pickMedia,
                              onAddMedia: _addMedia(),
                              onSelectClip: (i) => setState(() {
                                _selected = i;
                                _previewRevision = newId();
                              }),
                              onSelectTool: (i) {
                                setState(() => _timelineTool = i);
                              },
                              onRemoveClip: (i) {
                                _project.clips.removeAt(i);
                                _selected = min(
                                  i,
                                  max(0, _project.clips.length - 1),
                                );
                                _captureIndex = 0;
                                _previewRevision = newId();
                                _change();
                              },
                              onMoveClip: _move,
                              onChanged: _change,
                              onPreviewUpdated: () {
                                _previewRevision = newId();
                              },
                            ),
                            3 => AudioEditor(
                              project: _project,
                              importing: _importing,
                              onPick: _pickMusic,
                              onChanged: _change,
                            ),
                            _ => MapsExportPanel(
                              project: _project,
                              importing: _importing,
                              onExport: _export,
                              onExportPng: _exportPng,
                              onBackup: _backup,
                              onSetupHeader: () {
                                _placeTool = 2;
                                _goToStep(0);
                              },
                            ),
                          },
                        ),
                ),
              ],
            ),
            bottomNavigationBar: MediaQuery.viewInsetsOf(context).bottom > 0
                ? null
                : CreationSteps(
                    selected: _tab,
                    completed: [
                      _project.place.name.trim().isNotEmpty,
                      _project.clips.isNotEmpty,
                      _project.tags.isNotEmpty,
                      _project.music != null,
                      false,
                    ],
                    onSelected: _goToStep,
                  ),
          ),
          if (_exporting)
            Positioned.fill(
              child: ExportMonitor(
                title: _project.title,
                status: _status,
                phase: _exportPhase,
                progress: _progress,
                position: _exportPosition,
                duration: _project.duration,
                format: _exportFormat,
                preview: IgnorePointer(
                  child: ReelCanvas(
                    project: _project,
                    position: _exportPosition,
                    posterOnly: true,
                    heroPath: _captureHeroPath,
                    posters: _capturePosters,
                  ),
                ),
                onCancel: _cancelled || _exportPhase == ExportPhase.finishing
                    ? null
                    : () {
                        setState(() {
                          _cancelled = true;
                          _status = 'Cancelling export…';
                        });
                        _renderer.cancel();
                      },
              ),
            ),
        ],
      ),
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

  Widget _addMedia() => OutlinedButton.icon(
    onPressed: _importing ? null : _pickMedia,
    icon: _importing
        ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.add_photo_alternate_outlined),
    label: Text(_importing ? 'Importing media…' : 'Add photos & videos'),
  );

  void _move(int index, int delta) {
    final clip = _project.clips.removeAt(index);
    _project.clips.insert(index + delta, clip);
    _selected = index + delta;
    _previewRevision = newId();
    _change();
  }
}
