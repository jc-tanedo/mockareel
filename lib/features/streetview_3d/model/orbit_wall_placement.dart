import 'dart:math';
import 'package:mockareel/model/reel_clip.dart';
import 'package:mockareel/model/streetview_data.dart';
import 'orbit_dolly.dart';
import 'orbit_scene.dart';

class OrbitWallPlacement {
  final Random _random;
  OrbitWallPlacement([Random? random]) : _random = random ?? Random();

  static bool samePin(StreetviewMedia a, StreetviewMedia b) {
    final pins = OrbitDolly.pinOffset(a.place, b.place);
    final sameCoords = pins != null && pins.distance < 1;
    return (a.locationId != null && a.locationId == b.locationId) ||
        sameCoords ||
        (a.mapPath != null && a.mapPath == b.mapPath && pins == null);
  }

  bool ensureDistinct(List<ReelClip> clips, Map<String, OrbitScene> scenes) {
    var changed = false;
    for (final clip in clips) {
      final path = clip.streetview.mapPath;
      if (path == null) continue;
      final scene = scenes[path];
      if (scene == null) continue;
      changed = choose(clip, clips, scene) || changed;
    }
    return changed;
  }

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
    final index = clips.indexOf(clip);
    final used = <String?>{
      for (final sibling in clips)
        if (sibling != clip && samePin(media, sibling.streetview))
          sibling.streetview.wallId,
    };
    final prevSamePinWall =
        index > 0 && samePin(clips[index - 1].streetview, media)
        ? clips[index - 1].streetview.wallId
        : null;
    final nextSamePinWall =
        index >= 0 &&
            index + 1 < clips.length &&
            samePin(clips[index + 1].streetview, media)
        ? clips[index + 1].streetview.wallId
        : null;
    final adjacent = <String?>{
      if (prevSamePinWall != null) prevSamePinWall,
      if (nextSamePinWall != null) nextSamePinWall,
    };
    final earlierSamePinUsed = <String?>{
      if (index > 0)
        for (final sibling in clips.take(index))
          if (samePin(sibling.streetview, media) &&
              sibling.streetview.wallId != null)
            sibling.streetview.wallId,
    };
    final freeAll = walls.keys.where((id) => !used.contains(id)).toList();
    bool collides(String? id) {
      if (id == null || walls.length < 2) return false;
      if (prevSamePinWall == id) return true;
      if (earlierSamePinUsed.contains(id) && freeAll.isNotEmpty) return true;
      return false;
    }

    if (!shuffle && current != null && !walls.containsKey(current)) {
      final replacement = scene.matchingWall(current);
      if (replacement != null && !collides(replacement)) {
        media.wallId = replacement;
        media.visitedWalls = {
          ...media.visitedWalls.where(walls.containsKey),
          replacement,
        }.toList();
        return true;
      }
    }
    if (walls.containsKey(current) &&
        ((!shuffle && !collides(current)) || walls.length == 1)) {
      return false;
    }
    Set<String> history;
    List<String> pool;
    if (shuffle) {
      final shuffleSpace = freeAll.length >= 2 ? freeAll : walls.keys.toList();
      history = media.visitedWalls.where(shuffleSpace.contains).toSet();
      if (current != null && shuffleSpace.contains(current)) {
        history.add(current);
      }
      pool = shuffleSpace.where((id) => !history.contains(id)).toList();
      if (pool.isEmpty) {
        history.clear();
        pool = shuffleSpace
            .where((id) => id != current || shuffleSpace.length == 1)
            .toList();
      }
      if (shuffleSpace.length == walls.length && pool.length > 1) {
        final freeInPool = pool.where((id) => !used.contains(id)).toList();
        if (freeInPool.isNotEmpty) {
          pool = freeInPool;
        } else {
          final nonAdj = pool.where((id) => !adjacent.contains(id)).toList();
          if (nonAdj.isNotEmpty) pool = nonAdj;
        }
      }
    } else {
      history = media.visitedWalls.where(walls.containsKey).toSet();
      if (walls.containsKey(current)) history.add(current!);
      pool = walls.keys.where((id) => !history.contains(id)).toList();
      if (pool.isEmpty) {
        history.clear();
        pool = walls.keys
            .where((id) => id != current || walls.length == 1)
            .toList();
      }
      final free = pool.where((id) => !used.contains(id)).toList();
      if (free.isNotEmpty) {
        pool = free;
      } else if (freeAll.isNotEmpty) {
        pool = List.of(freeAll);
      } else {
        final nonAdj = pool.where((id) => !adjacent.contains(id)).toList();
        if (nonAdj.isNotEmpty) {
          pool = nonAdj;
        } else if (walls.length > 1) {
          final anyNonAdj = walls.keys
              .where((id) => !adjacent.contains(id))
              .toList();
          if (anyNonAdj.isNotEmpty) {
            history.clear();
            pool = anyNonAdj;
          }
        }
      }
      if (pool.length > 1) {
        final neighborId =
            prevSamePinWall != null && walls.containsKey(prevSamePinWall)
            ? prevSamePinWall
            : nextSamePinWall != null && walls.containsKey(nextSamePinWall)
            ? nextSamePinWall
            : null;
        final neighbor = neighborId == null ? null : walls[neighborId];
        if (neighbor != null) {
          final nearby = pool
              .where(
                (id) => (walls[id]!.center - neighbor.center).distance <= 65,
              )
              .toList();
          if (nearby.isEmpty) {
            pool = List.of(pool)
              ..sort(
                (a, b) => (walls[a]!.center - neighbor.center).distanceSquared
                    .compareTo(
                      (walls[b]!.center - neighbor.center).distanceSquared,
                    ),
              );
            if (pool.length > 6) pool = pool.sublist(0, 6);
          } else {
            final angled = nearby.where((id) {
              final n = walls[id]!.normal;
              return n.dx * neighbor.normal.dx + n.dy * neighbor.normal.dy >
                  -0.85;
            }).toList();
            final curated = angled.isNotEmpty ? angled : nearby;
            curated.sort(
              (a, b) => (walls[a]!.center - neighbor.center).distanceSquared
                  .compareTo(
                    (walls[b]!.center - neighbor.center).distanceSquared,
                  ),
            );
            pool = curated.length > 6 ? curated.sublist(0, 6) : curated;
          }
        }
      }
    }
    final selected = pool[_random.nextInt(pool.length)];
    media.wallId = selected;
    media.visitedWalls = [...history, selected];
    return true;
  }
}
