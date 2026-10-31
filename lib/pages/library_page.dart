import '../model/feed_timeline.dart';
import '../pages/maps_editor_page.dart';
import '../theme/app_theme.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../model/project.dart';
import '../services/project_store.dart';
import '../widgets/reel_preview.dart';
import 'feed_editor_page.dart';

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
      darkOutput: template == 'streetview',
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
          ? const Center(child: CircularProgressIndicator())
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
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: colors.primaryContainer.withValues(
                                alpha: .35,
                              ),
                              borderRadius: BorderRadius.circular(26),
                              border: Border.all(
                                color: colors.primary.withValues(alpha: .25),
                              ),
                            ),
                            child: Icon(
                              Icons.video_library_outlined,
                              size: 36,
                              color: colors.primary,
                            ),
                          ),
                          const SizedBox(height: 22),
                          Text(
                            'Your next reel starts here',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Choose a familiar interface.\nMake the story your own.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 24),
                          FilledButton.icon(
                            onPressed: _new,
                            icon: const Icon(Icons.add),
                            label: const Text('Create your first project'),
                          ),
                        ],
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
    final templateLabel = p.isStreetview
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

class TemplatePickerPage extends StatelessWidget {
  const TemplatePickerPage({super.key});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Choose a template')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Familiar screens.\nYour stories.',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -.8,
              color: colors.onSurface,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Start with a format, then make every detail yours.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, c) => GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: c.maxWidth >= 650 ? 3 : 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 16,
              childAspectRatio: .51,
              children: [
                _template(
                  context,
                  'maps-place',
                  'Maps place story',
                  'Pins, places & memories',
                  Icons.map_outlined,
                  const Color(0xffb2d7cb),
                ),
                _template(
                  context,
                  'tiktok-feed',
                  'TikTok FYP scroll',
                  'Search, swipe & tell a story',
                  Icons.swipe_up_outlined,
                  mint,
                ),
                _template(
                  context,
                  'streetview',
                  'Streetview journey',
                  'Maps, moments & movement',
                  Icons.streetview,
                  const Color(0xff8bd3dd),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _template(
    BuildContext context,
    String id,
    String title,
    String subtitle,
    IconData icon,
    Color accent,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final feed = id == 'tiktok-feed';
    final street = id == 'streetview';
    return Card(
      margin: EdgeInsets.zero,
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.55)),
      ),
      child: InkWell(
        onTap: () => Navigator.pop(context, id),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: AspectRatio(
                    aspectRatio: 9 / 16,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: feed
                                    ? [
                                        const Color(0xff5a3e75),
                                        const Color(0xff1e3c55),
                                      ]
                                    : street
                                    ? [
                                        const Color(0xff233a54),
                                        const Color(0xff15222e),
                                      ]
                                    : [
                                        const Color(0xff80b5a9),
                                        const Color(0xff364f54),
                                      ],
                              ),
                            ),
                          ),
                        ),
                        if (feed) ...[
                          const Positioned(
                            top: 16,
                            left: 12,
                            child: Text(
                              'Following   For You',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: Center(
                              child: Icon(icon, size: 44, color: accent),
                            ),
                          ),
                          const Positioned(
                            bottom: 40,
                            left: 10,
                            child: Text(
                              '@yourstory\nYour moment. Your feed.',
                              style: TextStyle(fontSize: 10, height: 1.5),
                            ),
                          ),
                          const Positioned(
                            bottom: 12,
                            left: 10,
                            right: 10,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Icon(Icons.home, size: 14),
                                Icon(Icons.add_box, size: 16),
                                Icon(Icons.person, size: 14),
                              ],
                            ),
                          ),
                        ] else if (street) ...[
                          Positioned(
                            top: 14,
                            left: 10,
                            right: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black45,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.threesixty,
                                    size: 12,
                                    color: Colors.white70,
                                  ),
                                  SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      'Street View',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 9),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: Center(
                              child: Icon(icon, size: 42, color: accent),
                            ),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            height: 64,
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: const BoxDecoration(
                                color: Color(0xff18191c),
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(14),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'Dropped pin',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: accent,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Text(
                                      'Directions',
                                      style: TextStyle(
                                        fontSize: 8,
                                        color: Color(0xff00333c),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ] else ...[
                          Positioned(
                            top: 22,
                            left: 22,
                            child: Icon(
                              Icons.location_on,
                              color: accent,
                              size: 36,
                            ),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            height: 140,
                            child: Container(
                              padding: const EdgeInsets.all(11),
                              decoration: const BoxDecoration(
                                color: Color(0xfff5f6f7),
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(15),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Your favorite place',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Text(
                                    '4.9 ★',
                                    style: TextStyle(
                                      fontSize: 8,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              color: accent,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              color: const Color(0xffd0b69b),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'A place worth sharing',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 8,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: colors.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
