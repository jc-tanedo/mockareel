import 'package:mockareel/model/place_details.dart';
import 'package:mockareel/model/reel_clip.dart';
import 'package:mockareel/model/streetview_data.dart';

abstract final class OrbitLocationDefaults {
  static bool _hasPlace(StreetviewMedia s) =>
      s.canCaptureMap ||
      s.mapPath != null ||
      s.place.latitude != null ||
      s.place.longitude != null ||
      s.place.name.isNotEmpty ||
      s.place.address.isNotEmpty;

  /// Read only the retained original. Check all originals before inheriting
  /// pins so a tagged item later in a multi-selection keeps its own location.
  static Future<bool> read(
    List<ReelClip> clips,
    Future<List<double>?> Function(ReelClip) coordinates,
  ) async {
    var changed = false;
    for (final clip in clips) {
      final s = clip.streetview;
      if (_hasPlace(s)) continue;
      final gps = await coordinates(clip);
      if (gps == null ||
          gps.length != 2 ||
          !gps.every((v) => v.isFinite) ||
          gps[0].abs() > 90 ||
          gps[1].abs() > 180) {
        continue;
      }
      s.place = PlaceDetails(latitude: gps[0], longitude: gps[1]);
      s.locationSelected = true;
      s.locationOrigin = 'media';
      changed = true;
    }
    return changed;
  }

  /// A captured map is immutable, so clips can share the asset while keeping
  /// independent place objects. A later capture can fill an inherited empty map.
  static bool inherit(List<ReelClip> clips) {
    bool changed = false;
    for (int i = 1; i < clips.length; i++) {
      final previous = clips[i - 1].streetview, current = clips[i].streetview;
      if (!_hasPlace(previous)) continue;
      if (!_hasPlace(current)) {
        current.place = PlaceDetails.fromJson(previous.place.toJson());
        current.locationSelected =
            previous.canCaptureMap || previous.place.latitude != null;
        current.locationOrigin = 'previous';
        current.locationId = previous.locationId;
        current.mapPath = previous.mapPath;
        changed = true;
      } else if (current.locationId == null &&
          current.mapPath == null &&
          previous.mapPath != null &&
          current.place.latitude != null &&
          current.place.longitude != null &&
          current.place.latitude == previous.place.latitude &&
          current.place.longitude == previous.place.longitude) {
        current.mapPath = previous.mapPath;
        changed = true;
      }
    }
    return changed;
  }
}
