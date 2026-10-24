import 'dart:math';
import 'project.dart';

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

class FeedPost {
  String username, title, caption, sound, likes, comments, saves, shares;
  String? avatarPath;
  bool verified, following;
  FeedPost({
    this.username = 'yourname',
    this.title = '',
    this.caption = 'A little moment worth sharing. #fyp',
    this.sound = 'original sound',
    this.likes = '24.8K',
    this.comments = '128',
    this.saves = '2,041',
    this.shares = '386',
    this.avatarPath,
    this.verified = false,
    this.following = false,
  });
  factory FeedPost.fromJson(Map<String, dynamic> j) => FeedPost(
    username: j['username'] as String? ?? 'yourname',
    title: j['title'] as String? ?? '',
    caption: j['caption'] as String? ?? 'A little moment worth sharing. #fyp',
    sound: j['sound'] as String? ?? 'original sound',
    likes: j['likes'] as String? ?? '24.8K',
    comments: j['comments'] as String? ?? '128',
    saves: j['saves'] as String? ?? '2,041',
    shares: j['shares'] as String? ?? '386',
    avatarPath: j['avatarPath'] as String?,
    verified: j['verified'] == true,
    following: j['following'] == true,
  );
  Map<String, dynamic> toJson() => {
    'username': username,
    'title': title,
    'caption': caption,
    'sound': sound,
    'likes': likes,
    'comments': comments,
    'saves': saves,
    'shares': shares,
    'avatarPath': avatarPath,
    'verified': verified,
    'following': following,
  };
}

enum HomeOs {
  iphone('iPhone · iOS', 316, 13),
  android('Android', 324, 25),
  pixel('Google Pixel', 332, 25),
  oneUi('Samsung · One UI', 324, 16);

  final String label;
  final double iconTop, iconRadius;
  const HomeOs(this.label, this.iconTop, this.iconRadius);
}

class FeedSettings {
  String opening, search, time, date, widgetTitle, widgetText;
  List<String> appLabels;
  List<int> appIcons;
  HomeOs homeOs;
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
    this.showIcons = true,
    this.showClock = true,
    this.showWidget = true,
    this.showStatus = true,
    this.closeToHome = false,
    this.typingSeconds = 2,
    this.loadingSeconds = .8,
    this.homeSeconds = 2,
    this.homeMedia,
  }) : appIcons = appIcons ?? List.generate(8, (i) => i),
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
      ? homeSeconds + .6
      : 0;
  double get outroDuration => closeToHome ? .65 + homeSeconds : 0;
  factory FeedSettings.fromJson(Map<String, dynamic> j) => FeedSettings(
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

/// The same scene plan drives scrubbing, playback and native export.
class FeedScene {
  final String kind;
  final int postIndex;
  final double start, duration;
  const FeedScene(this.kind, this.postIndex, this.start, this.duration);
}

abstract final class FeedTimeline {
  static List<FeedScene> scenes(ReelProject p) {
    final result = <FeedScene>[];
    var start = 0.0;
    void add(String kind, int index, double seconds) {
      result.add(FeedScene(kind, index, start, seconds));
      start += seconds;
    }

    if (p.feed.introDuration > 0) {
      add(p.feed.hasSearch ? 'search' : 'home-open', 0, p.feed.introDuration);
    }
    for (var i = 0; i < p.clips.length; i++) {
      add('post', i, p.clips[i].duration);
    }
    if (p.feed.closeToHome) {
      add('home-close', max(0, p.clips.length - 1), p.feed.outroDuration);
    }
    return result;
  }

  static double duration(ReelProject p) =>
      scenes(p).fold(0, (n, s) => n + s.duration);
  static FeedScene at(ReelProject p, double time) {
    final all = scenes(p);
    return all.firstWhere(
      (s) => time < s.start + s.duration,
      orElse: () => all.isEmpty ? const FeedScene('post', 0, 0, 0) : all.last,
    );
  }

  static double postStart(ReelProject p, int index) =>
      p.feed.introDuration + p.startOf(index);
  static double transition(ReelProject p, int index) =>
      index == 0 ? 0 : min(p.slideSeconds, p.clips[index].duration * .45);
  static double entry(ReelProject p, int index, double elapsed) {
    final d = transition(p, index);
    return d <= 0 ? 0 : 640 * pow(1 - (elapsed / d).clamp(0, 1), 3).toDouble();
  }
}
