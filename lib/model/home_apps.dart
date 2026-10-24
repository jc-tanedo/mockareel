import 'home_os.dart';

enum HomeGlyph {
  messages,
  calendar,
  photos,
  camera,
  weather,
  clock,
  maps,
  videos,
  wallet,
  notes,
  reminders,
  stocks,
  itunes,
  appStore,
  books,
  news,
  health,
  settings,
  tiktok,
  phone,
  safari,
  mail,
  music,
  chrome,
  playStore,
  gallery,
  store,
  folder,
  internet,
}

class HomeApp {
  String label;
  HomeGlyph glyph;
  HomeApp(this.label, this.glyph);
  factory HomeApp.fromJson(Map<String, dynamic> json) => HomeApp(
    json['label'] as String? ?? '',
    HomeGlyph.values.firstWhere(
      (g) => g.name == json['glyph'],
      orElse: () => HomeGlyph.folder,
    ),
  );
  Map<String, dynamic> toJson() => {'label': label, 'glyph': glyph.name};
}

abstract final class HomeApps {
  static const iphone = [
    ('Messages', HomeGlyph.messages),
    ('Calendar', HomeGlyph.calendar),
    ('Photos', HomeGlyph.photos),
    ('Camera', HomeGlyph.camera),
    ('Weather', HomeGlyph.weather),
    ('Clock', HomeGlyph.clock),
    ('Maps', HomeGlyph.maps),
    ('Videos', HomeGlyph.videos),
    ('Wallet', HomeGlyph.wallet),
    ('Notes', HomeGlyph.notes),
    ('Reminders', HomeGlyph.reminders),
    ('Stocks', HomeGlyph.stocks),
    ('iTunes Store', HomeGlyph.itunes),
    ('App Store', HomeGlyph.appStore),
    ('iBooks', HomeGlyph.books),
    ('News', HomeGlyph.news),
    ('Health', HomeGlyph.health),
    ('Settings', HomeGlyph.settings),
    ('TikTok', HomeGlyph.tiktok),
    ('', HomeGlyph.folder),
  ];
  static List<HomeApp> grid(HomeOs os) => [
    for (final a in switch (os) {
      HomeOs.iphone => iphone,
      HomeOs.pixel => const [
        ('Business', HomeGlyph.folder),
        ('Google', HomeGlyph.folder),
        ('Tools', HomeGlyph.folder),
        ('TV', HomeGlyph.folder),
        ('TikTok', HomeGlyph.tiktok),
      ],
      HomeOs.oneUi => const [
        ('Store', HomeGlyph.store),
        ('Gallery', HomeGlyph.gallery),
        ('Play Store', HomeGlyph.playStore),
        ('TikTok', HomeGlyph.tiktok),
      ],
      HomeOs.android => const [
        ('Photos', HomeGlyph.photos),
        ('Camera', HomeGlyph.camera),
        ('Notes', HomeGlyph.notes),
        ('TikTok', HomeGlyph.tiktok),
        ('Weather', HomeGlyph.weather),
        ('Music', HomeGlyph.music),
        ('Messages', HomeGlyph.messages),
        ('Settings', HomeGlyph.settings),
      ],
    })
      HomeApp(a.$1, a.$2),
  ];
  static List<HomeApp> dock(HomeOs os) => [
    for (final a in switch (os) {
      HomeOs.iphone => const [
        ('Phone', HomeGlyph.phone),
        ('Safari', HomeGlyph.safari),
        ('Mail', HomeGlyph.mail),
        ('Music', HomeGlyph.music),
      ],
      HomeOs.pixel => const [
        ('Phone', HomeGlyph.phone),
        ('Messages', HomeGlyph.messages),
        ('Camera', HomeGlyph.camera),
        ('Chrome', HomeGlyph.chrome),
        ('Play Store', HomeGlyph.playStore),
      ],
      _ => const [
        ('Phone', HomeGlyph.phone),
        ('Messages', HomeGlyph.messages),
        ('Internet', HomeGlyph.internet),
        ('Camera', HomeGlyph.camera),
      ],
    })
      HomeApp(a.$1, a.$2),
  ];
  static const legacyGlyphs = [
    HomeGlyph.photos,
    HomeGlyph.camera,
    HomeGlyph.notes,
    HomeGlyph.music,
    HomeGlyph.weather,
    HomeGlyph.music,
    HomeGlyph.messages,
    HomeGlyph.settings,
    HomeGlyph.maps,
    HomeGlyph.mail,
    HomeGlyph.clock,
    HomeGlyph.videos,
  ];
  static const legacyLabels = [
    'Photos',
    'Camera',
    'Notes',
    'TikTok',
    'Weather',
    'Music',
    'Messages',
    'Settings',
  ];
}

class HomeIconPosition {
  final double left, top, size, radius;
  const HomeIconPosition(this.left, this.top, this.size, this.radius);
}

abstract final class HomeLayout {
  static int defaultLaunch(HomeOs os) => switch (os) {
    HomeOs.iphone => 18,
    HomeOs.pixel => 4,
    _ => 3,
  };
  static HomeIconPosition icon(HomeOs os, int slot) => switch (os) {
    HomeOs.iphone => HomeIconPosition(
      18 + (slot % 4) * 86,
      28 + (slot ~/ 4) * 99,
      68,
      17,
    ),
    HomeOs.pixel => HomeIconPosition(22 + (slot % 5) * 65.5, 434, 44, 22),
    HomeOs.oneUi => HomeIconPosition(28 + (slot % 4) * 82, 444, 58, 16),
    HomeOs.android => HomeIconPosition(
      35 + (slot % 4) * 80,
      324 + (slot ~/ 4) * 86,
      50,
      25,
    ),
  };
}
