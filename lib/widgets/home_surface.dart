import 'package:flutter/material.dart';
import '../model/feed.dart';

/// Shared output surface for preview, thumbnails and animated export frames.
class HomeSurface extends StatelessWidget {
  final FeedSettings settings;
  final bool transparentBackground;
  const HomeSurface({
    super.key,
    required this.settings,
    this.transparentBackground = false,
  });
  bool get _ios => settings.homeOs == HomeOs.iphone;
  bool get _pixel => settings.homeOs == HomeOs.pixel;
  bool get _samsung => settings.homeOs == HomeOs.oneUi;
  @override
  Widget build(BuildContext context) {
    final os = settings.homeOs;
    final hasChrome =
        settings.showIcons ||
        settings.showClock ||
        settings.showStatus ||
        settings.showWidget;
    final colors = switch (os) {
      HomeOs.iphone => const [
        Color(0xff555185),
        Color(0xff222e53),
        Color(0xffb57683),
      ],
      HomeOs.android => const [
        Color(0xff285556),
        Color(0xff17343a),
        Color(0xff8a9f84),
      ],
      HomeOs.pixel => const [
        Color(0xff6f8072),
        Color(0xff35463e),
        Color(0xffc2bda1),
      ],
      HomeOs.oneUi => const [
        Color(0xff4b6991),
        Color(0xff232d54),
        Color(0xff946f9a),
      ],
    };
    return Stack(
      children: [
        if (!transparentBackground)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: colors,
                ),
              ),
            ),
          ),
        if (hasChrome)
          const Positioned.fill(child: ColoredBox(color: Colors.black26)),
        if (settings.showStatus)
          Positioned(top: 0, left: 0, right: 0, child: _status()),
        if (settings.showClock) ...[
          Positioned(
            top: _pixel ? 60 : 48,
            left: _ios || _samsung ? 20 : 28,
            right: 20,
            child: Text(
              settings.time,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: _ios || _samsung ? TextAlign.center : TextAlign.left,
              style: TextStyle(
                fontSize: _samsung
                    ? 60
                    : _pixel
                    ? 56
                    : 52,
                fontWeight: _pixel ? FontWeight.w400 : FontWeight.w200,
                letterSpacing: -2,
              ),
            ),
          ),
          Positioned(
            top: _pixel ? 132 : 122,
            left: 28,
            right: 20,
            child: Text(
              settings.date,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: _ios || _samsung ? TextAlign.center : TextAlign.left,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
        if (settings.showWidget)
          Positioned(
            top: _pixel ? 178 : 162,
            left: 22,
            right: 22,
            height: 126,
            child: _widget(),
          ),
        if (settings.showIcons) ...[
          for (var row = 0; row < 2; row++)
            Positioned(
              top: os.iconTop + row * 86,
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  for (var col = 0; col < 4; col++) _app(row * 4 + col),
                ],
              ),
            ),
          Positioned(
            top: 502,
            left: 0,
            right: 0,
            child: Center(
              child: _pixel
                  ? const Icon(Icons.keyboard_arrow_up, size: 18)
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < 3; i++)
                          Container(
                            width: i == 0 && _samsung ? 12 : 4,
                            height: 4,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: i == 0 ? Colors.white : Colors.white38,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
          Positioned(
            top: _pixel ? 528 : 540,
            left: 14,
            right: 14,
            height: _pixel ? 55 : 70,
            child: _dock(),
          ),
          if (_pixel)
            Positioned(
              top: 589,
              left: 22,
              right: 22,
              height: 32,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xffdce6d5),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.search, color: Color(0xff344334), size: 20),
                    Spacer(),
                    Icon(Icons.mic_none, color: Color(0xff344334), size: 20),
                    SizedBox(width: 12),
                    Icon(
                      Icons.camera_alt_outlined,
                      color: Color(0xff344334),
                      size: 19,
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            top: 626,
            left: 0,
            right: 0,
            height: 7,
            child: _navigation(),
          ),
        ],
      ],
    );
  }

  Widget _status() => SizedBox(
    height: 32,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            children: [
              Text(
                settings.time,
                style: TextStyle(
                  fontSize: _ios ? 12 : 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (!_ios) ...[
                const SizedBox(width: 7),
                const Icon(Icons.notifications_none, size: 11),
              ],
              const Spacer(),
              Icon(
                _ios ? Icons.signal_cellular_alt : Icons.network_cell,
                size: 13,
              ),
              const SizedBox(width: 5),
              const Icon(Icons.wifi, size: 14),
              const SizedBox(width: 5),
              const Icon(Icons.battery_full, size: 17),
            ],
          ),
          if (_pixel || _samsung)
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: Colors.black87,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    ),
  );
  Widget _widget() {
    final foreground = _pixel ? const Color(0xff263d30) : Colors.white;
    final background = _pixel
        ? const Color(0xffdce6d5)
        : _samsung
        ? Colors.black.withValues(alpha: .25)
        : Colors.white.withValues(alpha: _ios ? .18 : .12);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(
          _pixel
              ? 30
              : _samsung
              ? 22
              : _ios
              ? 24
              : 12,
        ),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: foreground),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _pixel
                      ? Icons.wb_sunny_outlined
                      : _samsung
                      ? Icons.cloud_outlined
                      : Icons.auto_awesome,
                  color: foreground,
                  size: 18,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    _pixel
                        ? 'AT A GLANCE'
                        : _samsung
                        ? 'TODAY'
                        : 'DAILY NOTE',
                    maxLines: 1,
                    style: const TextStyle(fontSize: 9, letterSpacing: 1.5),
                  ),
                ),
                if (_samsung)
                  Text(
                    '24°',
                    style: TextStyle(color: foreground, fontSize: 19),
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
                  fontWeight: FontWeight.w600,
                  fontSize: 19,
                  height: 1.15,
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
    );
  }

  static const icons = [
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
      color: _pixel ? const Color(0xffdce6d5) : color,
      borderRadius: BorderRadius.circular(settings.homeOs.iconRadius),
    ),
    child: Icon(
      icon,
      size: 28,
      color: _pixel
          ? const Color(0xff354f3d)
          : feed
          ? const Color(0xff25f4ee)
          : Colors.white,
    ),
  );
  Widget _app(int i) {
    final index = i < settings.appIcons.length
        ? settings.appIcons[i].clamp(0, 11)
        : i;
    return SizedBox(
      key: ValueKey('home-app-$i'),
      width: 64,
      child: Column(
        children: [
          _tile(icons[index], _colors[i], feed: i == 3),
          const SizedBox(height: 5),
          Text(
            i < settings.appLabels.length ? settings.appLabels[i] : 'App',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 9),
          ),
        ],
      ),
    );
  }

  Widget _dock() => Container(
    key: const ValueKey('home-dock'),
    decoration: BoxDecoration(
      color: _ios ? Colors.white.withValues(alpha: .18) : Colors.transparent,
      borderRadius: BorderRadius.circular(26),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _tile(Icons.call, const Color(0xff37bb77)),
        _tile(Icons.public, const Color(0xff3699e2)),
        _tile(Icons.message, const Color(0xff37bb77)),
        _tile(
          _samsung ? Icons.camera_alt : Icons.headphones,
          _samsung ? const Color(0xff636773) : const Color(0xffe25878),
        ),
      ],
    ),
  );
  Widget _navigation() => _ios || _pixel
      ? Center(
          child: Container(
            width: _ios ? 110 : 95,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        )
      : Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: _samsung
              ? const [
                  Icon(Icons.menu, size: 14),
                  Icon(Icons.circle_outlined, size: 14),
                  Icon(Icons.chevron_left, size: 18),
                ]
              : const [
                  Icon(Icons.arrow_left, size: 18),
                  Icon(Icons.circle_outlined, size: 13),
                  Icon(Icons.crop_square, size: 13),
                ],
        );
}
