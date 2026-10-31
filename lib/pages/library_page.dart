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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text(
        'Mockareel',
        style: TextStyle(fontWeight: FontWeight.w700),
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!),
                TextButton(onPressed: _load, child: const Text('Retry')),
              ],
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
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Your projects',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -.8,
                              ),
                            ),
                            SizedBox(height: 7),
                            Text(
                              'Pick up where inspiration left off.',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${_projects.length} reels',
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
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
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            color: mint.withValues(alpha: .1),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Icon(
                            Icons.video_library_outlined,
                            size: 34,
                            color: mint,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Your next reel starts here',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 9),
                        const Text(
                          'Choose a familiar interface.\nMake the story your own.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white54, height: 1.6),
                        ),
                        const SizedBox(height: 22),
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
                        mainAxisSpacing: 20,
                        childAspectRatio: .66,
                      ),
                      delegate: SliverChildBuilderDelegate((context, i) {
                        final p = _projects[i];
                        return _ProjectTile(project: p, onTap: () => _open(p));
                      }, childCount: _projects.length),
                    ),
                  ),
                ),
            ],
          ),
  );
}

class _ProjectTile extends StatelessWidget {
  final ReelProject project;
  final VoidCallback onTap;
  const _ProjectTile({required this.project, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final p = project;
    return Semantics(
      button: true,
      label: 'Open ${p.title}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ColoredBox(
                  color: panel,
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
            const SizedBox(height: 9),
            Text(
              p.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              '${p.isFeed ? 'FYP SCROLL' : 'MAPS STORY'} · ${p.clips.length} clips',
              style: const TextStyle(
                fontSize: 9,
                color: Colors.white54,
                letterSpacing: .4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TemplatePickerPage extends StatelessWidget {
  const TemplatePickerPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Choose a template')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Familiar screens.\nYour stories.',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Start with a format, then make every detail yours.',
          style: TextStyle(color: Colors.white54),
        ),
        const SizedBox(height: 26),
        LayoutBuilder(
          builder: (context, c) => GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: c.maxWidth >= 650 ? 3 : 2,
            crossAxisSpacing: 14,
            mainAxisSpacing: 16,
            childAspectRatio: .52,
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
                const Color(0xffb2d7cb),
              ),
            ],
          ),
        ),
      ],
    ),
  );
  Widget _template(
    BuildContext context,
    String id,
    String title,
    String subtitle,
    IconData icon,
    Color accent,
  ) {
    final feed = id == 'tiktok-feed';
    return InkWell(
      onTap: () => Navigator.pop(context, id),
      borderRadius: BorderRadius.circular(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: panel,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              padding: const EdgeInsets.all(9),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
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
                          top: 18,
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
                            child: Icon(icon, size: 45, color: accent),
                          ),
                        ),
                        const Positioned(
                          bottom: 42,
                          left: 10,
                          child: Text(
                            '@yourstory\nYour moment. Your feed.',
                            style: TextStyle(fontSize: 10, height: 1.6),
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
                      ] else ...[
                        Positioned(
                          top: 25,
                          left: 25,
                          child: Icon(
                            Icons.location_on,
                            color: accent,
                            size: 38,
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: 150,
                          child: Container(
                            padding: const EdgeInsets.all(12),
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
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Text(
                                  '4.9 / 5',
                                  style: TextStyle(
                                    fontSize: 8,
                                    color: Colors.black54,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Expanded(
                                  child: Row(
                                    children: [
                                      Expanded(child: Container(color: accent)),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Container(
                                          color: const Color(0xffd0b69b),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'A place worth sharing',
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
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.white54,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
