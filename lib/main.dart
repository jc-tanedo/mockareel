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
import 'services/native_renderer.dart';
import 'services/places.dart';
import 'services/project_store.dart';
import 'widgets/reel_preview.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MockareelApp());
}

const ink = Color(0xff0a1018),
    panel = Color(0xff111b27),
    mint = Color(0xff55e3c0);

class MockareelApp extends StatelessWidget {
  final ProjectStore? store;
  const MockareelApp({super.key, this.store});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Mockareel',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
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
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    ),
    home: EditorPage(store: store),
  );
}

class EditorPage extends StatefulWidget {
  final ProjectStore? store;
  const EditorPage({super.key, this.store});
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
      _hours = TextEditingController(),
      _badge = TextEditingController();
  ReelProject _project = ReelProject();
  int _tab = 0, _selected = 0, _captureIndex = 0, _editRevision = 0;
  bool _ready = false, _importing = false, _exporting = false, _dirty = false;
  double? _progress;
  String _key = '', _status = '', _previewRevision = 'initial';
  String? _captureHeroPath;
  bool _captureSnapshot = false;
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
    _badge,
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
      final project = await _store.restore();
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
    _capturePosters = {};
    _name.text = project.place.name;
    _category.text = project.place.category;
    _rating.text = project.place.rating;
    _address.text = project.place.address;
    _localName.text = project.place.localName;
    _reviews.text = project.place.reviewCount;
    _price.text = project.place.price;
    _hours.text = project.place.hours;
    _badge.text = project.storyBadge;
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
    _project.storyBadge = _badge.text;
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
  }

  Future<void> _projects() async {
    await _save(silent: true);
    final projects = await _store.projects();
    if (!mounted) return;
    final result = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SizedBox(
          height: 440,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Your projects',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => Navigator.pop(ctx, 'new'),
                      icon: const Icon(Icons.add),
                      label: const Text('New'),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.file_open_outlined),
                title: const Text('Import a project backup'),
                onTap: () => Navigator.pop(ctx, 'import'),
              ),
              Expanded(
                child: ListView(
                  children: projects
                      .map(
                        (p) => ListTile(
                          leading: const Icon(Icons.movie_outlined),
                          title: Text(p.title),
                          subtitle: Text(
                            '${p.clips.length} clips · ${p.duration.toStringAsFixed(1)} seconds',
                          ),
                          trailing: p.id == _project.id
                              ? const Icon(Icons.check, color: mint)
                              : null,
                          onTap: () => Navigator.pop(ctx, p),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || result == null) return;
    if (result == 'import') {
      await _importBackup();
      return;
    }
    setState(() => _setProject(result is ReelProject ? result : ReelProject()));
    await _save(silent: true);
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

  Future<void> _importBackup() async {
    try {
      final file = await FilePicker.pickFile(type: FileType.any);
      final path = file?.path;
      if (path == null) return;
      final project = await _store.importBackup(path);
      if (mounted) setState(() => _setProject(project));
      _toast('Project imported with its media');
    } catch (e) {
      _toast('Import failed: ${_error(e)}');
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
    final hero = _project.heroClip;
    String? heroPath;
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
      _progressSubscription = _renderer.progress.listen((value) {
        if (mounted) {
          setState(() {
            _progress = value;
            _status = 'Rendering MP4 on this device…';
          });
        }
      });
      final path = await _renderer.export(_project, overlays);
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
                          _project.startOf(_captureIndex) +
                          TemplateLayout.transitionDuration(
                            _project,
                            _captureIndex,
                          ),
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
                tooltip: 'Saved projects',
                onPressed: _projects,
                icon: const Icon(Icons.folder_open_outlined),
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
                IconButton(
                  tooltip: 'Maps API settings',
                  onPressed: _settings,
                  icon: const Icon(Icons.settings_outlined),
                ),
              ],
            ),
            body: switch (_tab) {
              0 => _editTab(),
              1 => _timelineTab(),
              _ => _exportTab(),
            },
            bottomNavigationBar: NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: (i) => setState(() {
                _tab = i;
                _previewRevision = newId();
              }),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.edit_location_alt_outlined),
                  label: 'Place',
                ),
                NavigationDestination(
                  icon: Icon(Icons.video_collection_outlined),
                  label: 'Timeline',
                ),
                NavigationDestination(
                  icon: Icon(Icons.ios_share),
                  label: 'Export',
                ),
              ],
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

  Widget _preview() => TimelinePreview(
    key: ValueKey(_previewRevision),
    project: _project,
    selected: _selected,
  );
  Widget _editTab() => ListView(
    padding: const EdgeInsets.all(18),
    children: [
      _preview(),
      const SizedBox(height: 8),
      FilledButton.icon(
        onPressed: _findPlace,
        icon: const Icon(Icons.search),
        label: const Text('Find a place on Google Maps'),
      ),
      const SizedBox(height: 20),
      const Text(
        'PLACE DETAILS',
        style: TextStyle(color: mint, fontSize: 11, letterSpacing: 1.5),
      ),
      const SizedBox(height: 12),
      _field('Place name', _name),
      _field('Category & description', _category),
      _field(
        'Rating',
        _rating,
        keyboard: const TextInputType.numberWithOptions(decimal: true),
      ),
      _field('Address', _address),
      ExpansionTile(
        title: const Text('Template details'),
        tilePadding: EdgeInsets.zero,
        children: [
          _field('Local / alternate place name', _localName),
          _field('Review count', _reviews, keyboard: TextInputType.number),
          _field('Price / price range', _price),
          _field('Hours / open status', _hours),
          _field('Story badge (optional)', _badge),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Story controls overlay'),
            subtitle: const Text(
              'Add the reference’s decorative story controls',
            ),
            value: _project.storyChrome,
            onChanged: (v) {
              _project.storyChrome = v;
              _change();
            },
          ),
          if (_project.clips.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: DropdownButtonFormField<String>(
                key: ValueKey('hero-${_project.id}-${_project.heroClip?.id}'),
                initialValue: _project.heroClip?.id,
                decoration: const InputDecoration(
                  labelText: 'Peeking header photo',
                ),
                isExpanded: true,
                items: _project.clips
                    .map(
                      (c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(
                          c.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (id) {
                  _project.heroClipId = id;
                  _previewRevision = newId();
                  _change();
                },
              ),
            ),
        ],
      ),
      const Text(
        'All details remain editable after lookup.',
        style: TextStyle(fontSize: 12, color: Colors.white60),
      ),
      const SizedBox(height: 18),
      _addMedia(),
    ],
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
  Widget _timelineTab() => ListView(
    padding: const EdgeInsets.all(18),
    children: [
      _preview(),
      _addMedia(),
      ExpansionTile(
        title: const Text('Left-scroll snap'),
        tilePadding: EdgeInsets.zero,
        children: [
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
            'Each card slides in, snaps fully into view, then holds. Slide time is included in the clip duration.',
            style: TextStyle(fontSize: 12, color: Colors.white60),
          ),
          TextButton(
            onPressed: _project.clips.isEmpty
                ? null
                : () {
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
      ),
      const SizedBox(height: 16),
      Text(
        '${_project.clips.length} clips · ${_project.duration.toStringAsFixed(1)} seconds',
        style: const TextStyle(color: mint),
      ),
      const SizedBox(height: 8),
      if (_project.clips.isEmpty)
        const Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'Add your photos and videos to build the reel. Every clip gets its own timing and caption.',
            textAlign: TextAlign.center,
          ),
        ),
      for (var i = 0; i < _project.clips.length; i++) _clipCard(i),
    ],
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
            Row(
              children: [
                Icon(
                  clip.isVideo ? Icons.videocam_outlined : Icons.image_outlined,
                  color: mint,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${index + 1}. ${clip.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: 'Preview clip ${index + 1}',
                  onPressed: () => setState(() {
                    _selected = index;
                    _previewRevision = newId();
                  }),
                  icon: const Icon(Icons.play_arrow),
                ),
                IconButton(
                  tooltip: 'Remove clip ${index + 1}',
                  onPressed: () {
                    _project.clips.removeAt(index);
                    _selected = min(
                      _selected,
                      max(0, _project.clips.length - 1),
                    );
                    _captureIndex = 0;
                    _previewRevision = newId();
                    _change();
                  },
                  icon: const Icon(Icons.close, size: 19),
                ),
              ],
            ),
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
                  tooltip: 'Move clip up',
                  onPressed: index == 0 ? null : () => _move(index, -1),
                  icon: const Icon(Icons.arrow_upward, size: 18),
                ),
                IconButton(
                  tooltip: 'Move clip down',
                  onPressed: index == _project.clips.length - 1
                      ? null
                      : () => _move(index, 1),
                  icon: const Icon(Icons.arrow_downward, size: 18),
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
            if (clip.isVideo && clip.sourceDuration > clip.duration + .01) ...[
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
            ExpansionTile(
              key: ValueKey('framing-${clip.id}'),
              title: const Text('Card framing'),
              tilePadding: EdgeInsets.zero,
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

  Widget _exportTab() => ListView(
    padding: const EdgeInsets.all(22),
    children: [
      const SizedBox(height: 16),
      const Icon(Icons.movie_creation_outlined, size: 55, color: mint),
      const SizedBox(height: 18),
      const Text(
        'Your place. Your story.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 12),
      Text(
        '${_project.clips.length} clips · ${_project.duration.toStringAsFixed(1)} seconds',
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 10),
      const Text(
        'Vertical MP4 · 1080 × 1920\nSilent video · cards scroll left and snap\nYour framing, captions and place details included',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white60, height: 1.7),
      ),
      const SizedBox(height: 26),
      FilledButton.icon(
        onPressed: _project.clips.isEmpty || _importing ? null : _export,
        icon: const Icon(Icons.file_download_outlined),
        label: const Text('Render MP4'),
      ),
      if (_project.clips.isEmpty)
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            'Add at least one photo or video in Timeline to export.',
            textAlign: TextAlign.center,
          ),
        ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: () => _exportPng(false),
        icon: const Icon(Icons.layers_outlined),
        label: const Text('Transparent template PNG'),
      ),
      OutlinedButton.icon(
        onPressed: _project.clips.isEmpty ? null : () => _exportPng(true),
        icon: const Icon(Icons.image_outlined),
        label: const Text('Full snapshot PNG'),
      ),
      const SizedBox(height: 22),
      const Divider(),
      const SizedBox(height: 12),
      const Text(
        'Keep creating later',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 8),
      const Text(
        'Projects autosave on this device. Backups include the media, timings, captions and place details so they can be imported on another device.',
        style: TextStyle(color: Colors.white60, height: 1.5),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: _backup,
        icon: const Icon(Icons.inventory_2_outlined),
        label: const Text('Share project backup'),
      ),
      TextButton.icon(
        onPressed: _projects,
        icon: const Icon(Icons.folder_open_outlined),
        label: const Text('Open or import a project'),
      ),
    ],
  );
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
