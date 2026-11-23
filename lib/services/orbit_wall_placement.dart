import 'dart:math';
import '../model/orbit_scene.dart';
import '../model/project.dart';

class OrbitWallPlacement {
  final Random _random;
  OrbitWallPlacement([Random? random]) : _random = random ?? Random();

  bool choose(
    ReelClip clip,
    List<ReelClip> clips,
    OrbitScene scene, {
    bool shuffle = false,
  }) {
    final media = clip.streetview;
    final walls = scene.walls;
    final current = media.wallId;
    if (walls.isEmpty) {
      if (current == null && media.visitedWalls.isEmpty) return false;
      media.wallId = null;
      media.visitedWalls.clear();
      return true;
    }
    if (!shuffle && current != null && !walls.containsKey(current)) {
      final replacement = scene.matchingWall(current);
      if (replacement != null) {
        media.wallId = replacement;
        media.visitedWalls = {
          ...media.visitedWalls.where(walls.containsKey),
          replacement,
        }.toList();
        return true;
      }
    }
    if (walls.containsKey(current) && (!shuffle || walls.length == 1)) {
      return false;
    }
    final history = media.visitedWalls.where(walls.containsKey).toSet();
    if (walls.containsKey(current)) history.add(current!);
    var pool = walls.keys.where((id) => !history.contains(id)).toList();
    if (pool.isEmpty) {
      history.clear();
      pool = walls.keys
          .where((id) => id != current || walls.length == 1)
          .toList();
    }
    if (!shuffle) {
      final used = <String?>{
        for (final sibling in clips)
          if (sibling != clip && _samePin(media, sibling.streetview))
            sibling.streetview.wallId,
      };
      final free = pool.where((id) => !used.contains(id)).toList();
      if (free.isNotEmpty) pool = free;
    }
    final selected = pool[_random.nextInt(pool.length)];
    media.wallId = selected;
    media.visitedWalls = [...history, selected];
    return true;
  }

  bool _samePin(StreetviewMedia a, StreetviewMedia b) =>
      (a.locationId != null && a.locationId == b.locationId) ||
      (a.place.latitude != null &&
          a.place.longitude != null &&
          a.place.latitude == b.place.latitude &&
          a.place.longitude == b.place.longitude) ||
      (a.mapPath != null && a.mapPath == b.mapPath);
}
