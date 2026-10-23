import 'dart:math';

String newId() =>
    '${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(1 << 30)}';

class PlaceDetails {
  String name, category, rating, address;
  String? placeId;
  PlaceDetails(
      {this.name = '',
      this.category = '',
      this.rating = '',
      this.address = '',
      this.placeId});
  factory PlaceDetails.fromJson(Map<String, dynamic> json) => PlaceDetails(
      name: json['name'] as String? ?? '',
      category: (json['category'] ?? json['subtitle']) as String? ?? '',
      rating: json['rating']?.toString() ?? '',
      address: json['address'] as String? ?? '',
      placeId: json['placeId'] as String?);
  Map<String, dynamic> toJson() => {
        'name': name,
        'category': category,
        'rating': rating,
        'address': address,
        'placeId': placeId
      };
}

class ReelClip {
  final String id, path, name;
  final bool isVideo;
  final double sourceDuration;
  double duration, trimStart;
  String caption;
  ReelClip(
      {required this.id,
      required this.path,
      required this.name,
      required this.isVideo,
      this.sourceDuration = 0,
      this.duration = 3.5,
      this.trimStart = 0,
      this.caption = ''}) {
    normalize();
  }
  double get maxDuration =>
      isVideo && sourceDuration > 0 ? min(30, sourceDuration) : 30;
  void normalize() {
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
      caption: json['caption'] as String? ?? '');
  Map<String, dynamic> toJson() => {
        'id': id,
        'path': path,
        'name': name,
        'isVideo': isVideo,
        'sourceDuration': sourceDuration,
        'duration': duration,
        'trimStart': trimStart,
        'caption': caption
      };
}

class ReelProject {
  final String id;
  String title;
  PlaceDetails place;
  final List<ReelClip> clips;
  DateTime updatedAt;
  ReelProject(
      {String? id,
      this.title = 'Untitled reel',
      PlaceDetails? place,
      List<ReelClip>? clips,
      DateTime? updatedAt})
      : id = id ?? newId(),
        place = place ?? PlaceDetails(),
        clips = clips ?? [],
        updatedAt = updatedAt ?? DateTime.now();
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
      place: PlaceDetails.fromJson(
          Map<String, dynamic>.from(json['place'] as Map? ?? {})),
      clips: (json['clips'] as List? ?? [])
          .map((e) => ReelClip.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''));
  Map<String, dynamic> toJson() => {
        'version': 2,
        'id': id,
        'title': title,
        'template': 'maps-place',
        'place': place.toJson(),
        'clips': clips.map((e) => e.toJson()).toList(),
        'updatedAt': updatedAt.toIso8601String()
      };
}
