import '../services/media_importer.dart';
import '../services/export_background_session.dart';
import '../services/feed_export_pipeline.dart';
import '../widgets/feed_export_panel.dart';
import '../widgets/feed_posts_editor.dart';
import '../widgets/feed_sequence_editor.dart';
import '../widgets/project_name_dialog.dart';
import '../widgets/editor_app_bar.dart';
import '../widgets/editor_export_overlay.dart';
import '../widgets/export_monitor.dart';
import '../widgets/offscreen_capture_stage.dart';
import '../model/feed_timeline.dart';
import '../pages/exported_video_page.dart';
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
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
  final _backgroundExport = ExportBackgroundSession();
  int _tab = 0, _selected = 0, _postTool = 0, _revision = 0;
  bool _busy = false, _exporting = false, _dirty = false, _cancelled = false;
  String _status = '';
  double? _progress;
  Timer? _autosave;
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
    final title = await ProjectNameDialog.show(context, p.title);
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
    try {
      final result = await MediaImporter.pickMultipleClips(
        store: widget.store,
        renderer: _renderer,
        defaultDuration: 5,
        cardWidth: 1,
      );
      if (!mounted) return;
      if (result.clips.isNotEmpty) {
        p.clips.addAll(result.clips);
        _selected = p.clips.length - 1;
        _change();
      }
      if (result.failures > 0) {
        _toast(
          '${result.failures} files could not be opened. Try JPG/PNG or MP4.',
        );
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
    if (_busy || p.clips.isEmpty) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final index = _selected;
    final clip = p.clips.removeAt(index);
    _selected = max(0, min(index, p.clips.length - 1));
    _change();
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text('Removed “${clip.name}”'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            if (!mounted || p.clips.contains(clip)) return;
            _selected = min(index, p.clips.length);
            p.clips.insert(_selected, clip);
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
    if (_exporting) _renderer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    return PopScope(
      canPop: !_exporting,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && _dirty) unawaited(_save());
      },
      child: Stack(
        children: [
          OffscreenCaptureStage(
            captureKey: _captureKey,
            child: FeedCanvas(
              project: p,
              position: _captureTime,
              overlayOnly: _overlayOnly,
              posterOnly: true,
              posters: _posters,
            ),
          ),
          Scaffold(
            appBar: EditorAppBar(
              title: p.title,
              formatLabel: 'TIKTOK FYP SCROLL · 9:16',
              dirty: _dirty,
              exporting: _exporting,
              onBack: _back,
              onRename: _rename,
              onSave: () async {
                if (await _save()) _toast('Project saved on this device');
              },
              onMenuSelected: (s) {
                if (s == 'rename') _rename();
                if (s == 'backup') _backup();
              },
              menuItems: EditorAppBar.standardMenuItems(),
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
            EditorExportOverlay(
              title: p.title,
              status: _status,
              phase: _exportPhase,
              progress: _progress,
              position: _exportPosition,
              duration: FeedTimeline.duration(p),
              preview: FeedCanvas(
                project: p,
                position: _exportPosition,
                posterOnly: true,
                posters: _posters,
              ),
              cancelled: _cancelled,
              onCancel: () {
                setState(() {
                  _cancelled = true;
                  _status = 'Cancelling export…';
                });
                _renderer.cancel();
              },
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
    final bytes = await OffscreenCaptureStage.capturePng(
      _captureKey,
      pixelRatio: 3,
      settleFrames: 2,
    );
    final file = File('${dir.path}/$name.png');
    await file.writeAsBytes(bytes);
    return file.path;
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
    try {
      final notifications = await _backgroundExport.start(p.title);
      if (notifications == false) {
        _toast(
          'Enable notifications in Android settings to see export progress.',
        );
      }
      if (!await _save()) return;
      final pipeline = FeedExportPipeline(
        project: p,
        store: widget.store,
        renderer: _renderer,
        onPrecache: _precache,
        onCapture: _capture,
        onStatus: (s) {
          if (mounted) {
            setState(() => _status = s);
            unawaited(_backgroundExport.update(_status, _progress));
          }
        },
        onProgress: (v) {
          if (mounted) {
            setState(() => _progress = v);
            unawaited(_backgroundExport.update(_status, _progress));
          }
        },
        onPhase: (phase) {
          if (mounted) setState(() => _exportPhase = phase);
        },
        onPosition: (pos) {
          if (mounted) setState(() => _exportPosition = pos);
        },
        onPosters: (posters) {
          if (mounted) setState(() => _posters = posters);
        },
        isCancelled: () => _cancelled || !mounted,
      );
      final path = await pipeline.run();
      if (!mounted || _cancelled) return;
      await _backgroundExport.finish(complete: true);
      if (!mounted) return;
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
      await _backgroundExport.finish(complete: false);
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
