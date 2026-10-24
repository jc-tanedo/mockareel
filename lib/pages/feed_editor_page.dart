import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../main.dart' show ExportedVideoPage, mint;
import '../model/project.dart';
import '../model/feed.dart';
import '../services/native_renderer.dart';
import '../services/project_store.dart';
import '../widgets/audio_editor.dart';
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
  double _captureTime = 0;
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
    final controller = TextEditingController(text: p.title);
    final title = await showDialog<String>(
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
    // Dialog animations can still hold the controller for a frame.
    if (title != null && title.isNotEmpty && mounted) {
      p.title = title;
      _change();
    }
  }

  Future<void> _backup() async {
    try {
      await _save();
      final path = await widget.store.backup(p);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(path)],
          subject: '${p.title} — Mockareel project',
        ),
      );
    } catch (_) {
      _toast('Could not share the project backup.');
    }
  }

  bool _isVideo(XFile file) =>
      file.mimeType?.startsWith('video/') == true ||
      RegExp(
        r'\.(mp4|mov|m4v|webm|mkv|3gp)$',
        caseSensitive: false,
      ).hasMatch(file.name);
  Future<ReelClip> _retain(XFile file) async {
    final video = _isVideo(file);
    final info = video
        ? await _renderer.inspect(file.path)
        : <String, dynamic>{};
    final duration = (info['duration'] as num?)?.toDouble() ?? 0;
    if (video && duration <= 0) {
      throw const FormatException('Video duration unavailable');
    }
    return ReelClip(
      id: newId(),
      path: await widget.store.retainMedia(file.path, file.name),
      name: file.name,
      isVideo: video,
      sourceDuration: duration,
      duration: video ? min(5, duration) : 5,
      cardWidth: 1,
    );
  }

  Future<void> _pickMedia() async {
    setState(() => _busy = true);
    var failures = 0;
    try {
      final files = await ImagePicker().pickMultipleMedia();
      for (final file in files) {
        try {
          final clip = await _retain(file);
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
      final c = await _retain(file);
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
      final file = await FilePicker.pickFile(type: FileType.audio);
      if (file?.path == null) return;
      final info = await _renderer.inspect(file!.path!);
      final duration = (info['duration'] as num?)?.toDouble() ?? 0;
      if (info['hasAudio'] != true || duration <= 0) {
        throw const FormatException();
      }
      final path = await widget.store.retainMedia(file.path!, file.name);
      if (mounted) {
        p.music = MusicTrack(
          path: path,
          name: file.name,
          sourceDuration: duration,
        );
        _change();
      }
    } catch (_) {
      _toast('Choose an audio file your device can play.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autosave?.cancel();
    _subscription?.cancel();
    if (_exporting) _renderer.cancel();
    super.dispose();
  }

  Widget _field(
    String label,
    String value,
    ValueChanged<String> change, {
    int lines = 1,
    int max = 180,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      key: ValueKey('$label-$_selected-${p.id}'),
      initialValue: value,
      maxLength: max,
      maxLines: lines,
      decoration: InputDecoration(labelText: label, counterText: ''),
      onChanged: (v) {
        change(v);
        _change();
      },
    ),
  );
  Widget _slider(
    String label,
    double value,
    double lo,
    double hi,
    ValueChanged<double> change,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '$label · ${value.toStringAsFixed(1)}${label == 'Zoom' ? '×' : 's'}',
        style: const TextStyle(fontSize: 12),
      ),
      Slider(
        value: value.clamp(lo, hi),
        min: lo,
        max: max(lo + .001, hi),
        onChanged: (v) {
          change(v);
          _change();
        },
      ),
    ],
  );
  Widget _tools(List<String> labels, int selected, ValueChanged<int> tap) =>
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            for (var i = 0; i < labels.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(labels[i]),
                  selected: selected == i,
                  onSelected: (_) => tap(i),
                ),
              ),
          ],
        ),
      );
  Widget _sequence() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      const Text(
        'OPENING',
        style: TextStyle(
          fontSize: 10,
          color: Colors.white54,
          letterSpacing: 1.5,
        ),
      ),
      const SizedBox(height: 12),
      SegmentedButton<String>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: 'search', label: Text('Search')),
          ButtonSegment(value: 'home', label: Text('Home screen')),
          ButtonSegment(value: 'feed', label: Text('Feed')),
        ],
        selected: {p.feed.opening},
        onSelectionChanged: (s) {
          p.feed.opening = s.first;
          _change();
        },
      ),
      const SizedBox(height: 18),
      if (p.feed.opening == 'search') ...[
        _field(
          'Search query',
          p.feed.search,
          (v) => p.feed.search = v,
          max: 100,
        ),
        const Text(
          'Leave empty to start directly in the feed.',
          style: TextStyle(fontSize: 11, color: Colors.white54),
        ),
        const SizedBox(height: 16),
        _slider(
          'Typing',
          p.feed.typingSeconds,
          .5,
          6,
          (v) => p.feed.typingSeconds = v,
        ),
        _slider(
          'Loading',
          p.feed.loadingSeconds,
          .2,
          3,
          (v) => p.feed.loadingSeconds = v,
        ),
      ],
      if (p.feed.opening == 'home')
        const Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: Text(
            'The home screen holds, then the app opens into your first post.',
            style: TextStyle(fontSize: 12, color: Colors.white60),
          ),
        ),
      _slider(
        'Swipe duration',
        p.slideSeconds,
        .15,
        .8,
        (v) => p.slideSeconds = v,
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Close app to home screen'),
        subtitle: const Text('Shrink the last post back into the app icon.'),
        value: p.feed.closeToHome,
        onChanged: (v) {
          p.feed.closeToHome = v;
          _change();
        },
      ),
      ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: const Text('Home screen & status bar'),
        initiallyExpanded: p.feed.opening == 'home',
        children: [
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Show home status bar'),
            value: p.feed.showStatus,
            onChanged: (v) {
              p.feed.showStatus = v;
              _change();
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Show home widget'),
            value: p.feed.showWidget,
            onChanged: (v) {
              p.feed.showWidget = v;
              _change();
            },
          ),
          _field(
            'Status bar time',
            p.feed.time,
            (v) => p.feed.time = v,
            max: 8,
          ),
          _field('Date', p.feed.date, (v) => p.feed.date = v, max: 50),
          _field(
            'Widget title',
            p.feed.widgetTitle,
            (v) => p.feed.widgetTitle = v,
            max: 70,
          ),
          _field(
            'Widget note',
            p.feed.widgetText,
            (v) => p.feed.widgetText = v,
            max: 80,
          ),
          _slider(
            'Home screen hold',
            p.feed.homeSeconds,
            .5,
            6,
            (v) => p.feed.homeSeconds = v,
          ),
          OutlinedButton.icon(
            onPressed: _busy ? null : _pickHome,
            icon: const Icon(Icons.wallpaper),
            label: Text(
              p.feed.homeMedia == null
                  ? 'Choose home photo / video'
                  : 'Replace home photo / video',
            ),
          ),
          if (p.feed.homeMedia != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                p.feed.homeMedia!.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                p.feed.homeMedia!.isVideo
                    ? 'Video wallpaper · loops to fit'
                    : 'Photo wallpaper',
              ),
              trailing: IconButton(
                tooltip: 'Remove home media',
                onPressed: () {
                  p.feed.homeMedia = null;
                  _change();
                },
                icon: const Icon(Icons.close),
              ),
            ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('App labels'),
            subtitle: const Text(
              'Eight generic tiles; the fourth opens the feed.',
            ),
            children: [
              for (var i = 0; i < 8; i++)
                _field(
                  'App ${i + 1}',
                  i < p.feed.appLabels.length ? p.feed.appLabels[i] : 'App',
                  (v) {
                    while (p.feed.appLabels.length < 8) {
                      p.feed.appLabels.add('App');
                    }
                    p.feed.appLabels[i] = v;
                  },
                  max: 16,
                ),
              for (var i = 0; i < 8; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DropdownButtonFormField<int>(
                    key: ValueKey('app-icon-$i'),
                    initialValue: i < p.feed.appIcons.length
                        ? p.feed.appIcons[i]
                        : i,
                    decoration: InputDecoration(labelText: 'App ${i + 1} icon'),
                    items: [
                      for (var n = 0; n < 12; n++)
                        DropdownMenuItem(
                          value: n,
                          child: Text(
                            const [
                              'Photos',
                              'Camera',
                              'Notes',
                              'Music note',
                              'Weather',
                              'Sound',
                              'Messages',
                              'Settings',
                              'Map',
                              'Mail',
                              'Clock',
                              'Video',
                            ][n],
                          ),
                        ),
                    ],
                    onChanged: (n) {
                      if (n == null) return;
                      while (p.feed.appIcons.length < 8) {
                        p.feed.appIcons.add(p.feed.appIcons.length);
                      }
                      p.feed.appIcons[i] = n;
                      _change();
                    },
                  ),
                ),
            ],
          ),
        ],
      ),
    ],
  );
  void _move(int delta) {
    final next = _selected + delta;
    if (next < 0 || next >= p.clips.length) return;
    final c = p.clips.removeAt(_selected);
    p.clips.insert(next, c);
    _selected = next;
    _change();
  }

  Widget _posts() => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${p.clips.length} posts',
                style: const TextStyle(fontSize: 12, color: Colors.white60),
              ),
            ),
            TextButton.icon(
              onPressed: _busy ? null : _pickMedia,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add media'),
            ),
          ],
        ),
      ),
      if (p.clips.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DropdownButtonFormField<int>(
            key: ValueKey('select-$_selected-${p.clips.length}'),
            initialValue: _selected,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Selected post',
              isDense: true,
            ),
            items: [
              for (var i = 0; i < p.clips.length; i++)
                DropdownMenuItem(
                  value: i,
                  child: Text(
                    '${i + 1}. ${p.clips[i].name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (i) {
              if (i != null) setState(() => _selected = i);
            },
          ),
        ),
        _tools(
          ['Identity', 'Caption', 'Stats', 'Timing & frame'],
          _postTool,
          (i) => setState(() => _postTool = i),
        ),
        Expanded(
          child: ListView(
            key: ValueKey('post-$_selected-tool-$_postTool'),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            children: _postFields(p.clips[_selected]),
          ),
        ),
      ] else
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.swipe_up_outlined, size: 35, color: mint),
                  const SizedBox(height: 12),
                  const Text(
                    'One post per photo or video',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Add your media, then edit the poster, caption and counts for each post.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _busy ? null : _pickMedia,
                    icon: const Icon(Icons.add),
                    label: const Text('Add photos & videos'),
                  ),
                ],
              ),
            ),
          ),
        ),
    ],
  );
  List<Widget> _postFields(ReelClip c) {
    final post = c.post;
    return switch (_postTool) {
      0 => [
        _field('Username', post.username, (v) => post.username = v, max: 40),
        Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundImage: post.avatarPath != null
                  ? FileImage(File(post.avatarPath!))
                  : null,
              child: post.avatarPath == null ? const Icon(Icons.person) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: _busy ? null : () => _pickAvatar(c),
                child: const Text('Choose profile photo'),
              ),
            ),
            if (post.avatarPath != null)
              IconButton(
                tooltip: 'Remove profile photo',
                onPressed: () {
                  post.avatarPath = null;
                  _change();
                },
                icon: const Icon(Icons.close),
              ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Verified badge'),
          value: post.verified,
          onChanged: (v) {
            post.verified = v;
            _change();
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Already following'),
          subtitle: const Text('Hide the follow plus on the profile photo.'),
          value: post.following,
          onChanged: (v) {
            post.following = v;
            _change();
          },
        ),
      ],
      1 => [
        _field(
          'Post title',
          post.title,
          (v) => post.title = v,
          lines: 2,
          max: 100,
        ),
        _field(
          'Caption & hashtags',
          post.caption,
          (v) => post.caption = v,
          lines: 4,
          max: 400,
        ),
        _field('Sound label', post.sound, (v) => post.sound = v, max: 80),
        const Text(
          'The sound label is decorative. Choose actual background music in Audio.',
          style: TextStyle(fontSize: 11, color: Colors.white54),
        ),
      ],
      2 => [
        _field('Likes', post.likes, (v) => post.likes = v, max: 12),
        _field('Comments', post.comments, (v) => post.comments = v, max: 12),
        _field('Saves', post.saves, (v) => post.saves = v, max: 12),
        _field('Shares', post.shares, (v) => post.shares = v, max: 12),
      ],
      _ => [
        _slider(
          'Post duration',
          c.duration,
          min(.5, c.maxDuration),
          c.maxDuration,
          (v) {
            c.duration = v;
            c.normalize();
          },
        ),
        if (c.isVideo && c.sourceDuration > c.duration)
          _slider(
            'Trim start',
            c.trimStart,
            0,
            max(.001, c.sourceDuration - c.duration),
            (v) {
              c.trimStart = v;
              c.normalize();
            },
          ),
        _slider('Zoom', c.zoom, 1, 3, (v) => c.zoom = v),
        const Text('Horizontal crop', style: TextStyle(fontSize: 12)),
        Slider(
          value: c.panX,
          min: -1,
          max: 1,
          onChanged: (v) {
            c.panX = v;
            _change();
          },
        ),
        Row(
          children: [
            IconButton(
              tooltip: 'Move post earlier',
              onPressed: _selected > 0 ? () => _move(-1) : null,
              icon: const Icon(Icons.arrow_upward),
            ),
            IconButton(
              tooltip: 'Move post later',
              onPressed: _selected < p.clips.length - 1 ? () => _move(1) : null,
              icon: const Icon(Icons.arrow_downward),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () {
                p.clips.removeAt(_selected);
                _selected = max(0, min(_selected, p.clips.length - 1));
                _change();
              },
              icon: const Icon(Icons.delete_outline),
              label: const Text('Remove post'),
            ),
          ],
        ),
      ],
    };
  }

  Widget _exportPanel() => Column(
    children: [
      Expanded(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'READY FOR YOUR CLOSE-UP',
              style: TextStyle(fontSize: 10, color: mint, letterSpacing: 1.2),
            ),
            const SizedBox(height: 14),
            Text(
              '${p.clips.length} posts · ${FeedTimeline.duration(p).toStringAsFixed(1)} seconds',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              '1080 × 1920 · 30 fps · MP4',
              style: TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 16),
            Text(
              '${p.feed.hasSearch
                  ? 'Typed search → '
                  : p.feed.opening == 'home'
                  ? 'Home screen → '
                  : ''}Vertical feed${p.feed.closeToHome ? ' → Home screen' : ''}',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 16),
            if (p.clips.isEmpty)
              const Text(
                'Add at least one photo or video in Posts.',
                style: TextStyle(color: mint),
              ),
            const Text(
              'Background music is optional. Source video audio is muted.',
              style: TextStyle(fontSize: 11, color: Colors.white54),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _backup,
              icon: const Icon(Icons.inventory_2_outlined),
              label: const Text('Share project backup'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Changes save automatically on this device.',
              style: TextStyle(fontSize: 11, color: Colors.white38),
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: p.clips.isEmpty || _busy ? null : _export,
            icon: const Icon(Icons.movie_creation_outlined),
            label: const Text('Render MP4'),
          ),
        ),
      ),
    ],
  );

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
                onTap: _rename,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Text(
                      'TIKTOK FYP SCROLL · 9:16',
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
                  onPressed: () async {
                    if (await _save()) _toast('Project saved on this device');
                  },
                  icon: Icon(
                    _dirty ? Icons.save_outlined : Icons.check_circle_outline,
                    color: mint,
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'More project options',
                  onSelected: (s) {
                    if (s == 'rename') _rename();
                    if (s == 'backup') _backup();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'rename',
                      child: Text('Rename project'),
                    ),
                    PopupMenuItem(
                      value: 'backup',
                      child: Text('Share project backup'),
                    ),
                  ],
                ),
              ],
            ),
            body: Column(
              children: [
                if (!keyboard)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 12, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'STEP ${_tab + 1} OF 4',
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: mint,
                                  letterSpacing: 1.3,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                _titles[_tab],
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_tab < 3)
                          TextButton.icon(
                            onPressed: () => setState(() => _tab++),
                            icon: const Icon(Icons.arrow_forward, size: 17),
                            label: const Text('Next'),
                          ),
                      ],
                    ),
                  ),
                Expanded(
                  child: EditorWorkspace(
                    keyboardVisible: keyboard,
                    previewFraction: .5,
                    hint:
                        'LIVE PREVIEW · ${_tab == 1 ? 'POST ${_selected + 1}' : 'FULL SEQUENCE'}',
                    previewBuilder: (height) => TimelinePreview(
                      key: ValueKey('${p.id}-${_tab == 1 ? _selected : -1}'),
                      project: p,
                      selected: _tab == 1 ? _selected : 0,
                      startAtBeginning: _tab != 1,
                      maxHeight: height,
                    ),
                    inspector: switch (_tab) {
                      0 => _sequence(),
                      1 => _posts(),
                      2 => AudioEditor(
                        project: p,
                        importing: _busy,
                        onPick: _pickMusic,
                        onChanged: _change,
                      ),
                      _ => _exportPanel(),
                    },
                  ),
                ),
              ],
            ),
            bottomNavigationBar: keyboard
                ? null
                : Material(
                    color: const Color(0xff202023),
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'CREATE YOUR REEL · TAP ANY STEP',
                              style: TextStyle(
                                fontSize: 8,
                                color: Colors.white38,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 9),
                            Row(
                              children: [
                                for (var i = 0; i < 4; i++)
                                  Expanded(
                                    child: Semantics(
                                      button: true,
                                      selected: _tab == i,
                                      label:
                                          'Step ${i + 1} of 4, ${_labels[i]}',
                                      child: InkWell(
                                        onTap: () => setState(() => _tab = i),
                                        child: Column(
                                          children: [
                                            Container(
                                              width: 23,
                                              height: 23,
                                              alignment: Alignment.center,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: _tab == i
                                                    ? mint
                                                    : Colors.transparent,
                                                border: Border.all(
                                                  color: _tab == i
                                                      ? mint
                                                      : Colors.white24,
                                                ),
                                              ),
                                              child: Text(
                                                '${i + 1}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: _tab == i
                                                      ? Colors.black
                                                      : Colors.white54,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 5),
                                            Text(
                                              _labels[i],
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: _tab == i
                                                    ? mint
                                                    : Colors.white54,
                                              ),
                                            ),
                                            Text(
                                              i == 2 ? 'Optional' : ' ',
                                              style: const TextStyle(
                                                fontSize: 8,
                                                color: Colors.white30,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
          if (_exporting)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black87,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.movie_creation_outlined,
                          size: 36,
                          color: mint,
                        ),
                        const SizedBox(height: 20),
                        Text(_status, textAlign: TextAlign.center),
                        const SizedBox(height: 20),
                        LinearProgressIndicator(value: _progress),
                        const SizedBox(height: 20),
                        TextButton(
                          onPressed: () {
                            _cancelled = true;
                            _renderer.cancel();
                          },
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

  Future<void> _precache(String path) async {
    if (!mounted) return;
    Object? failure;
    await precacheImage(
      FileImage(File(path)),
      context,
      onError: (error, stack) {
        failure = error;
      },
    );
    if (failure != null) {
      throw const FormatException(
        'An image could not be decoded. Replace missing media.',
      );
    }
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
      _status = 'Preparing scenes…';
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
        if (!await File(c.path).exists()) {
          throw FormatException('“${c.name}” is missing. Replace this media.');
        }
        for (final end in [false, true]) {
          final path = c.isVideo
              ? await _renderer.thumbnail(
                  c.path,
                  c.trimStart + (end ? c.duration - .001 : 0),
                )
              : c.path;
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
        // UI is static after each swipe; capture only the changing interval.
        for (var frame = 0; frame < (animated * 30).ceil(); frame++) {
          sceneFrames.add(
            await _capture(
              temp,
              'scene_${i}_$frame',
              s.start + frame / 30,
              overlay: true,
            ),
          );
          if (mounted) {
            setState(
              () => _progress =
                  (i + frame / max(1, animated * 30)) / scenes.length * .35,
            );
          }
        }
        final overlay = await _capture(
          temp,
          'overlay_$i',
          s.start + min(s.duration - .001, animated + .001),
          overlay: true,
        );
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
          // Split a short video wallpaper into repeats; each copy reuses the same UI scene clock.
          clips.add({
            ...source.toJson(),
            'duration': s.duration,
            'loopSource': !isPost && source.isVideo,
            'loopDuration': source.duration,
          });
        }
      }
      if (_cancelled) throw const FormatException('Export cancelled');
      _subscription = _renderer.progress.listen((value) {
        if (mounted) {
          setState(() {
            _status = 'Rendering MP4 on this device…';
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
      if (!mounted) return;
      setState(() => _exporting = false);
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
