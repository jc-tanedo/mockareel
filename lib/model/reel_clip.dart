import 'dart:math';
import 'ids.dart';
import 'feed_post.dart';
import 'streetview.dart';
import 'media_edits.dart';
export 'media_edits.dart';

class ReelClip {
  final String id, path, name;
  final bool isVideo;
  double sourceDuration;
  bool isGif, loopGif;
  double duration, trimStart, cardWidth, cardHeight, zoom, panX;
  String caption;
  FeedPost post;
  StreetviewMedia streetview;
  MediaEdits edits;
  ReelClip({
    required this.id,
    required this.path,
    required this.name,
    required this.isVideo,
    this.sourceDuration = 0,
    this.isGif = false,
    this.loopGif = true,
    this.duration = 3.5,
    this.trimStart = 0,
    this.caption = '',
    FeedPost? post,
    StreetviewMedia? streetview,
    MediaEdits? edits,
    this.cardWidth = .78,
    this.cardHeight = 1,
    this.zoom = 1,
    this.panX = 0,
  }) : edits = edits ?? MediaEdits(),
       streetview = streetview ?? StreetviewMedia(),
       post = post ?? FeedPost() {
    normalize();
  }
  bool get supportsBlur => !isTimed;
  MediaEdits get effectiveEdits => edits.forMedia(photo: supportsBlur);
  bool get isTimed => isVideo || isGif;
  double get maxDuration => isTimed && !(isGif && loopGif) && sourceDuration > 0
      ? min(30, sourceDuration)
      : 30;
  double get maxTrimStart => !isTimed || sourceDuration <= 0
      ? 0
      : isGif && loopGif
      ? max(0, sourceDuration - .001)
      : max(0, sourceDuration - duration);
  double get minDuration => min(isGif ? 1 / 30 : .5, maxDuration);
  void setGifLoop(bool value) {
    if (isGif && !value && sourceDuration > 0) {
      duration = min(duration, max(minDuration, sourceDuration - trimStart));
    }
    loopGif = value;
    normalize();
  }

  void normalize() {
    cardWidth = cardWidth.isFinite ? cardWidth.clamp(.45, 1).toDouble() : .78;
    cardHeight = cardHeight.isFinite ? cardHeight.clamp(.55, 1).toDouble() : 1;
    zoom = zoom.isFinite ? zoom.clamp(1, 3).toDouble() : 1;
    panX = panX.isFinite ? panX.clamp(-1, 1).toDouble() : 0;
    final max = maxDuration;
    duration = duration.isFinite
        ? duration.clamp(minDuration, max).toDouble()
        : min(3.5, max);
    trimStart = isTimed && sourceDuration > 0 && trimStart.isFinite
        ? trimStart.clamp(0, maxTrimStart).toDouble()
        : 0;
  }

  factory ReelClip.fromJson(Map<String, dynamic> json) => ReelClip(
    id: json['id'] as String? ?? newId(),
    path: json['path'] as String,
    name: json['name'] as String? ?? 'Media',
    isVideo: json['isVideo'] == true,
    sourceDuration: (json['sourceDuration'] as num?)?.toDouble() ?? 0,
    isGif: json['isGif'] == true,
    loopGif: json['loopGif'] != false,
    duration: (json['duration'] as num?)?.toDouble() ?? 3.5,
    trimStart: (json['trimStart'] as num?)?.toDouble() ?? 0,
    caption: json['caption'] as String? ?? '',
    edits: MediaEdits.fromJson(
      Map<String, dynamic>.from(json['edits'] as Map? ?? {}),
    ),
    streetview: StreetviewMedia.fromJson(
      Map<String, dynamic>.from(json['streetview'] as Map? ?? {}),
    ),
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
    'isGif': isGif,
    'loopGif': loopGif,
    'duration': duration,
    'trimStart': trimStart,
    'caption': caption,
    'post': post.toJson(),
    'streetview': streetview.toJson(),
    'edits': edits.toJson(),
    'cardWidth': cardWidth,
    'cardHeight': cardHeight,
    'zoom': zoom,
    'panX': panX,
  };
}
