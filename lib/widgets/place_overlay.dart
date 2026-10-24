import 'dart:io';
import 'package:flutter/material.dart';
import '../model/project.dart';
import '../model/template_layout.dart';
import 'media_frame.dart';
import 'story_tags.dart';

/// Only the gallery rectangle is transparent. This surface is shared by the
/// live preview, transparent PNG, and each frame of the native compositor.
class PlaceOverlay extends StatelessWidget {
  final ReelProject project;
  final int index;
  final String? heroPath;
  final bool showTags;
  final double sheetOffset;
  const PlaceOverlay({
    super.key,
    required this.project,
    this.index = 0,
    this.heroPath,
    this.showTags = true,
    this.sheetOffset = 0,
  });
  static const _teal = Color(0xff075d6b),
      _pale = Color(0xffddf0f3),
      _muted = Color(0xff666d72);
  @override
  Widget build(BuildContext context) {
    final p = project.place;
    final caption = index >= 0 && index < project.clips.length
        ? project.clips[index].caption
        : '';
    final hero = project.headerMode == 'map'
        ? project.mapHeaderPath
        : heroPath ??
              (project.heroClip?.isVideo == false
                  ? project.heroClip?.path
                  : null);
    Widget line(
      String text, {
      double size = 10,
      Color color = _muted,
      int lines = 1,
    }) => Text(
      text,
      maxLines: lines,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: size, color: color, height: 1.2),
    );
    return MediaQuery.withNoTextScaling(
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: 360,
          height: 640,
          child: Theme(
            data: ThemeData.light(useMaterial3: true),
            child: DefaultTextStyle(
              style: const TextStyle(
                color: Color(0xff202124),
                fontFamily: 'Roboto',
                decoration: TextDecoration.none,
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    width: 360,
                    height: 94 + sheetOffset,
                    child: ColoredBox(
                      color: const Color(0xff193d43),
                      child: hero == null
                          ? (project.headerMode == 'map'
                                ? const Center(
                                    child: Icon(
                                      Icons.map_outlined,
                                      color: Colors.white38,
                                      size: 34,
                                    ),
                                  )
                                : project.heroClip == null
                                ? const Center(
                                    child: Icon(
                                      Icons.photo_outlined,
                                      color: Colors.white38,
                                      size: 34,
                                    ),
                                  )
                                : ClipPoster(
                                    clip: project.heroClip!,
                                    applyCrop: false,
                                  ))
                          : Image.file(
                              File(hero),
                              fit: BoxFit.cover,
                              alignment: Alignment.bottomCenter,
                              errorBuilder: (_, __, ___) => const SizedBox(),
                            ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 94 + sheetOffset,
                    height: 18,
                    child: ColoredBox(
                      color: project.headerMode == 'map'
                          ? const Color(0xffe8eadf)
                          : const Color(0xff193d43),
                    ),
                  ),
                  Positioned.fill(
                    child: Transform.translate(
                      offset: Offset(0, sheetOffset),
                      child: Stack(
                        children: [
                          Positioned(
                            left: 0,
                            top: 94,
                            right: 0,
                            height: 156,
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(18),
                                ),
                              ),
                            ),
                          ),
                          const Positioned(
                            left: 0,
                            top: 250,
                            width: 16,
                            height: 250,
                            child: ColoredBox(color: Colors.white),
                          ),
                          const Positioned(
                            right: 0,
                            top: 250,
                            width: 16,
                            height: 250,
                            child: ColoredBox(color: Colors.white),
                          ),
                          const Positioned(
                            left: 0,
                            right: 0,
                            top: 500,
                            bottom: 0,
                            child: ColoredBox(color: Colors.white),
                          ),
                          Positioned(
                            left: 18,
                            top: 108,
                            width: 232,
                            child: Text(
                              p.name.isEmpty ? 'Your place name' : p.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 19,
                                height: 1.08,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Positioned(
                            right: 14,
                            top: 110,
                            child: Row(
                              children: [
                                for (final icon in [
                                  Icons.bookmark_border,
                                  Icons.notifications_none,
                                  Icons.ios_share,
                                ])
                                  Container(
                                    margin: const EdgeInsets.only(left: 5),
                                    padding: const EdgeInsets.all(5),
                                    decoration: const BoxDecoration(
                                      color: Color(0xfff1f3f4),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(icon, size: 12, color: _muted),
                                  ),
                              ],
                            ),
                          ),
                          Positioned(
                            left: 18,
                            top: 134,
                            width: 324,
                            child: line(p.localName, size: 10),
                          ),
                          Positioned(
                            left: 18,
                            top: 154,
                            right: 18,
                            child: Row(
                              children: [
                                line(
                                  p.rating.isEmpty ? '—' : p.rating,
                                  size: 11,
                                ),
                                const SizedBox(width: 4),
                                ...List.generate(
                                  5,
                                  (i) => Icon(
                                    i < (double.tryParse(p.rating) ?? 0).round()
                                        ? Icons.star
                                        : Icons.star_border,
                                    size: 12,
                                    color: const Color(0xffedb928),
                                  ),
                                ),
                                const SizedBox(width: 5),
                                if (p.reviewCount.isNotEmpty)
                                  Flexible(
                                    child: line('(${p.reviewCount})', size: 10),
                                  ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.volume_up_outlined,
                                  color: _teal,
                                  size: 12,
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            left: 18,
                            top: 173,
                            width: 324,
                            child: line(
                              [
                                p.category,
                                p.price,
                              ].where((s) => s.isNotEmpty).join(' · '),
                            ),
                          ),
                          if (!project.review.visible)
                            Positioned(
                              left: 18,
                              top: 628,
                              width: 324,
                              child: line(p.address, size: 9),
                            ),
                          Positioned(
                            left: 18,
                            top: 193,
                            width: 324,
                            child: line(
                              p.hours.isEmpty ? 'Hours not set' : p.hours,
                              color: const Color(0xff39825d),
                            ),
                          ),
                          Positioned(
                            left: 16,
                            right: 16,
                            top: 214,
                            height: 27,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (final action in p.actions)
                                  Expanded(
                                    child: Container(
                                      margin: const EdgeInsets.only(right: 4),
                                      decoration: BoxDecoration(
                                        color: action.kind == 'directions'
                                            ? _teal
                                            : _pale,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            placeActionIcon(action.kind),
                                            size: 11,
                                            color: action.kind == 'directions'
                                                ? Colors.white
                                                : _teal,
                                          ),
                                          const SizedBox(width: 3),
                                          Flexible(
                                            child: line(
                                              action.label,
                                              size: 8,
                                              color: action.kind == 'directions'
                                                  ? Colors.white
                                                  : _teal,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (caption.isNotEmpty)
                            Positioned(
                              left: TemplateLayout.galleryLeft + 10,
                              right: TemplateLayout.galleryLeft + 10,
                              top: 446,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: .72),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: line(
                                  caption,
                                  size: 14,
                                  color: Colors.white,
                                  lines: 2,
                                ),
                              ),
                            ),
                          if (project.review.visible)
                            Positioned(
                              left: 16,
                              right: 16,
                              top: 530,
                              height: 100,
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xffeef0f2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 12,
                                          backgroundColor: const Color(
                                            0xffe97e16,
                                          ),
                                          child: Text(
                                            project.review.author.trim().isEmpty
                                                ? '★'
                                                : String.fromCharCodes(
                                                    project.review.author
                                                        .trim()
                                                        .runes
                                                        .take(1),
                                                  ).toUpperCase(),
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 7),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              line(
                                                project.review.author
                                                        .trim()
                                                        .isEmpty
                                                    ? 'Featured review'
                                                    : project.review.author,
                                                size: 10,
                                                color: const Color(0xff202124),
                                              ),
                                              Row(
                                                children: [
                                                  for (var i = 0; i < 5; i++)
                                                    Icon(
                                                      i < project.review.rating
                                                          ? Icons.star
                                                          : Icons.star_border,
                                                      size: 10,
                                                      color: const Color(
                                                        0xffedb928,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 7),
                                    Expanded(
                                      child: line(
                                        project.review.text.trim(),
                                        size: 10,
                                        lines: 4,
                                        color: const Color(0xff444a50),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else ...[
                            Positioned(
                              left: 16,
                              right: 16,
                              top: 530,
                              height: 25,
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  for (final tab in [
                                    'Overview',
                                    if (p.hasMenu) 'Menu',
                                    'Reviews',
                                    'Photos',
                                    'Updates',
                                  ])
                                    Container(
                                      padding: const EdgeInsets.only(bottom: 7),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(
                                            color: tab == 'Overview'
                                                ? _teal
                                                : Colors.transparent,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                      child: line(
                                        tab,
                                        size: 8,
                                        color: tab == 'Overview'
                                            ? _teal
                                            : _muted,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Positioned(
                              left: 16,
                              right: 16,
                              top: 565,
                              height: 28,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _pale,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.open_in_new,
                                      color: _teal,
                                      size: 12,
                                    ),
                                    const SizedBox(width: 6),
                                    line(p.footer, size: 11, color: _teal),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              left: 18,
                              right: 18,
                              top: 610,
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.schedule,
                                    color: _muted,
                                    size: 12,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: line(
                                      p.hours.isEmpty
                                          ? 'Hours not set'
                                          : p.hours,
                                      size: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (project.clips.isNotEmpty) ...[
                            Positioned(
                              left: 18,
                              top: 242,
                              child: line(
                                'Photos & videos',
                                size: 7,
                                color: const Color(0xff202124),
                              ),
                            ),
                            Positioned(
                              right: 18,
                              top: 242,
                              child: line(
                                '${index + 1} / ${project.clips.length}',
                                size: 7,
                                color: const Color(0xff1a73e8),
                              ),
                            ),
                            Positioned(
                              left: 16,
                              right: 16,
                              top: 510,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  for (var i = 0; i < project.clips.length; i++)
                                    Container(
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 2,
                                      ),
                                      width: i == index ? 5 : 3,
                                      height: i == index ? 5 : 3,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: i == index
                                            ? const Color(0xff1a73e8)
                                            : const Color(0xffd4d8de),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                          if (showTags)
                            Positioned.fill(
                              child: StoryTagLayer(tags: project.tags),
                            ),
                          if (project.storyChrome) ...[
                            const Positioned(
                              left: 16,
                              top: 20,
                              child: Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            const Positioned(
                              right: 20,
                              top: 20,
                              child: Text(
                                'Aa',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const Positioned(
                              right: 20,
                              top: 54,
                              child: Icon(
                                Icons.sentiment_satisfied_alt,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            for (var i = 0; i < 3; i++)
                              Positioned(
                                right: 10,
                                top: 106 + i * 36,
                                child: Container(
                                  width: 29,
                                  height: 29,
                                  decoration: const BoxDecoration(
                                    color: Color(0xff929292),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    [
                                      Icons.music_note,
                                      Icons.auto_awesome,
                                      Icons.favorite_border,
                                    ][i],
                                    size: 13,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
