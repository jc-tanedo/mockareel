import 'dart:convert';
import 'package:mockareel/model/place_details.dart';
import 'package:mockareel/model/reel_clip.dart';
import 'package:mockareel/model/streetview_data.dart';
import 'orbit_location.dart';

extension OrbitClipAssignment on OrbitLocation {
  void assign(ReelClip clip) {
    final media = clip.streetview;
    if (media.locationId != id &&
        (media.place.latitude != place.latitude ||
            media.place.longitude != place.longitude ||
            media.mapPath != mapPath)) {
      media.wallId = null;
      media.visitedWalls.clear();
    }
    clip.streetview
      ..locationId = id
      ..locationSelected = true
      ..locationOrigin = ''
      ..place = PlaceDetails.fromJson(place.toJson())
      ..mapPath = mapPath;
  }
}

extension OrbitClipLocations on StreetviewSettings {
  OrbitLocation? locationFor(ReelClip clip) =>
      locations.where((l) => l.id == clip.streetview.locationId).firstOrNull;

  // Old reels stored places only on clips. Preserve their order and overrides.
  bool adoptClipLocations(List<ReelClip> clips) {
    final known = {for (final location in locations) location.id: location};
    String signature(PlaceDetails place, String? path) =>
        jsonEncode([path, place.toJson()]);
    var changed = false;
    // A legacy capture can live on either side of the clip/location link.
    for (final clip in clips) {
      final media = clip.streetview;
      final linked = known[media.locationId];
      if (linked != null && linked.mapPath == null && media.mapPath != null) {
        linked.mapPath = media.mapPath;
        changed = true;
      }
    }
    final byPlace = {
      for (final location in locations)
        signature(location.place, location.mapPath): location,
    };
    for (final clip in clips) {
      final media = clip.streetview;
      if (known.containsKey(media.locationId)) continue;
      final place = media.place;
      if (!media.canCaptureMap &&
          media.mapPath == null &&
          place.name.isEmpty &&
          place.address.isEmpty &&
          place.latitude == null) {
        continue;
      }
      final key = signature(place, media.mapPath);
      final location = byPlace.putIfAbsent(key, () {
        final added = OrbitLocation(
          place: PlaceDetails.fromJson(place.toJson()),
          mapPath: media.mapPath,
        );
        locations.add(added);
        known[added.id] = added;
        return added;
      });
      media.locationId = location.id;
      changed = true;
    }
    for (final clip in clips) {
      final media = clip.streetview;
      final path = known[media.locationId]?.mapPath;
      if (media.mapPath == null && path != null) {
        media.mapPath = path;
        changed = true;
      }
    }
    return changed;
  }

  int addClipsAt(
    OrbitLocation location,
    List<ReelClip> clips,
    List<ReelClip> added,
  ) {
    final last = clips.lastIndexWhere(
      (c) => c.streetview.locationId == location.id,
    );
    var insertAt = last + 1;
    if (last < 0) {
      final later = locations
          .skip(locations.indexOf(location) + 1)
          .map((l) => l.id)
          .toSet();
      insertAt = clips.indexWhere(
        (c) => later.contains(c.streetview.locationId),
      );
      if (insertAt < 0) insertAt = clips.length;
    }
    for (final clip in added) {
      location.assign(clip);
    }
    clips.insertAll(insertAt, added);
    return insertAt;
  }
}
