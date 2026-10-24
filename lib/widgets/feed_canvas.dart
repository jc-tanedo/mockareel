import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import '../model/project.dart';
import '../model/feed.dart';
import 'media_frame.dart';
import 'home_surface.dart';
export 'home_surface.dart';

const _pink = Color(0xfffe2c55), _cyan = Color(0xff25f4ee);

class FeedCanvas extends StatelessWidget {
  final ReelProject project;
  final double position;
  final bool playing, overlayOnly, posterOnly;
  final Map<String, String> posters;
  const FeedCanvas({
    super.key,
    required this.project,
    this.position = 0,
    this.playing = false,
    this.overlayOnly = false,
    this.posterOnly = false,
    this.posters = const {},
  });
  Widget _media(ReelClip c, double elapsed, {bool still = false}) =>
      still || posterOnly
      ? ClipPoster(
          clip: c,
          position: elapsed,
          resolvedPath:
              posters['${c.id}:${elapsed >= c.duration ? 'end' : 'start'}'],
        )
      : MediaFrame(
          key: ValueKey(c.id),
          clip: c,
          position: elapsed.clamp(0, c.duration),
          playing: playing,
        );
  @override
  Widget build(BuildContext context) {
    final s = FeedTimeline.at(project, position), f = project.feed;
    final elapsed = (position - s.start).clamp(0.0, s.duration);
    final children = <Widget>[];
    if (s.kind == 'search') {
      children.add(
        Positioned.fill(
          child: SearchSurface(settings: f, elapsed: elapsed),
        ),
      );
    } else if (s.kind == 'post') {
      final i = s.postIndex;
      final entry = project.clips.isEmpty
          ? 0.0
          : FeedTimeline.entry(project, i, elapsed);
      if (!overlayOnly) {
        children.add(
          const Positioned.fill(child: ColoredBox(color: Colors.black)),
        );
      }
      if (i > 0 && entry > 0) {
        final prev = project.clips[i - 1];
        children.add(
          Positioned(
            left: 0,
            top: entry - 640,
            width: 360,
            height: 640,
            child: Stack(
              children: [
                Positioned.fill(
                  child: _media(prev, prev.duration, still: true),
                ),
                Positioned.fill(child: FeedPostSurface(post: prev.post)),
              ],
            ),
          ),
        );
      }
      if (project.clips.isNotEmpty) {
        final c = project.clips[i];
        children.add(
          Positioned(
            left: 0,
            top: entry,
            width: 360,
            height: 640,
            child: Stack(
              children: [
                if (!overlayOnly) Positioned.fill(child: _media(c, elapsed)),
                Positioned.fill(child: FeedPostSurface(post: c.post)),
              ],
            ),
          ),
        );
      } else {
        children.add(
          const Center(
            child: Icon(
              Icons.add_photo_alternate_outlined,
              color: Colors.white54,
              size: 48,
            ),
          ),
        );
      }
      children.add(
        Positioned.fill(
          child: FeedChrome(time: f.time, search: f.hasSearch ? f.search : ''),
        ),
      );
    } else {
      final home = f.homeMedia;
      if (!overlayOnly && home != null) {
        children.add(
          Positioned.fill(child: _media(home, elapsed % home.duration)),
        );
      }
      children.add(
        Positioned.fill(
          child: HomeSurface(settings: f, transparentBackground: home != null),
        ),
      );
      final opening = s.kind == 'home-open';
      final t = opening
          ? ((elapsed - f.homeSeconds) / .6).clamp(0.0, 1.0)
          : (elapsed / .65).clamp(0.0, 1.0);
      final amount = opening ? pow(t, .7).toDouble() : pow(1 - t, 3).toDouble();
      if (amount > 0 && project.clips.isNotEmpty) {
        final c = project.clips[opening ? 0 : project.clips.length - 1];
        // Match the fourth app tile on the home screen.
        children.add(
          Positioned(
            left: 275 * (1 - amount),
            top: f.homeOs.iconTop * (1 - amount),
            width: 50 + 310 * amount,
            height: 50 + 590 * amount,
            child: Opacity(
              opacity: amount.clamp(0, 1),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(
                  f.homeOs.iconRadius * (1 - amount),
                ),
                child: FittedBox(
                  fit: BoxFit.fill,
                  child: SizedBox(
                    width: 360,
                    height: 640,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: _media(
                            c,
                            opening ? 0 : c.duration,
                            still: true,
                          ),
                        ),
                        Positioned.fill(child: FeedPostSurface(post: c.post)),
                        Positioned.fill(child: FeedChrome(time: f.time)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }
    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: 360,
        height: 640,
        child: ClipRect(
          child: DefaultTextStyle(
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Roboto',
              fontSize: 13,
              decoration: TextDecoration.none,
            ),
            child: IconTheme(
              data: const IconThemeData(color: Colors.white),
              child: Stack(children: children),
            ),
          ),
        ),
      ),
    );
  }
}

class PhoneStatus extends StatelessWidget {
  final String time;
  final Color color;
  const PhoneStatus({super.key, required this.time, this.color = Colors.white});
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 32,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Row(
        children: [
          Text(
            time,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Icon(Icons.signal_cellular_alt, size: 14, color: color),
          const SizedBox(width: 5),
          Icon(Icons.wifi, size: 14, color: color),
          const SizedBox(width: 5),
          Icon(Icons.battery_full, size: 18, color: color),
        ],
      ),
    ),
  );
}

class FeedChrome extends StatelessWidget {
  final String time, search;
  const FeedChrome({super.key, required this.time, this.search = ''});
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned(
        left: 0,
        right: 0,
        top: 0,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black54, Colors.transparent],
            ),
          ),
          child: Column(
            children: [
              PhoneStatus(time: time),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Icon(Icons.live_tv_outlined, size: 22),
                    const Text(
                      'Following',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Column(
                      children: [
                        const Text(
                          'For You',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Container(width: 25, height: 3, color: Colors.white),
                      ],
                    ),
                    const Icon(Icons.search, size: 25),
                  ],
                ),
              ),
              if (search.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Row(
                    children: [
                      const Icon(Icons.search, size: 13),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          search,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                      const Icon(Icons.chevron_right, size: 15),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        height: 57,
        child: ColoredBox(
          color: Colors.black,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(17, 6, 17, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _nav(Icons.home_filled, 'Home'),
                    _nav(Icons.people_outline, 'Friends'),
                    SizedBox(
                      width: 43,
                      height: 29,
                      child: Stack(
                        children: [
                          Positioned(
                            left: 0,
                            right: 4,
                            top: 1,
                            bottom: 1,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: _cyan,
                                borderRadius: BorderRadius.circular(7),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 4,
                            right: 0,
                            top: 1,
                            bottom: 1,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: _pink,
                                borderRadius: BorderRadius.circular(7),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 4,
                            right: 4,
                            top: 1,
                            bottom: 1,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: const Icon(
                                Icons.add,
                                color: Colors.black,
                                size: 25,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _nav(Icons.chat_bubble_outline, 'Inbox'),
                    _nav(Icons.person_outline, 'Profile'),
                  ],
                ),
              ),
              Container(
                width: 110,
                height: 3,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
  Widget _nav(IconData icon, String label) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 22),
      Text(
        label,
        style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w600),
      ),
    ],
  );
}

class FeedPostSurface extends StatelessWidget {
  final FeedPost post;
  const FeedPostSurface({super.key, required this.post});
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      const Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.center,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black87],
            ),
          ),
        ),
      ),
      Positioned(
        left: 13,
        right: 70,
        bottom: 72,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    '@${post.username.replaceFirst(RegExp(r'^@'), '')}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (post.verified)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(Icons.verified, color: _cyan, size: 14),
                  ),
              ],
            ),
            if (post.title.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 7),
                child: Text(
                  post.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 19,
                    height: 1.15,
                  ),
                ),
              ),
            const SizedBox(height: 6),
            Text(
              post.caption,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, height: 1.35),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.music_note, size: 14),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    '${post.sound} · ${post.username}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      Positioned(
        right: 9,
        bottom: 76,
        width: 48,
        child: Column(
          children: [
            SizedBox(
              height: 60,
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: ClipOval(
                      child: post.avatarPath == null
                          ? const ColoredBox(
                              color: Color(0xff554b73),
                              child: Icon(Icons.person, size: 30),
                            )
                          : Image.file(
                              File(post.avatarPath!),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.person),
                            ),
                    ),
                  ),
                  if (!post.following)
                    Positioned(
                      bottom: 6,
                      child: Container(
                        width: 19,
                        height: 19,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: _pink,
                        ),
                        child: const Icon(Icons.add, size: 16),
                      ),
                    ),
                ],
              ),
            ),
            _action(Icons.favorite, post.likes),
            _action(Icons.chat_bubble_rounded, post.comments),
            _action(Icons.bookmark, post.saves),
            _action(Icons.reply, post.shares),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [Color(0xff777777), Colors.black, Color(0xff444444)],
                ),
                border: Border.all(color: Colors.white24, width: 5),
              ),
              child: const Icon(Icons.music_note, size: 15),
            ),
          ],
        ),
      ),
    ],
  );
  Widget _action(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 15),
    child: Column(
      children: [
        Icon(
          icon,
          size: 31,
          shadows: const [Shadow(color: Colors.black38, blurRadius: 4)],
        ),
        const SizedBox(height: 2),
        Text(
          text,
          maxLines: 1,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class SearchSurface extends StatelessWidget {
  final FeedSettings settings;
  final double elapsed;
  const SearchSurface({
    super.key,
    required this.settings,
    required this.elapsed,
  });
  @override
  Widget build(BuildContext context) {
    final chars = settings.search.characters;
    final count =
        (chars.length * (elapsed / settings.typingSeconds).clamp(0, 1)).floor();
    final loading = elapsed >= settings.typingSeconds;
    return ColoredBox(
      color: Colors.white,
      child: DefaultTextStyle(
        style: const TextStyle(
          color: Color(0xff161823),
          fontSize: 13,
          fontFamily: 'Roboto',
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PhoneStatus(time: settings.time, color: Colors.black),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
              child: Row(
                children: [
                  const Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.black,
                    size: 20,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xfff1f1f2),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.search,
                            color: Colors.black54,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${chars.take(count)}${loading ? '' : '|'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (count > 0)
                            const Icon(
                              Icons.cancel,
                              color: Colors.black38,
                              size: 14,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Search',
                    style: TextStyle(color: _pink, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            if (loading) ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 22),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Top',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text('Users', style: TextStyle(fontSize: 12)),
                    ),
                    Expanded(
                      child: Text('Videos', style: TextStyle(fontSize: 12)),
                    ),
                    Expanded(
                      child: Text('Photos', style: TextStyle(fontSize: 12)),
                    ),
                    Expanded(
                      child: Text('Sounds', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
              const Divider(color: Color(0xffeeeeee)),
              Expanded(
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Transform.translate(
                        offset: Offset(5 * sin(elapsed * 10), 0),
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: _cyan,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Transform.translate(
                        offset: Offset(-5 * sin(elapsed * 10), 0),
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: _pink,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'You may like',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
              for (final text in [
                settings.search,
                'Find your next favorite',
                'Little moments, big memories',
              ])
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: Colors.black45, size: 16),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(
                        Icons.north_west,
                        color: Colors.black38,
                        size: 15,
                      ),
                    ],
                  ),
                ),
              const Spacer(),
              Container(
                height: 210,
                color: const Color(0xffd1d3d9),
                padding: const EdgeInsets.all(7),
                child: Column(
                  children: [
                    for (final row in ['QWERTYUIOP', 'ASDFGHJKL', 'ZXCVBNM'])
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (final letter in row.split(''))
                              Expanded(
                                child: Container(
                                  margin: const EdgeInsets.all(2),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    letter,
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 5),
                    Container(
                      height: 35,
                      width: 175,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Text('space'),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
