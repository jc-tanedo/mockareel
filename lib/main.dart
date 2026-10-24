import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'model/template_layout.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'model/project.dart';
import 'pages/library_page.dart';
import 'services/native_renderer.dart';
import 'services/places.dart';
import 'services/static_map.dart';
import 'widgets/template_content_editor.dart';
import 'widgets/output_theme_picker.dart';
import 'widgets/editor_workspace.dart';
import 'widgets/creation_steps.dart';
import 'services/project_store.dart';
import 'widgets/reel_preview.dart';
import 'widgets/media_frame.dart';
import 'widgets/place_actions_editor.dart';
import 'widgets/text_editor.dart';
import 'widgets/audio_editor.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MockareelApp());
}

const ink = Color(0xff171719),
    panel = Color(0xff232326),
    mint = Color(0xffb1a6ff);

class MockareelApp extends StatelessWidget {
  final ProjectStore? store;
  final ReelProject? editorProject;
  const MockareelApp({super.key, this.store, this.editorProject});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Mockareel',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xff202023),
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Color(0xff202023),
        indicatorColor: Color(0xff39334f),
        height: 68,
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xff38383d),
        thickness: 1,
      ),
      sliderTheme: const SliderThemeData(
        trackHeight: 2,
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 5),
      ),
      scaffoldBackgroundColor: ink,
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: mint,
        brightness: Brightness.dark,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: panel,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    ),
    home: editorProject == null
        ? LibraryPage(store: store)
        : EditorPage(store: store, initialProject: editorProject),
  );
}

class EditorPage extends StatefulWidget {
  final ProjectStore? store;
  final ReelProject? initialProject;
  const EditorPage({super.key, this.store, this.initialProject});
  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> with WidgetsBindingObserver {
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
      final bytes = await service.load(
        _project.place,
        _key,
        zoom: _project.mapZoom,
      );
      file = File('${_store.root!.path}/media/map_${newId()}.png');
      await file.writeAsBytes(bytes, flush: true);
      await _precache(file.path);
      if (!mounted || id != _project.id || !identical(place, _project.place)) {
        await file.delete();
        return;
      }
      _project.mapHeaderPath = file.path;
      _project.mapSource = 'google';
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
    String? retained;
    try {
      final file = await FilePicker.pickFile(type: FileType.audio);
      if (file == null || file.path == null) return;
      final info = await _renderer.inspect(file.path!);
      final duration = (info['duration'] as num?)?.toDouble() ?? 0;
      if (duration <= 0 || info['hasAudio'] != true) {
        throw const FormatException(
          'Choose a file with a playable audio track.',
        );
      }
      retained = await _store.retainMedia(file.path!, file.name);
      if (!mounted) return;
      _project.music = MusicTrack(
        path: retained,
        name: file.name,
        sourceDuration: duration,
      );
      _previewRevision = newId();
      _change();
    } catch (e) {
      if (retained != null) await File(retained).delete();
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
        String? retained;
        try {
          final video =
              file.mimeType?.startsWith('video/') == true ||
              RegExp(
                r'\.(mp4|mov|m4v|webm|mkv|3gp)$',
                caseSensitive: false,
              ).hasMatch(file.name);
          final metadata = video
              ? await _renderer.inspect(file.path)
              : <String, dynamic>{};
          final length = (metadata['duration'] as num?)?.toDouble() ?? 0;
          if (video && length <= 0) {
            throw const FormatException('Video duration is unavailable');
          }
          retained = await _store.retainMedia(file.path, file.name);
          final clip = ReelClip(
            id: newId(),
            path: retained,
            name: file.name,
            isVideo: video,
            sourceDuration: length,
            duration: video ? min(3.5, length) : 3.5,
          );
          if (!mounted) return;
          _project.clips.add(clip);
          _selected = _project.clips.length - 1;
        } catch (_) {
          failures++;
          if (retained != null) await File(retained).delete();
        }
      }
      if (mounted) {
        _previewRevision = newId();
        _change();
      }
      if (failures > 0) {
        _toast(
          '$failures files could not be opened. Try JPG/PNG images or MP4 video.',
        );
      }
    } catch (e) {
      _toast(_error(e));
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _settings() async {
    final controller = TextEditingController(text: _key);
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Google Places key'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enable Places API (New) and billing in your Google Cloud project. The key is stored on this device and used only for place search.',
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(labelText: 'API key'),
              ),
              const SizedBox(height: 10),
              const Text(
                'Manual place editing and video export work without a key.',
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save key'),
          ),
        ],
      ),
    );
    if (value != null) {
      await (await SharedPreferences.getInstance()).setString(
        'mapsApiKey',
        value,
      );
      if (mounted) setState(() => _key = value);
    }
    // The route's closing animation still references the controller; let its field own teardown.
  }

  Future<void> _findPlace() async {
    if (_key.isEmpty) {
      await _settings();
      if (_key.isEmpty || !mounted) return;
    }
    final place = await showDialog<PlaceDetails>(
      context: context,
      builder: (_) => PlaceSearchDialog(apiKey: _key, initial: _name.text),
    );
    if (place == null || !mounted) return;
    setState(() {
      _project.place = place;
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
    if (_project.headerMode == 'map') await _loadMap();
  }

  Future<void> _projects() async {
    await _save(silent: true);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _rename() async {
    final controller = TextEditingController(text: _project.title);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Project name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 80,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty && mounted) {
      _project.title = result;
      _change();
    }
  }

  Future<void> _backup() async {
    try {
      await _save(silent: true);
      final path = await _store.backup(_project);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(path, mimeType: 'application/zip')],
          subject: '${_project.title} — Mockareel project',
        ),
      );
    } catch (e) {
      _toast('Could not share backup: ${_error(e)}');
    }
  }

  Future<void> _precache(String path) async {
    if (!mounted) return;
    Object? failure;
    await precacheImage(
      FileImage(File(path)),
      context,
      onError: (e, _) {
        failure = e;
      },
    );
    if (failure != null) {
      throw Exception(
        'A media image could not be opened. Replace it and try again.',
      );
    }
  }

  Future<void> _prepareCapture({bool snapshot = false}) async {
    final hero = _project.headerMode == 'photo' ? _project.heroClip : null;
    String? heroPath = _project.headerMode == 'map'
        ? _project.mapHeaderPath
        : null;
    if (heroPath != null) await _precache(heroPath);
    if (_project.headerMode == 'map' && heroPath == null) {
      throw const FormatException(
        'Load a Google map or upload a map image in Place before exporting.',
      );
    }
    if (hero != null) {
      heroPath = hero.isVideo
          ? await _renderer.thumbnail(hero.path, hero.trimStart)
          : hero.path;
      await _precache(heroPath);
    }
    final paths = <String, String>{};
    if (snapshot) {
      for (final c in _project.clips) {
        paths[c.id] = c.isVideo
            ? await _renderer.thumbnail(c.path, c.trimStart)
            : c.path;
        await _precache(paths[c.id]!);
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
      _progress = null;
      _previewRevision = newId();
    });
    try {
      await _save(silent: true);
      await _prepareCapture(snapshot: snapshot);
      if (!mounted) return;
      setState(() => _captureIndex = _selected);
      final bytes = await _capturePng();
      final file = File(
        '${_store.root!.path}/exports/${snapshot ? 'snapshot' : 'template'}-${newId()}.png',
      );
      await file.writeAsBytes(bytes);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'image/png')],
          subject:
              '${_project.title} — ${snapshot ? 'snapshot' : 'transparent template'}',
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
  ) => Column(
    children: [
      Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
          Text(display, style: const TextStyle(color: mint, fontSize: 12)),
        ],
      ),
      Slider(value: value, min: min, max: max, onChanged: onChanged),
    ],
  );

  Future<void> _export() async {
    if (_project.clips.isEmpty || _exporting) return;
    setState(() {
      _exporting = true;
      _progress = null;
      _status = 'Preparing your reel…';
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
      await _prepareCapture();
      final overlays = <String>[];
      for (var i = 0; i < _project.clips.length; i++) {
        if (!mounted) return;
        setState(() => _captureIndex = i);
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
          _captureIndex = max(0, _project.clipAt(position));
        });
        final file = File('${temp.path}/intro_$frame.png');
        await file.writeAsBytes(await _capturePng());
        introFrames.add(file.path);
      }
      if (mounted) setState(() => _capturePosition = null);
      _progressSubscription = _renderer.progress.listen((value) {
        if (mounted) {
          setState(() {
            _progress = value;
            _status = 'Rendering MP4 on this device…';
          });
        }
      });
      final path = await _renderer.export(
        _project,
        overlays,
        introFrames: introFrames,
      );
      if (!mounted) return;
      setState(() => _status = 'Reel exported');
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
          _progress = null;
        });
      }
    }
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
                onTap: _rename,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _project.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Text(
                      'MAPS PLACE STORY · 9:16',
                      style: TextStyle(
                        fontSize: 9,
                        color: mint,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                IconButton(
                  tooltip: 'Save project',
                  onPressed: _save,
                  icon: Icon(
                    _dirty ? Icons.save_outlined : Icons.check_circle_outline,
                    color: mint,
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'More project options',
                  icon: const Icon(Icons.more_horiz),
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
                      child: Text('Rename project'),
                    ),
                    PopupMenuItem(
                      value: 'settings',
                      child: Text('Maps API settings'),
                    ),
                    PopupMenuItem(
                      value: 'backup',
                      child: Text('Share project backup'),
                    ),
                    PopupMenuItem(
                      value: 'projects',
                      child: Text('Open or import a project'),
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
                            0 => _editTab(),
                            1 => _timelineTab(),
                            3 => AudioEditor(
                              project: _project,
                              importing: _importing,
                              onPick: _pickMusic,
                              onChanged: _change,
                            ),
                            _ => _exportTab(),
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
              child: Material(
                color: Colors.black87,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(30),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.movie_creation_outlined,
                          size: 44,
                          color: mint,
                        ),
                        const SizedBox(height: 20),
                        Text(_status, textAlign: TextAlign.center),
                        const SizedBox(height: 20),
                        LinearProgressIndicator(value: _progress),
                        const SizedBox(height: 12),
                        Text(
                          _progress == null
                              ? 'Keep the app open while rendering'
                              : '${(_progress! * 100).round()}%',
                        ),
                        const SizedBox(height: 18),
                        TextButton(
                          onPressed: _progressSubscription == null
                              ? null
                              : _renderer.cancel,
                          child: const Text('Cancel export'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _preview({double maxHeight = 420}) => TimelinePreview(
    key: ValueKey(_previewRevision),
    project: _project,
    selected: _selected,
    maxHeight: maxHeight,
  );
  void _goToStep(int step) => setState(() {
    _tab = step;
    _previewRevision = newId();
  });

  Widget _editTab() => Column(
    children: [
      InspectorTabs(
        labels: const ['Details', 'Look', 'Header', 'Buttons', 'Review'],
        selected: _placeTool,
        onSelected: (i) => setState(() => _placeTool = i),
      ),
      Expanded(
        child: ListView(
          key: ValueKey('place-inspector-$_placeTool'),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          children: switch (_placeTool) {
            0 => [
              FilledButton.icon(
                onPressed: _findPlace,
                icon: const Icon(Icons.search, size: 18),
                label: const Text('Find a place on Google Maps'),
              ),
              const SizedBox(height: 16),
              _field('Place name', _name),
              _field('Category & description', _category),
              _field('Address', _address),
              ExpansionTile(
                title: const Text('More place details'),
                tilePadding: EdgeInsets.zero,
                children: [
                  _field(
                    'Rating',
                    _rating,
                    keyboard: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  _field('Local / alternate place name', _localName),
                  _field(
                    'Review count',
                    _reviews,
                    keyboard: TextInputType.number,
                  ),
                  _field('Price / price range', _price),
                  _field('Hours / open status', _hours),
                ],
              ),
            ],
            1 => [
              OutputThemePicker(project: _project, onChanged: _change),
              const Divider(height: 28),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Story controls overlay'),
                subtitle: const Text('Decorative controls from the reference'),
                value: _project.storyChrome,
                onChanged: (v) {
                  _project.storyChrome = v;
                  _change();
                },
              ),
            ],
            2 => [
              TemplateContentEditor(
                project: _project,
                loading: _importing,
                showReview: false,
                onChanged: _change,
                onLoadMap: _loadMap,
                onUploadMap: _uploadMap,
              ),
              if (_project.headerMode == 'photo' && _project.clips.isNotEmpty)
                _heroPicker(),
              if (_project.headerMode == 'photo' && _project.clips.isEmpty)
                TextButton.icon(
                  onPressed: () => _goToStep(1),
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('Add media in Timeline'),
                ),
            ],
            3 => [
              PlaceActionsEditor(
                key: ValueKey(
                  'actions-${_project.id}-${_project.place.placeId}',
                ),
                place: _project.place,
                expanded: true,
                onChanged: _change,
              ),
            ],
            _ => [
              TemplateContentEditor(
                project: _project,
                loading: _importing,
                showHeader: false,
                expanded: true,
                onChanged: _change,
                onLoadMap: _loadMap,
                onUploadMap: _uploadMap,
              ),
            ],
          },
        ),
      ),
    ],
  );

  Widget _heroPicker() => DropdownButtonFormField<String>(
    key: ValueKey('hero-${_project.id}-${_project.heroClip?.id}'),
    initialValue: _project.heroClip?.id,
    decoration: const InputDecoration(labelText: 'Peeking header photo'),
    isExpanded: true,
    items: _project.clips
        .map(
          (c) => DropdownMenuItem(
            value: c.id,
            child: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        )
        .toList(),
    onChanged: (id) {
      _project.heroClipId = id;
      _previewRevision = newId();
      _change();
    },
  );
  Widget _field(
    String name,
    TextEditingController controller, {
    TextInputType? keyboard,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: controller,
      keyboardType: keyboard,
      onChanged: (_) => _change(),
      decoration: InputDecoration(labelText: name),
    ),
  );
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
  Widget _timelineTab() => LayoutBuilder(
    builder: (context, bounds) {
      final compact =
          bounds.maxHeight < 240 || MediaQuery.viewInsetsOf(context).bottom > 0;
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: compact && _project.clips.isNotEmpty
                      ? DropdownButton<int>(
                          value: _selected,
                          isExpanded: true,
                          underline: const SizedBox(),
                          items: [
                            for (var i = 0; i < _project.clips.length; i++)
                              DropdownMenuItem(
                                value: i,
                                child: Text(
                                  '${i + 1}. ${_project.clips[i].name}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                          ],
                          onChanged: (i) {
                            if (i != null) {
                              setState(() {
                                _selected = i;
                                _previewRevision = newId();
                              });
                            }
                          },
                        )
                      : Text(
                          '${_project.clips.length} clips · ${_project.duration.toStringAsFixed(1)} seconds',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white60,
                          ),
                        ),
                ),
                TextButton.icon(
                  onPressed: _importing ? null : _pickMedia,
                  icon: const Icon(Icons.add, size: 17),
                  label: Text(_importing ? 'Importing…' : 'Add media'),
                ),
              ],
            ),
          ),
          if (_project.clips.isNotEmpty) ...[
            if (!compact)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: _clipStrip(),
              ),
            Row(
              children: [
                Expanded(
                  child: InspectorTabs(
                    labels: const ['Timing', 'Frame', 'Motion'],
                    selected: _timelineTool,
                    onSelected: (i) => setState(() => _timelineTool = i),
                  ),
                ),
                IconButton(
                  tooltip: 'Remove clip ${_selected + 1}',
                  icon: const Icon(Icons.delete_outline, size: 19),
                  onPressed: () {
                    _project.clips.removeAt(_selected);
                    _selected = min(
                      _selected,
                      max(0, _project.clips.length - 1),
                    );
                    _captureIndex = 0;
                    _previewRevision = newId();
                    _change();
                  },
                ),
                const SizedBox(width: 8),
              ],
            ),
            Expanded(
              child: ListView(
                key: ValueKey('timeline-inspector-$_timelineTool'),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                children: [
                  if (_timelineTool == 2)
                    _motionInspector()
                  else
                    _clipCard(_selected.clamp(0, _project.clips.length - 1)),
                ],
              ),
            ),
          ] else
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const Icon(
                    Icons.video_collection_outlined,
                    color: Colors.white30,
                    size: 34,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Start with your photos & videos',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Add media, tap a clip to edit it, then set the pace.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  _addMedia(),
                ],
              ),
            ),
        ],
      );
    },
  );

  Widget _motionInspector() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Opening scroll reveal',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 12),
      _framingControl(
        'Reveal duration',
        _project.sheetIntroSeconds,
        0,
        2,
        '${_project.sheetIntroSeconds.toStringAsFixed(1)}s',
        (v) {
          _project.sheetIntroSeconds = v < .1 ? 0 : v;
          _previewRevision = newId();
          _change();
        },
      ),
      const Text(
        'Set to zero to start with the sheet already in position.',
        style: TextStyle(fontSize: 11, color: Colors.white54),
      ),
      const Divider(height: 28),
      const Text(
        'Left-scroll snap',
        style: TextStyle(fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 12),
      _framingControl(
        'Slide speed',
        _project.slideSeconds,
        .15,
        .8,
        '${_project.slideSeconds.toStringAsFixed(2)}s',
        (v) {
          _project.slideSeconds = v;
          _change();
        },
      ),
      const Text(
        'Slide time is included in each clip’s duration.',
        style: TextStyle(fontSize: 11, color: Colors.white54),
      ),
      TextButton(
        onPressed: () {
          for (final c in _project.clips) {
            c.duration = 1.56;
            c.normalize();
          }
          _project.slideSeconds = .35;
          _previewRevision = newId();
          _change();
        },
        child: const Text('Use reference pace · 1.56s per card'),
      ),
    ],
  );
  Widget _clipStrip() => SizedBox(
    height: 72,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: _project.clips.length,
      separatorBuilder: (_, _) => const SizedBox(width: 5),
      itemBuilder: (_, i) {
        final c = _project.clips[i];
        return Semantics(
          label: 'Clip ${i + 1}: ${c.name}',
          selected: i == _selected,
          button: true,
          child: Tooltip(
            message: c.name,
            child: InkWell(
              onTap: () => setState(() {
                _selected = i;
                _previewRevision = newId();
              }),
              child: Container(
                width: (c.duration * 12).clamp(78, 150),
                decoration: BoxDecoration(
                  color: panel,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: i == _selected ? mint : Colors.white12,
                    width: 2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipPoster(clip: c),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black87],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 6,
                        top: 5,
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 6,
                        right: 4,
                        bottom: 6,
                        child: Text(
                          '${c.duration.toStringAsFixed(1)}s',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );

  Widget _clipCard(int index) {
    final clip = _project.clips[index];
    return Card(
      key: ValueKey(clip.id),
      margin: const EdgeInsets.only(bottom: 12),
      color: panel,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_timelineTool == 0) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Duration · ${clip.duration.toStringAsFixed(1)}s',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Move clip earlier',
                    onPressed: index == 0 ? null : () => _move(index, -1),
                    icon: const Icon(Icons.chevron_left, size: 18),
                  ),
                  IconButton(
                    tooltip: 'Move clip later',
                    onPressed: index == _project.clips.length - 1
                        ? null
                        : () => _move(index, 1),
                    icon: const Icon(Icons.chevron_right, size: 18),
                  ),
                ],
              ),
              Slider(
                value: clip.duration,
                min: min(.5, clip.maxDuration),
                max: max(.5, clip.maxDuration),
                onChanged: (v) {
                  clip.duration = v;
                  clip.normalize();
                  _change();
                },
              ),
              if (clip.isVideo &&
                  clip.sourceDuration > clip.duration + .01) ...[
                Text(
                  'Start at ${clip.trimStart.toStringAsFixed(1)}s of ${clip.sourceDuration.toStringAsFixed(1)}s',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
                Slider(
                  value: clip.trimStart,
                  max: max(.01, clip.sourceDuration - clip.duration),
                  onChanged: (v) {
                    clip.trimStart = v;
                    clip.normalize();
                    _change();
                  },
                ),
              ],
              TextFormField(
                key: ValueKey('caption-${clip.id}'),
                initialValue: clip.caption,
                maxLength: 120,
                decoration: const InputDecoration(
                  labelText: 'Caption (optional)',
                  counterText: '',
                ),
                onChanged: (v) {
                  clip.caption = v;
                  _change();
                },
              ),
            ],
            if (_timelineTool == 1)
              Column(
                children: [
                  _framingControl(
                    'Card width',
                    clip.cardWidth,
                    .45,
                    1,
                    '${(clip.cardWidth * 328).round()} px',
                    (v) {
                      clip.cardWidth = v;
                      _change();
                    },
                  ),
                  _framingControl(
                    'Card height',
                    clip.cardHeight,
                    .55,
                    1,
                    '${(clip.cardHeight * 250).round()} px',
                    (v) {
                      clip.cardHeight = v;
                      _change();
                    },
                  ),
                  _framingControl(
                    'Zoom',
                    clip.zoom,
                    1,
                    3,
                    '${clip.zoom.toStringAsFixed(2)}×',
                    (v) {
                      clip.zoom = v;
                      _change();
                    },
                  ),
                  _framingControl(
                    'Horizontal crop',
                    clip.panX,
                    -1,
                    1,
                    '${(clip.panX * 100).round()}%',
                    (v) {
                      clip.panX = v;
                      _change();
                    },
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _move(int index, int delta) {
    final clip = _project.clips.removeAt(index);
    _project.clips.insert(index + delta, clip);
    _selected = index + delta;
    _previewRevision = newId();
    _change();
  }

  Widget _exportTab() {
    final needsMap =
        _project.headerMode == 'map' && _project.mapHeaderPath == null;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: panel,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '1080 × 1920',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Vertical MP4 · H.264 · ${_project.music == null ? 'Silent' : 'With music'}',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${_project.clips.length} clips · ${_project.duration.toStringAsFixed(1)} seconds',
                      style: const TextStyle(color: mint, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (_project.clips.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Add at least one photo or video in Timeline to export.',
                    style: TextStyle(color: Colors.white60),
                  ),
                ),
              if (needsMap)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Your map header needs an image.',
                          style: TextStyle(color: Colors.white60, fontSize: 12),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          _placeTool = 2;
                          _goToStep(0);
                        },
                        child: const Text('Set up header'),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Still images'),
                subtitle: const Text('Transparent template or full snapshot'),
                children: [
                  OutlinedButton.icon(
                    onPressed: needsMap ? null : () => _exportPng(false),
                    icon: const Icon(Icons.layers_outlined),
                    label: const Text('Transparent template PNG'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _project.clips.isEmpty || needsMap
                        ? null
                        : () => _exportPng(true),
                    icon: const Icon(Icons.image_outlined),
                    label: const Text('Full snapshot PNG'),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
              const Divider(height: 24),
              TextButton.icon(
                onPressed: _backup,
                icon: const Icon(Icons.inventory_2_outlined, size: 18),
                label: const Text('Share project backup'),
              ),
              const Text(
                'Your project and media autosave on this device.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _project.clips.isEmpty || _importing || needsMap
                  ? null
                  : _export,
              icon: const Icon(Icons.file_download_outlined),
              label: const Text('Render MP4'),
            ),
          ),
        ),
      ],
    );
  }
}

class PlaceSearchDialog extends StatefulWidget {
  final String apiKey, initial;
  const PlaceSearchDialog({
    super.key,
    required this.apiKey,
    required this.initial,
  });
  @override
  State<PlaceSearchDialog> createState() => _PlaceSearchDialogState();
}

class _PlaceSearchDialogState extends State<PlaceSearchDialog> {
  late final _query = TextEditingController(text: widget.initial);
  late final _places = PlacesService(widget.apiKey);
  List<PlaceDetails> _results = [];
  bool _loading = false;
  String? _message;
  Future<void> _search() async {
    if (_query.text.trim().isEmpty || _loading) return;
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final places = await _places.search(_query.text);
      if (mounted) {
        setState(() {
          _results = places;
          if (places.isEmpty) {
            _message = 'No places found. Try a name and city.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _message = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _query.dispose();
    _places.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Find a place'),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _query,
              autofocus: true,
              onSubmitted: (_) => _search(),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Place name and city',
                suffixIcon: IconButton(
                  onPressed: _loading ? null : _search,
                  icon: const Icon(Icons.search),
                ),
              ),
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(_message!, style: const TextStyle(fontSize: 12)),
              ),
            ..._results.map(
              (p) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.place_outlined, color: mint),
                title: Text(p.name),
                subtitle: Text(p.address),
                onTap: () => Navigator.pop(context, p),
              ),
            ),
            const SizedBox(height: 14),
            const Text('Google Maps', style: TextStyle(color: Colors.white60)),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
    ],
  );
}

class ExportedVideoPage extends StatefulWidget {
  final String path;
  final NativeRenderer renderer;
  const ExportedVideoPage({
    super.key,
    required this.path,
    required this.renderer,
  });
  @override
  State<ExportedVideoPage> createState() => _ExportedVideoPageState();
}

class _ExportedVideoPageState extends State<ExportedVideoPage> {
  late final _controller = VideoPlayerController.file(File(widget.path));
  String? _error;
  bool _saved = false, _saving = false;
  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    try {
      await _controller.initialize();
      await _controller.setLooping(true);
      if (mounted) {
        setState(() {});
        await _controller.play();
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'The video was exported but playback could not start. You can still share or save it.',
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Your reel is ready')),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: _error != null
                    ? Text(_error!)
                    : !_controller.value.isInitialized
                    ? const CircularProgressIndicator()
                    : GestureDetector(
                        onTap: () {
                          setState(() {
                            _controller.value.isPlaying
                                ? _controller.pause()
                                : _controller.play();
                          });
                        },
                        child: AspectRatio(
                          aspectRatio: _controller.value.aspectRatio,
                          child: VideoPlayer(_controller),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () async {
                try {
                  await SharePlus.instance.share(
                    ShareParams(
                      files: [XFile(widget.path, mimeType: 'video/mp4')],
                      subject: 'My Mockareel',
                    ),
                  );
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Could not open the share sheet. Try saving to gallery.',
                        ),
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.share),
              label: const Text('Share video'),
            ),
            OutlinedButton.icon(
              onPressed: _saving || _saved
                  ? null
                  : () async {
                      setState(() => _saving = true);
                      try {
                        await widget.renderer.saveToGallery(widget.path);
                        if (mounted) setState(() => _saved = true);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                e is PlatformException
                                    ? e.message ?? 'Save failed'
                                    : e.toString(),
                              ),
                            ),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _saving = false);
                      }
                    },
              icon: const Icon(Icons.save_alt),
              label: Text(
                _saved
                    ? 'Saved to Movies/Mockareel'
                    : _saving
                    ? 'Saving…'
                    : 'Save to gallery',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
