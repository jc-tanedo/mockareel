import 'dart:io';

import '../model/project.dart';
import '../model/streetview_timeline.dart';

extension ExportMaps on ReelProject {
  bool get needsMapHeader =>
      !isStreetview && headerMode == 'map' && mapHeaderPath == null;

  int? get firstMissingMapClip {
    if (!isStreetview) return null;
    final indices = isStreetview3d
        ? Iterable<int>.generate(clips.length)
        : StreetviewTimeline.scenes(this)
              .where((s) => s.kind == 'map' || s.kind == 'ending-map')
              .map((s) => s.mediaIndex);
    final checkedPaths = <String>{};
    for (final index in indices) {
      final path = clips[index].streetview.mapPath;
      if (path == null ||
          (checkedPaths.add(path) && !File(path).existsSync())) {
        return index;
      }
    }
    return null;
  }
}
