import 'dart:math';
import 'package:flutter/material.dart';
import '../model/feed.dart';
import 'phone_status.dart';

const _pink = Color(0xfffe2c55), _cyan = Color(0xff25f4ee);

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
