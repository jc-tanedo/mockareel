import 'ids.dart';

double _bounded(dynamic value, double fallback, double low, double high) =>
    value is num && value.toDouble().isFinite
    ? value.toDouble().clamp(low, high)
    : fallback;

class BlurSpot {
  final String id;
  double x, y, radius;
  BlurSpot({String? id, this.x = .5, this.y = .5, this.radius = .1})
    : id = id ?? newId();
  factory BlurSpot.fromJson(Map<String, dynamic> j) => BlurSpot(
    id: j['id'] as String?,
    x: _bounded(j['x'], .5, 0, 1),
    y: _bounded(j['y'], .5, 0, 1),
    radius: _bounded(j['radius'], .1, .025, .3),
  );
  Map<String, dynamic> toJson() => {'id': id, 'x': x, 'y': y, 'radius': radius};
}

/// Source-space edits, applied before any template crop, motion or UI.
class MediaEdits {
  static const maxSpots = 8;
  bool fisheye;
  String lens;
  double strength;
  final List<BlurSpot> spots;
  MediaEdits({
    this.fisheye = false,
    this.lens = 'fisheye',
    this.strength = .35,
    List<BlurSpot>? spots,
  }) : spots = spots ?? [];
  MediaEdits forMedia({required bool photo}) => photo
      ? this
      : MediaEdits(fisheye: fisheye, lens: lens, strength: strength);
  bool get active => (fisheye && strength > 0) || spots.isNotEmpty;
  factory MediaEdits.fromJson(Map<String, dynamic> j) => MediaEdits(
    fisheye: j['fisheye'] == true,
    lens: j['lens'] == 'pincushion' ? 'pincushion' : 'fisheye',
    strength: _bounded(j['strength'], .35, 0, 1),
    spots: (j['spots'] as List? ?? [])
        .take(maxSpots)
        .map((s) => BlurSpot.fromJson(Map<String, dynamic>.from(s as Map)))
        .toList(),
  );
  Map<String, dynamic> toJson() => {
    'fisheye': fisheye,
    'lens': lens,
    'strength': strength,
    'spots': spots.map((s) => s.toJson()).toList(),
  };
}
