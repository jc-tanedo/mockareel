import '../services/gif_media.dart';
import '../services/media_importer.dart';
import '../widgets/export_monitor.dart';
import '../services/feed_capture_plan.dart';
import '../widgets/feed_export_panel.dart';
import '../widgets/feed_posts_editor.dart';
import '../widgets/feed_sequence_editor.dart';
import '../widgets/project_name_dialog.dart';
import '../model/feed_timeline.dart';
import '../pages/exported_video_page.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:image_picker/image_picker.dart';
import '../model/project.dart';
import '../services/native_renderer.dart';
import '../services/project_store.dart';
import '../widgets/audio_editor.dart';
import '../widgets/creation_steps.dart';
import '../widgets/editor_workspace.dart';
import '../widgets/feed_canvas.dart';
import '../widgets/reel_preview.dart';

class FeedEditorPage extends StatefulWidget {
  final ProjectStore store;
  final ReelProject project;
  const FeedEditorPage({super.key, required this.store, required this.project});
  @override
  State<FeedEditorPage> createState() => _FeedEditorPageState();
}

class _FeedEditorPageState extends State<FeedEditorPage>
    with WidgetsBindingObserver {
  ReelProject get p => widget.project;
  final _renderer = NativeRenderer(), _captureKey = GlobalKey();
  int _tab = 0, _selected = 0, _postTool = 0, _revision = 0;
  bool _busy = false, _exporting = false, _dirty = false, _cancelled = false;
  String _status = '';
  double? _progress;
  Timer? _autosave;
  StreamSubscription<double>? _subscription;
  double _captureTime = 0, _exportPosition = 0;
  ExportPhase _exportPhase = ExportPhase.preparing;
  bool _overlayOnly = false;
  Map<String, String> _posters = {};
  static const _labels = ['Sequence', 'Posts', 'Audio', 'Export'];
  static const _titles = [
    'Set the scene',
    'Build your feed',
    'Choose your music',
    'Review & export',
  ];
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _dirty) unawaited(_save());
  }

  void _change() {
    setState(() => _dirty = true);
    _revision++;
    _autosave?.cancel();
    _autosave = Timer(const Duration(milliseconds: 700), _save);
  }

  Future<bool> _save() async {
    _autosave?.cancel();
    final revision = _revision;
    try {
      await widget.store.save(p);
      if (mounted && revision == _revision) setState(() => _dirty = false);
      return true;
    } catch (_) {
      _toast('Could not save project. Check device storage.');
      return false;
    }
  }

  void _toast(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _back() async {
    if (await _save() && mounted && context.mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _rename() async {
    final title = await showDialog<String>(
      context: context,
      builder: (_) => ProjectNameDialog(initialValue: p.title),
    );
    if (title != null && title.isNotEmpty && mounted) {
      p.title = title;
      _change();
    }
  }

  Future<void> _backup() async {
    try {
      await _save();
      await MediaImporter.shareProjectBackup(p, widget.store);
    } catch (_) {
      _toast('Could not share the project backup.');
    }
  }

  Future<void> _pickMedia() async {
    setState(() => _busy = true);
    var failures = 0;
    try {
      final files = await ImagePicker().pickMultipleMedia();
      for (final file in files) {
        try {
          final clip = await MediaImporter.retainClip(
            file,
            store: widget.store,
            renderer: _renderer,
            defaultDuration: 5,
            cardWidth: 1,
          );
          if (!mounted) return;
          p.clips.add(clip);
          _selected = p.clips.length - 1;
        } catch (_) {
          failures++;
        }
      }
      if (mounted) _change();
      if (failures > 0) {
        _toast('$failures files could not be opened. Try JPG/PNG or MP4.');
      }
    } catch (_) {
      _toast('Could not open the media picker.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickHome() async {
    setState(() => _busy = true);
    try {
      final file = await ImagePicker().pickMedia();
      if (file == null) return;
      final c = await MediaImporter.retainClip(
        file,
        store: widget.store,
        renderer: _renderer,
        defaultDuration: 5,
        cardWidth: 1,
      );
      if (mounted) {
        p.feed.homeMedia = c;
        _change();
      }
    } catch (_) {
      _toast('Could not open this home-screen media.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickAvatar(ReelClip clip) async {
    setState(() => _busy = true);
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (file == null) return;
      final path = await widget.store.retainMedia(file.path, file.name);
      if (mounted) {
        clip.post.avatarPath = path;
        _change();
      }
    } catch (_) {
      _toast('Could not open this profile photo.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickMusic() async {
    setState(() => _busy = true);
    try {
      final track = await MediaImporter.pickMusicTrack(
        store: widget.store,
        renderer: _renderer,
      );
      if (track != null && mounted) {
        p.music = track;
        _change();
      }
    } catch (_) {
      _toast('Choose an audio file your device can play.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _move(int delta) {
    final next = _selected + delta;
    if (next < 0 || next >= p.clips.length) return;
    final c = p.clips.removeAt(_selected);
    p.clips.insert(next, c);
    _selected = next;
    _change();
  }

  void _removePost() {
    if (p.clips.isEmpty) return;
    final index = _selected;
    final clip = p.clips.removeAt(index);
    if (_selected >= p.clips.length) {
      _selected = max(0, p.clips.length - 1);
    }
    _change();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Removed ${clip.name}'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            p.clips.insert(min(index, p.clips.length), clip);
            _selected = min(index, p.clips.length - 1);
            _change();
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autosave?.cancel();
    _subscription?.cancel();
    if (_exporting) _renderer.cancel();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return PopScope(
      canPop: !_exporting,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && _dirty) unawaited(_save());
      },
      child: Stack(
        children: [
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
                    child: FeedCanvas(
                      project: p,
                      position: _captureTime,
                      overlayOnly: _overlayOnly,
                      posterOnly: true,
                      posters: _posters,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Scaffold(
            appBar: AppBar(
              leading: IconButton(
                tooltip: 'Back to projects',
                onPressed: _exporting ? null : _back,
                icon: const Icon(Icons.arrow_back),
              ),
              titleSpacing: 0,
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
                              p.title,
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
                        'TIKTOK FYP SCROLL · 9:16',
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
                  onPressed: () async {
                    if (await _save()) _toast('Project saved on this device');
                  },
                  icon: Icon(
                    _dirty ? Icons.save_outlined : Icons.check_circle_outline,
                    color: _dirty ? colors.primary : colors.onSurfaceVariant,
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'More project options',
                  icon: const Icon(Icons.more_vert),
                  onSelected: (s) {
                    if (s == 'rename') _rename();
                    if (s == 'backup') _backup();
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
                      value: 'backup',
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.ios_share_outlined),
                        title: Text('Share project backup'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            body: Column(
              children: [
                if (!keyboard)
                  CreationStepHeading(
                    step: _tab,
                    onNext: () => setState(() => _tab++),
                    stepLabels: _labels,
                    stepTitles: _titles,
                    stepDescriptions: null,
                  ),
                Expanded(
                  child: _exporting
                      ? const SizedBox.expand()
                      : EditorWorkspace(
                          keyboardVisible: keyboard,
                          previewFraction: .5,
                          hint: _tab == 1
                              ? 'LIVE PREVIEW · POST ${_selected + 1}'
                              : 'LIVE PREVIEW · FULL SEQUENCE',
                          previewBuilder: (height) => TimelinePreview(
                            key: ValueKey(
                              '${p.id}-${_tab == 1 ? _selected : -1}',
                            ),
                            project: p,
                            selected: _tab == 1 ? _selected : 0,
                            startAtBeginning: _tab != 1,
                            maxHeight: height,
                          ),
                          inspector: switch (_tab) {
                            0 => FeedSequenceEditor(
                              project: p,
                              busy: _busy,
                              onPickHome: _pickHome,
                              onChanged: _change,
                            ),
                            1 => FeedPostsEditor(
                              project: p,
                              selectedIndex: _selected,
                              postTool: _postTool,
                              busy: _busy,
                              onPickMedia: _pickMedia,
                              onSelectPost: (i) {
                                setState(() => _selected = i);
                              },
                              onSelectTool: (i) {
                                setState(() => _postTool = i);
                              },
                              onRemovePost: _removePost,
                              onMovePost: _move,
                              onPickAvatar: _pickAvatar,
                              onChanged: _change,
                            ),
                            2 => AudioEditor(
                              project: p,
                              importing: _busy,
                              onPick: _pickMusic,
                              onChanged: _change,
                            ),
                            _ => FeedExportPanel(
                              project: p,
                              busy: _busy,
                              onExport: _export,
                              onBackup: _backup,
                            ),
                          },
                        ),
                ),
              ],
            ),
            bottomNavigationBar: keyboard
                ? null
                : CreationSteps(
                    selected: _tab,
                    completed: [
                      true,
                      p.clips.isNotEmpty,
                      p.music != null,
                      false,
                    ],
                    customLabels: _labels,
                    optionalSteps: const {2},
                    onSelected: (i) => setState(() => _tab = i),
                  ),
          ),
          if (_exporting)
            Positioned.fill(
              child: ExportMonitor(
                title: p.title,
                status: _status,
                phase: _exportPhase,
                progress: _progress,
                position: _exportPosition,
                duration: FeedTimeline.duration(p),
                preview: IgnorePointer(
                  child: FeedCanvas(
                    project: p,
                    position: _exportPosition,
                    posterOnly: true,
                    posters: _posters,
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

  Future<void> _precache(String path) async {
    if (!mounted) return;
    await MediaImporter.precacheMediaImage(path, context);
  }

  Future<String> _capture(
    Directory dir,
    String name,
    double time, {
    bool overlay = false,
  }) async {
    if (_cancelled || !mounted) throw const FormatException('Export cancelled');
    setState(() {
      _captureTime = time;
      _exportPosition = time;
      _overlayOnly = overlay;
    });
    await SchedulerBinding.instance.endOfFrame;
    // Allow resolved poster futures to paint before reading the boundary.
    await SchedulerBinding.instance.endOfFrame;
    final boundary =
        _captureKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('${dir.path}/$name.png');
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      return file.path;
    } finally {
      image.dispose();
    }
  }

  Future<void> _export() async {
    if (_exporting || p.clips.isEmpty) return;
    setState(() {
      _exporting = true;
      _cancelled = false;
      _progress = null;
      _status = 'Preparing media…';
      _exportPhase = ExportPhase.preparing;
      _exportPosition = 0;
    });
    Directory? temp;
    try {
      if (!await _save()) return;
      temp = await Directory(
        '${widget.store.root!.path}/exports/feed_${newId()}',
      ).create();
      final posters = <String, String>{};
      for (final c in [
        ...p.clips,
        if (p.feed.homeMedia != null) p.feed.homeMedia!,
      ]) {
        if (_cancelled || !mounted) {
          throw const FormatException('Export cancelled');
        }
        if (!await File(c.path).exists()) {
          throw FormatException('“${c.name}” is missing. Replace this media.');
        }
        for (final end in [false, true]) {
          final path = await _renderer.poster(
            c,
            position: end ? c.duration - .001 : 0,
          );
          posters['${c.id}:${end ? 'end' : 'start'}'] = path;
          await _precache(path);
        }
      }
      for (final c in p.clips) {
        if (c.post.avatarPath != null) await _precache(c.post.avatarPath!);
      }
      if (!mounted) return;
      setState(() => _posters = posters);
      final clips = <Map<String, dynamic>>[],
          overlays = <String>[],
          frames = <List<String>>[],
          transitions = <double>[];
      final scenes = FeedTimeline.scenes(p);
      final totalFrames = scenes.fold<int>(0, (sum, scene) {
        final animated = scene.kind == 'post'
            ? FeedTimeline.transition(p, scene.postIndex)
            : scene.duration;
        return sum + (animated * 30).ceil() + 1;
      });
      var completedFrames = 0;
      for (var i = 0; i < scenes.length; i++) {
        final s = scenes[i];
        final isPost = s.kind == 'post';
        setState(
          () => _status = 'Preparing scene ${i + 1} of ${scenes.length}…',
        );
        final transition = isPost
            ? FeedTimeline.transition(p, s.postIndex)
            : 0.0;
        final animated = isPost ? transition : s.duration;
        final sceneFrames = <String>[];
        final cached = <String, String>{};
        // UI is static after each swipe; capture only the changing interval.
        for (var frame = 0; frame < (animated * 30).ceil(); frame++) {
          if (_cancelled || !mounted) {
            throw const FormatException('Export cancelled');
          }
          final key = FeedCapturePlan.key(p, s, frame);
          final path = cached[key] ??= await _capture(
            temp,
            'scene_${i}_$frame',
            s.start + frame / 30,
            overlay: true,
          );
          sceneFrames.add(path);
          completedFrames++;
          if (mounted) {
            setState(() => _progress = completedFrames / totalFrames * .35);
          }
        }
        final overlay = await _capture(
          temp,
          'overlay_$i',
          s.start + min(s.duration - .001, animated + .001),
          overlay: true,
        );
        completedFrames++;
        overlays.add(overlay);
        frames.add(sceneFrames);
        transitions.add(transition);
        ReelClip? source = isPost
            ? p.clips[s.postIndex]
            : s.kind.startsWith('home')
            ? p.feed.homeMedia
            : null;
        if (source == null) {
          final base = await _capture(temp, 'base_$i', s.start);
          clips.add(
            ReelClip(
              id: newId(),
              path: base,
              name: 'Scene',
              isVideo: false,
              duration: s.duration,
            ).toJson(),
          );
        } else {
          // Split a short video wallpaper into repeats; each copy reuses
          // the same UI scene clock.
          clips.add({
            ...source.toJson(),
            'duration': s.duration,
            'loopSource': !isPost && source.isTimed,
            'loopDuration': source.duration,
          });
        }
      }
      if (_cancelled) throw const FormatException('Export cancelled');
      if (mounted) {
        setState(() {
          _exportPhase = ExportPhase.encoding;
          _status = 'Encoding video…';
          _progress = .35;
          _exportPosition = 0;
        });
      }
      _subscription = _renderer.progress.listen((value) {
        if (mounted) {
          setState(() {
            _status = 'Encoding video…';
            _exportPosition = FeedTimeline.duration(p) * value.clamp(0, 1);
            _progress = .35 + .65 * value;
          });
        }
      });
      final path = await _renderer.exportFeed(
        clips: clips,
        overlays: overlays,
        frames: frames,
        transitions: transitions,
        music: p.music,
      );
      if (!mounted || _cancelled) return;
      setState(() {
        _exportPhase = ExportPhase.finishing;
        _status = 'Export complete';
        _progress = 1;
      });
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ExportedVideoPage(path: path, renderer: _renderer),
        ),
      );
    } catch (e) {
      _toast(e.toString().replaceFirst('FormatException: ', ''));
    } finally {
      await _subscription?.cancel();
      _subscription = null;
      if (temp != null && await temp.exists()) {
        await temp.delete(recursive: true);
      }
      if (mounted) {
        setState(() {
          _exporting = false;
          _posters = {};
          _progress = null;
        });
      }
    }
  }
}
