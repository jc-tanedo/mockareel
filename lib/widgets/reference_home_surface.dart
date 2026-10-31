import 'package:flutter/material.dart';
import '../model/feed.dart';
import 'home_app_icon.dart';
import 'launcher_wallpaper.dart';
import 'reference_home_widgets.dart';

/// Classic iOS, Pixel Launcher and One UI each keep their own layout grammar.
class ReferenceHomeSurface extends StatelessWidget {
  final FeedSettings settings;
  final bool transparentBackground;
  const ReferenceHomeSurface({
    super.key,
    required this.settings,
    required this.transparentBackground,
  });
  bool get _iphone => settings.homeOs == HomeOs.iphone;
  bool get _pixel => settings.homeOs == HomeOs.pixel;
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      if (!transparentBackground)
        Positioned.fill(
          child: CustomPaint(painter: LauncherWallpaper(settings.homeOs)),
        ),
      if (settings.showStatus)
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: _iphone ? 23 : 30,
          child: _status(),
        ),
      if (!_iphone && (settings.showClock || settings.showWidget))
        ...(_pixel ? _pixelGlance() : _samsungWidgets()),
      if (settings.showIcons) ...[
        for (var i = 0; i < settings.homeApps.length; i++)
          if (settings.homeApps[i].label.trim().isNotEmpty ||
              i == settings.launchSlot)
            _app(i),
        if (!_pixel)
          Positioned(
            top: _iphone ? 519 : 537,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_iphone)
                  const Padding(
                    padding: EdgeInsets.only(right: 9),
                    child: Icon(Icons.search, size: 8, color: Colors.white54),
                  ),
                for (var i = 0; i < 3; i++)
                  Container(
                    width: i == 0 ? 6 : 4,
                    height: i == 0 ? 6 : 4,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == 0 ? Colors.white : Colors.white38,
                    ),
                  ),
              ],
            ),
          ),
        _dock(),
        if (_pixel) _search(587),
        if (!_iphone)
          Positioned(
            top: 628,
            left: 0,
            right: 0,
            height: 6,
            child: _pixel
                ? Center(
                    child: Container(
                      width: 80,
                      height: 3,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      RotatedBox(
                        quarterTurns: 1,
                        child: Icon(
                          Icons.menu,
                          size: 13,
                          color: Colors.white70,
                        ),
                      ),
                      Icon(
                        Icons.crop_square_rounded,
                        size: 13,
                        color: Colors.white70,
                      ),
                      Icon(Icons.chevron_left, size: 16, color: Colors.white70),
                    ],
                  ),
          ),
      ],
      if (!_iphone && !_pixel && settings.showWidget) _search(380),
    ],
  );
  Widget _status() {
    final period = settings.iphonePeriod;
    final time =
        _iphone &&
            period.isNotEmpty &&
            settings.time.trim().isNotEmpty &&
            !RegExp(
              r'(?:AM|PM)\s*$',
              caseSensitive: false,
            ).hasMatch(settings.time)
        ? '${settings.time} $period'
        : settings.time;
    return Stack(
      alignment: Alignment.center,
      children: [
        if (_iphone)
          Positioned(
            left: 7,
            child: Row(
              children: [
                for (var i = 0; i < 5; i++)
                  Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.only(right: 2),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                  ),
                const SizedBox(width: 3),
                const Icon(Icons.wifi, size: 14, color: Colors.white),
              ],
            ),
          )
        else
          Positioned(
            left: 20,
            child: Row(
              children: [
                Text(
                  time,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.notifications_none, size: 9),
                const SizedBox(width: 4),
                const Icon(Icons.mail, size: 8),
              ],
            ),
          ),
        if (_iphone)
          Text(
            time,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          )
        else
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: Colors.black87,
              shape: BoxShape.circle,
            ),
          ),
        Positioned(
          right: 8,
          child: Row(
            children: [
              if (!_iphone) ...[
                const Icon(Icons.signal_cellular_alt, size: 11),
                const SizedBox(width: 4),
                const Icon(Icons.wifi, size: 11),
                const SizedBox(width: 4),
              ],
              Container(
                width: _iphone ? 24 : 10,
                height: _iphone ? 10 : 7,
                padding: const EdgeInsets.all(1),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white70),
                  borderRadius: BorderRadius.circular(1.5),
                ),
                child: const ColoredBox(color: Colors.white),
              ),
              if (_iphone)
                const SizedBox(
                  width: 2,
                  height: 4,
                  child: ColoredBox(color: Colors.white70),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _app(int i) {
    final app = settings.homeApps[i],
        position = HomeLayout.icon(settings.homeOs, i);
    final labelWidth = _iphone
        ? 86.0
        : _pixel
        ? 65.5
        : 82.0;
    return Positioned(
      left: position.left - (labelWidth - position.size) / 2,
      top: position.top,
      width: labelWidth,
      height: position.size + 26,
      child: Column(
        key: ValueKey('home-app-$i'),
        children: [
          SizedBox(
            width: position.size,
            height: position.size,
            child: HomeAppIcon(
              glyph: app.glyph,
              os: settings.homeOs,
              date: settings.date,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            app.label.isEmpty ? 'TikTok' : app.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: _iphone ? 12 : 9,
              fontWeight: FontWeight.w400,
              height: 1.1,
              shadows: const [
                Shadow(
                  color: Colors.black54,
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dock() {
    final apps = settings.homeDock;
    final top = _iphone
        ? 535.0
        : _pixel
        ? 528.0
        : 562.0;
    final count = _pixel ? 5 : 4;
    final tile = _iphone
        ? 68.0
        : _pixel
        ? 44.0
        : 56.0;
    return Positioned(
      left: 0,
      top: top,
      right: 0,
      height: _iphone ? 105 : 64,
      child: Container(
        key: const ValueKey('home-dock'),
        color: _iphone
            ? Colors.white.withValues(alpha: .25)
            : Colors.transparent,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < apps.length && i < count; i++)
              Padding(
                padding: EdgeInsets.only(top: _iphone ? 13 : 0),
                child: SizedBox(
                  width: _iphone
                      ? 86
                      : _pixel
                      ? 65.5
                      : 82,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: tile,
                        height: tile,
                        child: HomeAppIcon(
                          glyph: apps[i].glyph,
                          os: settings.homeOs,
                        ),
                      ),
                      if (_iphone) ...[
                        const SizedBox(height: 7),
                        Text(
                          apps[i].label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            shadows: [
                              Shadow(color: Colors.black45, blurRadius: 3),
                            ],
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
    );
  }

  List<Widget> _pixelGlance() => [
    if (settings.showClock)
      Positioned(
        top: 78,
        left: 23,
        right: 23,
        child: Text(
          settings.date,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ),
    if (settings.showWidget)
      Positioned(
        top: 101,
        left: 23,
        child: Row(
          children: [
            const Icon(Icons.wb_sunny, color: Color(0xffffdf72), size: 13),
            const SizedBox(width: 5),
            Text(
              settings.weatherTemperature,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
  ];
  List<Widget> _samsungWidgets() => [
    if (settings.showWidget) ...[
      Positioned(
        top: 202,
        left: 24,
        width: 145,
        height: 148,
        child: SamsungWeatherCard(settings: settings),
      ),
      Positioned(
        top: 202,
        left: 184,
        right: 24,
        height: 64,
        child: SamsungBriefCard(text: settings.briefTitle, health: false),
      ),
      Positioned(
        top: 282,
        left: 184,
        right: 24,
        height: 68,
        child: SamsungBriefCard(text: settings.healthTitle, health: true),
      ),
    ],
  ];

  Widget _search(double top) => Positioned(
    top: top,
    left: 23,
    right: 23,
    height: 35,
    child: GoogleSearchBarWidget(pixel: _pixel),
  );
}
