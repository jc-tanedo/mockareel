import 'feed.dart';
import 'dart:math';

String newId() =>
    '${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(1 << 30)}';

class PlaceDetails {
  String name, category, rating, address, localName, reviewCount, price, hours;
  String? placeId;
  double? latitude, longitude;
  String phone, website;
  List<String> types;
  List<PlaceAction>? actionOverrides;
  bool? menuOverride;
  String? footerOverride;
  bool get hasMenu =>
      menuOverride ??
      types.any(
        (t) =>
            const {
              'restaurant',
              'cafe',
              'coffee_shop',
              'bakery',
              'bar',
              'meal_takeaway',
              'meal_delivery',
              'fast_food_restaurant',
              'food_court',
            }.contains(t) ||
            t.endsWith('_restaurant'),
      );
  List<PlaceAction> get suggestedActions => [
    PlaceAction(kind: 'directions', label: 'Directions'),
    if (hasMenu) PlaceAction(kind: 'menu', label: 'Menu'),
    if (phone.isNotEmpty) PlaceAction(kind: 'call', label: 'Call'),
    if (website.isNotEmpty) PlaceAction(kind: 'website', label: 'Website'),
    PlaceAction(kind: 'save', label: 'Save'),
  ].take(4).toList();
  List<PlaceAction> get actions => actionOverrides ?? suggestedActions;
  String get footer =>
      footerOverride ??
      (hasMenu
          ? 'View menu'
          : website.isNotEmpty
          ? 'Visit website'
          : 'Get directions');
  PlaceDetails({
    this.name = '',
    this.category = '',
    this.rating = '',
    this.address = '',
    this.placeId,
    this.latitude,
    this.longitude,
    this.phone = '',
    this.website = '',
    List<String>? types,
    this.actionOverrides,
    this.menuOverride,
    this.footerOverride,
    this.localName = '',
    this.reviewCount = '',
    this.price = '',
    this.hours = '',
  }) : types = types ?? [];
  factory PlaceDetails.fromJson(Map<String, dynamic> json) => PlaceDetails(
    name: json['name'] as String? ?? '',
    category: (json['category'] ?? json['subtitle']) as String? ?? '',
    rating: json['rating']?.toString() ?? '',
    address: json['address'] as String? ?? '',
    placeId: json['placeId'] as String?,
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
    phone: json['phone'] as String? ?? '',
    website: json['website'] as String? ?? '',
    types: (json['types'] as List? ?? []).cast<String>(),
    actionOverrides: (json['actions'] as List?)
        ?.map((e) => PlaceAction.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    menuOverride: json['menuOverride'] as bool?,
    footerOverride: json['footerOverride'] as String?,
    localName: json['localName'] as String? ?? '',
    reviewCount: json['reviewCount'] as String? ?? '',
    price: json['price'] as String? ?? '',
    hours: json['hours'] as String? ?? '',
  );
  Map<String, dynamic> toJson() => {
    'name': name,
    'category': category,
    'rating': rating,
    'address': address,
    'placeId': placeId,
    'latitude': latitude,
    'longitude': longitude,
    'phone': phone,
    'website': website,
    'types': types,
    'actions': actionOverrides?.map((e) => e.toJson()).toList(),
    'menuOverride': menuOverride,
    'footerOverride': footerOverride,
    'localName': localName,
    'reviewCount': reviewCount,
    'price': price,
    'hours': hours,
  };
}

class PlaceAction {
  String kind, label;
  PlaceAction({required this.kind, required this.label});
  factory PlaceAction.fromJson(Map<String, dynamic> j) => PlaceAction(
    kind: j['kind'] as String? ?? 'custom',
    label: j['label'] as String? ?? 'Action',
  );
  Map<String, dynamic> toJson() => {'kind': kind, 'label': label};
}

class StoryTag {
  final String id;
  String text, style;
  double x, y, size, rotation;
  int color;
  StoryTag({
    String? id,
    this.text = 'Your text',
    this.style = 'badge',
    this.x = .5,
    this.y = .29,
    this.size = 18,
    this.rotation = 0,
    this.color = 0xffffffff,
  }) : id = id ?? newId() {
    normalize();
  }
  void normalize() {
    x = x.isFinite ? x.clamp(0, 1).toDouble() : .5;
    y = y.isFinite ? y.clamp(0, 1).toDouble() : .29;
    size = size.isFinite ? size.clamp(10, 48).toDouble() : 18;
    rotation = rotation.isFinite ? rotation.clamp(-3.14, 3.14).toDouble() : 0;
  }

  factory StoryTag.fromJson(Map<String, dynamic> j) => StoryTag(
    id: j['id'] as String?,
    text: j['text'] as String? ?? '',
    style: j['style'] as String? ?? 'badge',
    x: (j['x'] as num?)?.toDouble() ?? .5,
    y: (j['y'] as num?)?.toDouble() ?? .29,
    size: (j['size'] as num?)?.toDouble() ?? 18,
    rotation: (j['rotation'] as num?)?.toDouble() ?? 0,
    color: (j['color'] as num?)?.toInt() ?? 0xffffffff,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'style': style,
    'x': x,
    'y': y,
    'size': size,
    'rotation': rotation,
    'color': color,
  };
}

class MusicTrack {
  String path, name;
  double sourceDuration, trimStart, volume;
  bool loop;
  MusicTrack({
    required this.path,
    required this.name,
    required this.sourceDuration,
    this.trimStart = 0,
    this.volume = .7,
    this.loop = true,
  }) {
    normalize();
  }
  void normalize() {
    sourceDuration = sourceDuration.isFinite ? max(0, sourceDuration) : 0;
    trimStart = trimStart.isFinite
        ? trimStart.clamp(0, max(0, sourceDuration - .1)).toDouble()
        : 0;
    volume = volume.isFinite ? volume.clamp(0, 1).toDouble() : .7;
  }

  factory MusicTrack.fromJson(Map<String, dynamic> j) => MusicTrack(
    path: j['path'] as String,
    name: j['name'] as String? ?? 'Music',
    sourceDuration: (j['sourceDuration'] as num?)?.toDouble() ?? 0,
    trimStart: (j['trimStart'] as num?)?.toDouble() ?? 0,
    volume: (j['volume'] as num?)?.toDouble() ?? .7,
    loop: j['loop'] != false,
  );
  Map<String, dynamic> toJson() => {
    'path': path,
    'name': name,
    'sourceDuration': sourceDuration,
    'trimStart': trimStart,
    'volume': volume,
    'loop': loop,
  };
}

class ReelClip {
  final String id, path, name;
  final bool isVideo;
  final double sourceDuration;
  double duration, trimStart, cardWidth, cardHeight, zoom, panX;
  String caption;
  FeedPost post;
  ReelClip({
    required this.id,
    required this.path,
    required this.name,
    required this.isVideo,
    this.sourceDuration = 0,
    this.duration = 3.5,
    this.trimStart = 0,
    this.caption = '',
    FeedPost? post,
    this.cardWidth = .78,
    this.cardHeight = 1,
    this.zoom = 1,
    this.panX = 0,
  }) : post = post ?? FeedPost() {
    normalize();
  }
  double get maxDuration =>
      isVideo && sourceDuration > 0 ? min(30, sourceDuration) : 30;
  void normalize() {
    cardWidth = cardWidth.isFinite ? cardWidth.clamp(.45, 1).toDouble() : .78;
    cardHeight = cardHeight.isFinite ? cardHeight.clamp(.55, 1).toDouble() : 1;
    zoom = zoom.isFinite ? zoom.clamp(1, 3).toDouble() : 1;
    panX = panX.isFinite ? panX.clamp(-1, 1).toDouble() : 0;
    final max = maxDuration;
    duration = duration.isFinite
        ? duration.clamp(min(.5, max), max).toDouble()
        : min(3.5, max);
    trimStart = isVideo && sourceDuration > 0 && trimStart.isFinite
        ? trimStart.clamp(0, sourceDuration - duration).toDouble()
        : 0;
  }

  factory ReelClip.fromJson(Map<String, dynamic> json) => ReelClip(
    id: json['id'] as String? ?? newId(),
    path: json['path'] as String,
    name: json['name'] as String? ?? 'Media',
    isVideo: json['isVideo'] == true,
    sourceDuration: (json['sourceDuration'] as num?)?.toDouble() ?? 0,
    duration: (json['duration'] as num?)?.toDouble() ?? 3.5,
    trimStart: (json['trimStart'] as num?)?.toDouble() ?? 0,
    caption: json['caption'] as String? ?? '',
    post: FeedPost.fromJson(
      Map<String, dynamic>.from(json['post'] as Map? ?? {}),
    ),
    cardWidth: (json['cardWidth'] as num?)?.toDouble() ?? .78,
    cardHeight: (json['cardHeight'] as num?)?.toDouble() ?? 1,
    zoom: (json['zoom'] as num?)?.toDouble() ?? 1,
    panX: (json['panX'] as num?)?.toDouble() ?? 0,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'path': path,
    'name': name,
    'isVideo': isVideo,
    'sourceDuration': sourceDuration,
    'duration': duration,
    'trimStart': trimStart,
    'caption': caption,
    'post': post.toJson(),
    'cardWidth': cardWidth,
    'cardHeight': cardHeight,
    'zoom': zoom,
    'panX': panX,
  };
}

class FeaturedReview {
  String author, text;
  int rating;
  bool enabled;
  FeaturedReview({
    this.author = '',
    this.text = '',
    this.rating = 5,
    this.enabled = true,
  }) {
    rating = rating.clamp(1, 5);
  }
  bool get visible => enabled && text.trim().isNotEmpty;
  factory FeaturedReview.fromJson(Map<String, dynamic> j) => FeaturedReview(
    author: j['author'] as String? ?? '',
    text: j['text'] as String? ?? '',
    rating: (j['rating'] as num?)?.toInt() ?? 5,
    enabled: j['enabled'] != false,
  );
  Map<String, dynamic> toJson() => {
    'author': author,
    'text': text,
    'rating': rating,
    'enabled': enabled,
  };
}

class ReelProject {
  final String id;
  String title, storyBadge;
  final String template;
  FeedSettings feed;
  bool get isFeed => template == 'tiktok-feed';
  String? heroClipId;
  bool storyChrome, darkOutput;
  double slideSeconds, sheetIntroSeconds;
  String headerMode;
  String? mapHeaderPath;
  String mapSource;
  int mapZoom;
  FeaturedReview review;
  PlaceDetails place;
  final List<ReelClip> clips;
  final List<StoryTag> tags;
  MusicTrack? music;
  DateTime updatedAt;
  ReelProject({
    String? id,
    this.title = 'Untitled reel',
    this.template = 'maps-place',
    FeedSettings? feed,
    this.storyBadge = '',
    this.storyChrome = false,
    this.darkOutput = false,
    this.heroClipId,
    this.headerMode = 'map',
    this.mapHeaderPath,
    this.mapSource = 'upload',
    this.mapZoom = 15,
    double sheetIntroSeconds = .9,
    FeaturedReview? review,
    double slideSeconds = .42,
    PlaceDetails? place,
    List<ReelClip>? clips,
    List<StoryTag>? tags,
    this.music,
    DateTime? updatedAt,
  }) : feed = feed ?? FeedSettings(),
       sheetIntroSeconds = sheetIntroSeconds.isFinite
           ? sheetIntroSeconds.clamp(0, 2).toDouble()
           : .9,
       review = review ?? FeaturedReview(),
       slideSeconds = slideSeconds.isFinite
           ? slideSeconds.clamp(.15, .8).toDouble()
           : .42,
       id = id ?? newId(),
       place = place ?? PlaceDetails(),
       clips = clips ?? [],
       tags =
           tags ??
           [
             if (storyBadge.isNotEmpty)
               StoryTag(text: storyBadge, size: 11, x: .7, y: .3),
           ],
       updatedAt = updatedAt ?? DateTime.now();
  ReelClip? get heroClip {
    for (final clip in clips) {
      if (clip.id == heroClipId) return clip;
    }
    return clips.isEmpty ? null : clips.first;
  }

  double get duration => clips.fold(0, (sum, clip) => sum + clip.duration);
  int clipAt(double seconds) {
    var end = 0.0;
    for (var i = 0; i < clips.length; i++) {
      end += clips[i].duration;
      if (seconds < end) return i;
    }
    return clips.isEmpty ? -1 : clips.length - 1;
  }

  double startOf(int index) =>
      clips.take(index).fold(0, (sum, c) => sum + c.duration);
  factory ReelProject.fromJson(Map<String, dynamic> json) => ReelProject(
    id: json['id'] as String?,
    title: json['title'] as String? ?? 'My place reel',
    template: json['template'] == 'tiktok-feed' ? 'tiktok-feed' : 'maps-place',
    feed: FeedSettings.fromJson(
      Map<String, dynamic>.from(json['feed'] as Map? ?? {}),
    ),
    storyBadge: json['storyBadge'] as String? ?? '',
    tags:
        (json['tags'] as List?)
            ?.map((e) => StoryTag.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList() ??
        [
          if ((json['storyBadge'] as String? ?? '').isNotEmpty)
            StoryTag(
              text: json['storyBadge'] as String,
              size: 11,
              x: .7,
              y: .3,
            ),
        ],
    music: json['music'] == null
        ? null
        : MusicTrack.fromJson(Map<String, dynamic>.from(json['music'] as Map)),
    storyChrome: json['storyChrome'] == true,
    darkOutput: json['darkOutput'] == true,
    heroClipId: json['heroClipId'] as String?,
    headerMode: json['headerMode'] as String? ?? 'photo',
    mapHeaderPath: json['mapHeaderPath'] as String?,
    mapSource: json['mapSource'] as String? ?? 'upload',
    mapZoom: (json['mapZoom'] as num?)?.toInt() ?? 15,
    sheetIntroSeconds: (json['sheetIntroSeconds'] as num?)?.toDouble() ?? 0,
    review: FeaturedReview.fromJson(
      Map<String, dynamic>.from(json['review'] as Map? ?? {}),
    ),
    slideSeconds: (json['slideSeconds'] as num?)?.toDouble() ?? .42,
    place: PlaceDetails.fromJson(
      Map<String, dynamic>.from(json['place'] as Map? ?? {}),
    ),
    clips: (json['clips'] as List? ?? [])
        .map((e) => ReelClip.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
  );
  Map<String, dynamic> toJson() => {
    'version': 2,
    'id': id,
    'title': title,
    'storyBadge': storyBadge,
    'tags': tags.map((t) => t.toJson()).toList(),
    'music': music?.toJson(),
    'storyChrome': storyChrome,
    'darkOutput': darkOutput,
    'heroClipId': heroClipId,
    'headerMode': headerMode,
    'mapHeaderPath': mapHeaderPath,
    'mapSource': mapSource,
    'mapZoom': mapZoom,
    'sheetIntroSeconds': sheetIntroSeconds,
    'review': review.toJson(),
    'slideSeconds': slideSeconds,
    'template': template,
    'feed': feed.toJson(),
    'place': place.toJson(),
    'clips': clips.map((e) => e.toJson()).toList(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}
