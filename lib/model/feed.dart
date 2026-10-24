import 'app_window_motion.dart';
import 'home_apps.dart';
import 'home_os.dart';
export 'home_apps.dart';
export 'home_os.dart';
import 'reel_clip.dart';
export 'feed_post.dart';

double _number(
  Map<String, dynamic> j,
  String key,
  double fallback,
  double lo,
  double hi,
) {
  final n = (j[key] as num?)?.toDouble() ?? fallback;
  return n.isFinite ? n.clamp(lo, hi) : fallback;
}

class FeedSettings {
  String opening, search, time, date, widgetTitle, widgetText;
  List<String> appLabels;
  List<int> appIcons;
  HomeOs homeOs;
  final Map<String, List<HomeApp>> appProfiles, dockProfiles;
  final Map<String, int> launchSlots;
  String weatherTemperature,
      weatherLocation,
      briefTitle,
      healthTitle,
      iphonePeriod;
  List<HomeApp> get homeApps {
    return appProfiles.putIfAbsent(homeOs.name, () {
      final apps = HomeApps.grid(homeOs);
      // Preserve customized labels/icons from the original eight-slot projects.
      for (var i = 0; i < apps.length && i < 8; i++) {
        final label = i < appLabels.length
            ? appLabels[i]
            : HomeApps.legacyLabels[i];
        final glyph = i < appIcons.length ? appIcons[i] : i;
        if (label != HomeApps.legacyLabels[i] || glyph != i) {
          apps[i] = HomeApp(label, HomeApps.legacyGlyphs[glyph.clamp(0, 11)]);
        }
      }
      return apps;
    });
  }

  List<HomeApp> get homeDock =>
      dockProfiles.putIfAbsent(homeOs.name, () => HomeApps.dock(homeOs));
  int get launchSlot =>
      (launchSlots[homeOs.name] ?? HomeLayout.defaultLaunch(homeOs)).clamp(
        0,
        homeApps.length - 1,
      );
  HomeIconPosition get launchIcon => HomeLayout.icon(homeOs, launchSlot);
  void moveLaunch(int slot) {
    final apps = homeApps;
    final from = launchSlot;
    final app = apps[from];
    apps[from] = apps[slot];
    apps[slot] = app;
    launchSlots[homeOs.name] = slot;
  }

  bool showWidget, showStatus, showIcons, showClock;
  bool closeToHome;
  double typingSeconds, loadingSeconds, homeSeconds;
  ReelClip? homeMedia;
  FeedSettings({
    this.opening = 'search',
    this.search = '',
    this.time = '9:41',
    this.date = 'Saturday, October 24',
    this.widgetTitle = 'Make room for good things',
    this.widgetText = 'A little inspiration, every day.',
    List<String>? appLabels,
    List<int>? appIcons,
    this.homeOs = HomeOs.iphone,
    Map<String, List<HomeApp>>? appProfiles,
    Map<String, List<HomeApp>>? dockProfiles,
    Map<String, int>? launchSlots,
    this.weatherTemperature = '22°',
    this.weatherLocation = 'Your city',
    this.briefTitle = 'Now brief',
    this.healthTitle = 'Start',
    this.iphonePeriod = 'AM',
    this.showIcons = true,
    this.showClock = true,
    this.showWidget = true,
    this.showStatus = true,
    this.closeToHome = false,
    this.typingSeconds = 2,
    this.loadingSeconds = .8,
    this.homeSeconds = 2,
    this.homeMedia,
  }) : appProfiles = appProfiles ?? {},
       dockProfiles = dockProfiles ?? {},
       launchSlots = launchSlots ?? {},
       appIcons = appIcons ?? List.generate(8, (i) => i),
       appLabels =
           appLabels ??
           [
             'Photos',
             'Camera',
             'Notes',
             'TikTok',
             'Weather',
             'Music',
             'Messages',
             'Settings',
           ];
  bool get hasSearch => opening == 'search' && search.trim().isNotEmpty;
  double get introDuration => hasSearch
      ? typingSeconds + loadingSeconds
      : opening == 'home'
      ? homeSeconds + AppWindowMotion.launchSeconds
      : 0;
  double get outroDuration =>
      closeToHome ? AppWindowMotion.closeSeconds + homeSeconds : 0;
  static Map<String, List<HomeApp>> _profiles(
    dynamic json, {
    bool dock = false,
  }) {
    if (json is! Map) return {};
    return {
      for (final os in HomeOs.values)
        if (json[os.name] is List && (json[os.name] as List).isNotEmpty)
          os.name: (json[os.name] as List)
              .take(
                dock
                    ? (os == HomeOs.pixel ? 5 : 4)
                    : os == HomeOs.iphone
                    ? 20
                    : os == HomeOs.pixel
                    ? 5
                    : os == HomeOs.oneUi
                    ? 4
                    : 8,
              )
              .map((v) => HomeApp.fromJson(Map<String, dynamic>.from(v as Map)))
              .toList(),
    };
  }

  factory FeedSettings.fromJson(Map<String, dynamic> j) => FeedSettings(
    appProfiles: _profiles(j['appProfiles']),
    dockProfiles: _profiles(j['dockProfiles'], dock: true),
    launchSlots: {
      for (final os in HomeOs.values)
        if ((j['launchSlots'] as Map?)?[os.name] is num)
          os.name: ((j['launchSlots'] as Map)[os.name] as num).toInt(),
    },
    weatherTemperature: j['weatherTemperature'] as String? ?? '22°',
    weatherLocation: j['weatherLocation'] as String? ?? 'Your city',
    briefTitle: j['briefTitle'] as String? ?? 'Now brief',
    healthTitle: j['healthTitle'] as String? ?? 'Start',
    iphonePeriod: ['AM', 'PM', ''].contains(j['iphonePeriod'])
        ? j['iphonePeriod'] as String
        : 'AM',
    appIcons: (j['appIcons'] as List?)
        ?.map((e) => (e as num).toInt().clamp(0, 11))
        .take(8)
        .toList(),
    homeOs: HomeOs.values.firstWhere(
      (os) => os.name == j['homeOs'],
      orElse: () => HomeOs.iphone,
    ),
    showIcons: j['showIcons'] != false,
    showClock: j['showClock'] != false,
    showWidget: j['showWidget'] != false,
    showStatus: j['showStatus'] != false,
    opening: ['search', 'home', 'feed'].contains(j['opening'])
        ? j['opening'] as String
        : 'search',
    search: j['search'] as String? ?? '',
    time: j['time'] as String? ?? '9:41',
    date: j['date'] as String? ?? 'Saturday, October 24',
    widgetTitle: j['widgetTitle'] as String? ?? 'Make room for good things',
    widgetText:
        j['widgetText'] as String? ?? 'A little inspiration, every day.',
    appLabels: (j['appLabels'] as List?)
        ?.map((e) => e.toString())
        .take(8)
        .toList(),
    closeToHome: j['closeToHome'] == true,
    typingSeconds: _number(j, 'typingSeconds', 2, .5, 6),
    loadingSeconds: _number(j, 'loadingSeconds', .8, .2, 3),
    homeSeconds: _number(j, 'homeSeconds', 2, .5, 6),
    homeMedia: j['homeMedia'] == null
        ? null
        : ReelClip.fromJson(Map<String, dynamic>.from(j['homeMedia'] as Map)),
  );
  Map<String, dynamic> toJson() => {
    'appProfiles': {
      for (final e in appProfiles.entries)
        e.key: e.value.map((a) => a.toJson()).toList(),
    },
    'dockProfiles': {
      for (final e in dockProfiles.entries)
        e.key: e.value.map((a) => a.toJson()).toList(),
    },
    'launchSlots': launchSlots,
    'weatherTemperature': weatherTemperature,
    'weatherLocation': weatherLocation,
    'briefTitle': briefTitle,
    'healthTitle': healthTitle,
    'iphonePeriod': iphonePeriod,
    'homeOs': homeOs.name,
    'showIcons': showIcons,
    'showClock': showClock,
    'appIcons': appIcons,
    'showWidget': showWidget,
    'showStatus': showStatus,
    'opening': opening,
    'search': search,
    'time': time,
    'date': date,
    'widgetTitle': widgetTitle,
    'widgetText': widgetText,
    'appLabels': appLabels,
    'closeToHome': closeToHome,
    'typingSeconds': typingSeconds,
    'loadingSeconds': loadingSeconds,
    'homeSeconds': homeSeconds,
    'homeMedia': homeMedia?.toJson(),
  };
}
