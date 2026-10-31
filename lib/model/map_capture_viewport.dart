import 'dart:ui';

/// CSS pixels. Extra map area keeps edge controls outside the saved viewport.
class MapCaptureViewport {
  static const contentWidth = 1440.0;
  static const padding = 240.0;
  final double aspectRatio;
  const MapCaptureViewport(this.aspectRatio);
  Size get content => Size(contentWidth, contentWidth / aspectRatio);
  Size get browser =>
      Size(content.width + padding * 2, content.height + padding * 2);
  Rect get crop => const Offset(padding, padding) & content;
  Map<String, double> toJson() => {
    'left': crop.left,
    'top': crop.top,
    'width': crop.width,
    'height': crop.height,
  };
}
