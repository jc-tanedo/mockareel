import 'dart:io';
import 'package:flutter/material.dart';
import '../model/feed.dart';

const _pink = Color(0xfffe2c55), _cyan = Color(0xff25f4ee);

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
