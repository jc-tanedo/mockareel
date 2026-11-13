import '../model/feed_timeline.dart';
import '../pages/maps_editor_page.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../model/project.dart';
import '../services/project_store.dart';
import '../widgets/reel_preview.dart';
import '../widgets/empty_placeholder.dart';
import '../widgets/skeleton_loader.dart';
import 'feed_editor_page.dart';
import 'settings_page.dart';
import 'template_picker_page.dart';
export 'template_picker_page.dart';

class LibraryPage extends StatefulWidget {
  final ProjectStore? store;
  const LibraryPage({super.key, this.store});
  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  late final ProjectStore _store = widget.store ?? ProjectStore();
  List<ReelProject> _projects = [];
  bool _loading = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await _store.initialize();
      // Migrate any legacy draft before reading the library.
      await _store.restore();
      final list = await _store.projects();
      if (mounted) {
        setState(() {
          _projects = list;
          _loading = false;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not open project storage.';
        });
      }
    }
  }

  Future<void> _open(ReelProject project) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => project.isFeed
            ? FeedEditorPage(store: _store, project: project)
            : MapsEditorPage(store: _store, initialProject: project),
      ),
    );
    await _load();
  }

  Future<void> _new() async {
    final template = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const TemplatePickerPage()),
    );
    if (template == null || !mounted) return;
    final p = ReelProject(
      template: template,
      darkOutput: template == 'streetview' || template == 'streetview-3d',
      title: template == 'tiktok-feed' ? 'Untitled feed' : 'Untitled reel',
    );
    await _store.save(p);
    if (mounted) await _open(p);
  }

  Future<void> _import() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['mockareel'],
      );
      if (file?.path == null) return;
      final p = await _store.importBackup(file!.path!);
      if (mounted) await _open(p);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not import this project backup.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.movie_filter_rounded,
                size: 18,
                color: colors.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Mockareel',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
            ),
            icon: const Icon(Icons.settings_outlined),
          ),
          IconButton(
            tooltip: 'Import project backup',
            onPressed: _import,
            icon: const Icon(Icons.file_open_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _new,
        icon: const Icon(Icons.add),
        label: const Text('New project'),
      ),
      body: _loading
          ? const LibrarySkeleton()
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 36,
                          color: colors.error,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 16),
                        FilledButton.tonalIcon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          : CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Your projects',
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -.6,
                                  color: colors.onSurface,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Pick up where inspiration left off.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: colors.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_projects.length} reels',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_projects.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(32, 0, 32, 100),
                      child: EmptyPlaceholder(
                        icon: Icons.video_library_outlined,
                        title: 'Your next reel starts here',
                        description:
                            'Choose a familiar interface.\n'
                            'Make the story your own.',
                        action: FilledButton.icon(
                          onPressed: _new,
                          icon: const Icon(Icons.add),
                          label: const Text('Create your first project'),
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                    sliver: SliverLayoutBuilder(
                      builder: (context, constraints) => SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: constraints.crossAxisExtent >= 700
                              ? 4
                              : 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 16,
                          childAspectRatio: .63,
                        ),
                        delegate: SliverChildBuilderDelegate((context, i) {
                          final p = _projects[i];
                          return _ProjectTile(
                            project: p,
                            onTap: () => _open(p),
                          );
                        }, childCount: _projects.length),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _ProjectTile extends StatelessWidget {
  final ReelProject project;
  final VoidCallback onTap;
  const _ProjectTile({required this.project, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final p = project;
    final templateLabel = p.isStreetview3d
        ? 'STREET VIEW 3D'
        : p.isStreetview
        ? 'STREET VIEW'
        : p.isFeed
        ? 'FYP SCROLL'
        : 'MAPS STORY';
    final templateIcon = p.isStreetview
        ? Icons.streetview
        : p.isFeed
        ? Icons.swipe_up_outlined
        : Icons.map_outlined;
    return Semantics(
      button: true,
      label: 'Open ${p.title}',
      child: Card(
        margin: EdgeInsets.zero,
        color: colors.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: ColoredBox(
                      color: colors.surfaceContainerHighest,
                      child: SizedBox.expand(
                        child: ReelCanvas(
                          project: p,
                          position: p.isFeed
                              ? FeedTimeline.postStart(p, 0)
                              : p.sheetIntroSeconds,
                          posterOnly: true,
                          animateIntro: false,
                          heroPath: p.headerMode == 'map'
                              ? p.mapHeaderPath
                              : p.heroClip?.isVideo == false
                              ? p.heroClip?.path
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    p.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 2),
                  child: Row(
                    children: [
                      Icon(templateIcon, size: 12, color: colors.primary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '$templateLabel · ${p.clips.length} clips',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 10,
                            color: colors.onSurfaceVariant,
                            letterSpacing: .3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
