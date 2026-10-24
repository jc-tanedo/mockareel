import 'dart:math';
import 'ids.dart';
import 'feed_post.dart';

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
