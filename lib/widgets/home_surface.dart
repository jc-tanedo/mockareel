import 'package:flutter/material.dart';
import '../model/feed.dart';
import 'reference_home_surface.dart';

/// The output surface is shared by preview, thumbnails and captured export UI.
class HomeSurface extends StatelessWidget {
  final FeedSettings settings;
  final bool transparentBackground;
  const HomeSurface({
    super.key,
    required this.settings,
    this.transparentBackground = false,
  });
  @override
  Widget build(BuildContext context) => settings.homeOs == HomeOs.android
      ? _AndroidHome(
          settings: settings,
          transparentBackground: transparentBackground,
        )
      : ReferenceHomeSurface(
          settings: settings,
          transparentBackground: transparentBackground,
        );
}

/// Preserve the original, generic Android preset alongside the reference layouts.
class _AndroidHome extends StatelessWidget {
  final FeedSettings settings;
  final bool transparentBackground;
  const _AndroidHome({
    required this.settings,
    required this.transparentBackground,
  });
  @override
  Widget build(BuildContext context) {
    final hasChrome =
        settings.showIcons ||
        settings.showClock ||
        settings.showStatus ||
        settings.showWidget;
    return Stack(
      children: [
        if (!transparentBackground)
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xff285556),
                    Color(0xff17343a),
                    Color(0xff8a9f84),
                  ],
                ),
              ),
            ),
          ),
        if (hasChrome)
          const Positioned.fill(child: ColoredBox(color: Colors.black26)),
        if (settings.showStatus)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SizedBox(
              height: 32,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Row(
                  children: [
                    Text(
                      settings.time,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 7),
                    const Icon(Icons.notifications_none, size: 11),
                    const Spacer(),
                    const Icon(Icons.network_cell, size: 13),
                    const SizedBox(width: 5),
                    const Icon(Icons.wifi, size: 14),
                    const SizedBox(width: 5),
                    const Icon(Icons.battery_full, size: 17),
                  ],
                ),
              ),
            ),
          ),
        if (settings.showClock) ...[
          Positioned(
            top: 48,
            left: 28,
            right: 20,
            child: Text(
              settings.time,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 52,
                fontWeight: FontWeight.w200,
                letterSpacing: -2,
              ),
            ),
          ),
          Positioned(
            top: 122,
            left: 28,
            right: 20,
            child: Text(
              settings.date,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
        if (settings.showWidget)
          Positioned(
            top: 162,
            left: 22,
            right: 22,
            height: 126,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: .12)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.auto_awesome, size: 18),
                      SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          'DAILY NOTE',
                          style: TextStyle(fontSize: 9, letterSpacing: 1.5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Text(
                      settings.widgetTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 19,
                        height: 1.15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    settings.widgetText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
        if (settings.showIcons) ...[
          for (var i = 0; i < 8; i++)
            Positioned(
              top: 324.0 + (i ~/ 4) * 86,
              left: 20.0 + (i % 4) * 80,
              width: 80,
              child: Column(
                key: ValueKey('home-app-$i'),
                children: [
                  _tile(
                    _icons[i < settings.appIcons.length
                        ? settings.appIcons[i].clamp(0, 11)
                        : i],
                    _colors[i],
                    feed: i == 3,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    i < settings.appLabels.length
                        ? settings.appLabels[i]
                        : 'App',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 9),
                  ),
                ],
              ),
            ),
          Positioned(
            top: 502,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 3; i++)
                  Container(
                    width: 4,
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == 0 ? Colors.white : Colors.white38,
                    ),
                  ),
              ],
            ),
          ),
          Positioned(
            top: 540,
            left: 14,
            right: 14,
            height: 70,
            child: Row(
              key: const ValueKey('home-dock'),
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _tile(Icons.call, const Color(0xff37bb77)),
                _tile(Icons.public, const Color(0xff3699e2)),
                _tile(Icons.message, const Color(0xff37bb77)),
                _tile(Icons.headphones, const Color(0xffe25878)),
              ],
            ),
          ),
          const Positioned(
            top: 626,
            left: 0,
            right: 0,
            height: 7,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Icon(Icons.arrow_left, size: 18),
                Icon(Icons.circle_outlined, size: 13),
                Icon(Icons.crop_square, size: 13),
              ],
            ),
          ),
        ],
      ],
    );
  }

  static const _icons = [
    Icons.photo_library,
    Icons.camera_alt,
    Icons.edit_note,
    Icons.music_note,
    Icons.wb_sunny,
    Icons.graphic_eq,
    Icons.chat,
    Icons.settings,
    Icons.map,
    Icons.mail,
    Icons.schedule,
    Icons.videocam,
  ];
  static const _colors = [
    Color(0xffc86fb2),
    Color(0xff636773),
    Color(0xffd1b65e),
    Colors.black,
    Color(0xff5da5cb),
    Color(0xffdf626d),
    Color(0xff51ae83),
    Color(0xff758293),
  ];
  Widget _tile(IconData icon, Color color, {bool feed = false}) => Container(
    width: 50,
    height: 50,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(25),
    ),
    child: Icon(
      icon,
      size: 28,
      color: feed ? const Color(0xff25f4ee) : Colors.white,
    ),
  );
}
