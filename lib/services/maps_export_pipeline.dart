import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:share_plus/share_plus.dart';
import '../model/orbit_scene.dart';
import '../model/orbit_media_pose.dart';
import '../model/project.dart';
import '../model/streetview_motion.dart';
import '../model/streetview_timeline.dart';
import 'export_maps.dart';
import '../services/native_renderer.dart';
import '../services/project_store.dart';
import '../widgets/export_monitor.dart';

class MapsExportPipeline {
  final ReelProject project;
  final ProjectStore store;
  final NativeRenderer renderer;
  final Future<void> Function(String path) onPrecache;
  final Future<Uint8List> Function() onCapturePng;
  final void Function(String status) onStatus;
  final void Function(double? progress) onProgress;
  final void Function(ExportPhase phase) onPhase;
  final void Function(double position) onPosition;
  final void Function(int index) onCaptureIndex;
  final void Function(double? position) onCapturePosition;
  final void Function(bool snapshot) onCaptureSnapshot;
  final void Function(Map<String, String> posters) onCapturePosters;
  final void Function(String? heroPath) onCaptureHeroPath;
  final bool Function() isCancelled;

  const MapsExportPipeline({
    required this.project,
    required this.store,
    required this.renderer,
    required this.onPrecache,
    required this.onCapturePng,
    required this.onStatus,
    required this.onProgress,
    required this.onPhase,
    required this.onPosition,
    required this.onCaptureIndex,
    required this.onCapturePosition,
    required this.onCaptureSnapshot,
    required this.onCapturePosters,
    required this.onCaptureHeroPath,
    required this.isCancelled,
  });

  Future<Map<String, String>> prepareCapture({bool snapshot = false}) async {
    final missingClip = project.firstMissingMapClip;
    if (missingClip != null) {
      throw FormatException(
        '${project.isStreetview3d ? 'Fetch 3D geometry' : 'Capture a map'} for clip ${missingClip + 1} (“${project.clips[missingClip].name}”) before exporting.',
      );
    }
    if (project.needsMapHeader) {
      throw const FormatException(
        'Load a Google map or upload a map image in Place before exporting.',
      );
    }
    final hero = project.headerMode == 'photo' ? project.heroClip : null;
    String? heroPath = project.headerMode == 'map'
        ? project.mapHeaderPath
        : null;
    if (heroPath != null) await onPrecache(heroPath);
    if (hero != null) {
      heroPath = await renderer.poster(hero);
      await onPrecache(heroPath);
    }
    final paths = <String, String>{};
    if (snapshot) {
      for (final c in project.clips) {
        if (isCancelled()) throw const FormatException('Export cancelled');
        paths[c.id] = await renderer.poster(c);
        await onPrecache(paths[c.id]!);
        if (project.isStreetview) {
          paths['${c.id}:end'] = await renderer.poster(
            c,
            position: c.duration - .001,
          );
          await onPrecache(paths['${c.id}:end']!);
          if (project.isStreetview3d) {
            if (c.streetview.mapPath != null) {
              await (await OrbitScene.load(c.streetview.mapPath!)).warmAtlas();
            }
            if (c.streetview.walking && !c.isTimed) {
              for (final layer in c.streetview.walkLayers) {
                await onPrecache(layer);
              }
            }
          } else if (c.streetview.mapPath != null) {
            await onPrecache(c.streetview.mapPath!);
          }
        }
      }
    }
    onCaptureHeroPath(heroPath);
    onCaptureSnapshot(snapshot);
    onCapturePosters(paths);
    return paths;
  }

  Future<void> runExportPng({
    required bool snapshot,
    required int selectedIndex,
  }) async {
    await prepareCapture(snapshot: snapshot);
    if (isCancelled()) throw const FormatException('Export cancelled');
    onCaptureIndex(selectedIndex);
    final bytes = await onCapturePng();
    final kind = snapshot ? 'snapshot' : 'template';
    final file = File('${store.root!.path}/exports/$kind-${newId()}.png');
    await file.writeAsBytes(bytes);
    if (isCancelled()) return;
    final subjectLabel = snapshot ? 'snapshot' : 'transparent template';
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'image/png')],
        subject: '${project.title} — $subjectLabel',
      ),
    );
  }

  Future<String> runExport() async {
    for (final clip in project.clips) {
      if (!await File(clip.path).exists()) {
        throw Exception(
          '“${clip.name}” is missing. Remove or replace that clip.',
        );
      }
    }

    Directory? temp;
    StreamSubscription<double>? progressSubscription;
    try {
      temp = await Directory(
        '${store.root!.path}/exports/overlay_${newId()}',
      ).create();

      final posters = await prepareCapture(snapshot: true);
      if (isCancelled()) throw const FormatException('Export cancelled');
      onCaptureSnapshot(false);

      if (project.isStreetview) {
        return await _exportStreetview(temp, posters);
      }

      final overlays = <String>[];
      for (var i = 0; i < project.clips.length; i++) {
        if (isCancelled()) throw const FormatException('Export cancelled');
        onCaptureIndex(i);
        onPosition(project.startOf(i));
        onStatus('Preparing clip ${i + 1} of ${project.clips.length}…');
        onProgress(.15 * i / project.clips.length);

        final data = await onCapturePng();
        final file = File('${temp.path}/$i.png');
        await file.writeAsBytes(data);
        overlays.add(file.path);
      }

      final introFrames = <String>[];
      final maxFrame = (min(project.sheetIntroSeconds, project.duration) * 30)
          .ceil();
      for (var frame = 0; frame < maxFrame; frame++) {
        if (isCancelled()) throw const FormatException('Export cancelled');
        final position = frame / 30;
        onCapturePosition(position);
        onPosition(position);
        onStatus('Preparing opening animation…');
        onProgress(.15 + .20 * frame / max(1, maxFrame));
        onCaptureIndex(max(0, project.clipAt(position)));

        final file = File('${temp.path}/intro_$frame.png');
        await file.writeAsBytes(await onCapturePng());
        introFrames.add(file.path);
      }

      onCapturePosition(null);
      onPhase(ExportPhase.encoding);
      onPosition(0);
      onProgress(.35);
      onStatus('Encoding video…');

      if (isCancelled()) throw const FormatException('Export cancelled');

      progressSubscription = renderer.progress.listen((value) {
        onProgress(.35 + .65 * value);
        onPosition(project.duration * value.clamp(0, 1));
        onStatus('Encoding video…');
      });

      final path = await renderer.export(
        project,
        overlays,
        introFrames: introFrames,
      );

      if (isCancelled()) throw const FormatException('Export cancelled');
      return path;
    } finally {
      await progressSubscription?.cancel();
      if (temp != null && await temp.exists()) {
        await temp.delete(recursive: true);
      }
    }
  }

  Future<String> _exportStreetview(
    Directory temp,
    Map<String, String> posters,
  ) async {
    StreamSubscription<double>? progressSubscription;
    try {
      final scenes = StreetviewTimeline.scenes(project);
      final clips = <Map<String, dynamic>>[];
      final overlays = <String>[];
      final frames = <List<String>>[];

      for (var i = 0; i < scenes.length; i++) {
        final scene = scenes[i];
        final clip = project.clips[scene.mediaIndex];
        // Whole-project precaching can evict early assets on longer reels.
        // Decode this scene's actual pixels immediately before its first paint;
        // otherwise a resolved Image.file can still capture a transparent frame.
        OrbitScene? geometry;
        if (project.isStreetview3d && clip.streetview.mapPath != null) {
          geometry = await OrbitScene.load(clip.streetview.mapPath!);
          await geometry.warmAtlas();
          final nextPath =
              (scene.kind == 'arrow' || scene.kind == 'back') &&
                  scene.mediaIndex + 1 < project.clips.length
              ? project.clips[scene.mediaIndex + 1].streetview.mapPath
              : null;
          if (nextPath != null) {
            await (await OrbitScene.load(nextPath)).warmAtlas();
          }
        }
        final nextMap =
            project.isStreetview3d &&
                scene.kind == 'back' &&
                scene.mediaIndex + 1 < project.clips.length
            ? project.clips[scene.mediaIndex + 1]
            : clip;
        final overview = project.streetview.locationFor(nextMap)?.overviewPath;
        final assets = <String>{
          if (overview != null &&
              (scene.kind == 'map' ||
                  scene.kind == 'ending-map' ||
                  scene.kind == 'back'))
            overview,
          if (project.isStreetview3d &&
              !clip.isTimed &&
              clip.streetview.walking)
            ...clip.streetview.walkLayers,
          if (project.isStreetview3d &&
              scene.kind == 'arrow' &&
              project.clips[scene.mediaIndex + 1].streetview.walking)
            ...project.clips[scene.mediaIndex + 1].streetview.walkLayers,
          if (scene.kind == 'map' ||
              (project.isStreetview3d &&
                  scene.kind == 'media' &&
                  !clip.isTimed))
            posters[clip.id]!,
          if (scene.kind == 'ending-map' ||
              scene.kind == 'back' ||
              scene.kind == 'arrow')
            posters['${clip.id}:end']!,
          if (scene.kind == 'arrow' || nextMap != clip)
            posters[project.clips[scene.mediaIndex + 1].id]!,
          if ((scene.kind == 'map' ||
                  scene.kind == 'ending-map' ||
                  scene.kind == 'back') &&
              !project.isStreetview3d &&
              clip.streetview.mapPath != null)
            clip.streetview.mapPath!,
        };
        for (final asset in assets) {
          if (isCancelled()) throw const FormatException('Export cancelled');
          await onPrecache(asset);
        }
        final media = scene.kind == 'media';
        final animatedArrows =
            media &&
            clip.streetview.showArrows &&
            StreetviewMotion.active(clip);
        final staticOverlay =
            media && !animatedArrows && !project.isStreetview3d;
        final count = staticOverlay ? 1 : (scene.duration * 30).ceil();
        final paths = <String>[];

        for (var f = 0; f < count; f++) {
          if (isCancelled()) throw const FormatException('Export cancelled');
          final capturePos = scene.start + f / 30;
          onCaptureSnapshot(false);
          onCapturePosition(capturePos);
          onPosition(capturePos);
          onProgress(.35 * (i + f / count) / scenes.length);
          onStatus('Preparing journey scene ${i + 1} of ${scenes.length}…');

          final file = File('${temp.path}/streetview-$i-$f.png');
          await file.writeAsBytes(await onCapturePng());
          paths.add(file.path);
        }

        overlays.add(paths.last);
        frames.add(staticOverlay ? [] : paths);
        clips.add(
          media
              ? {
                  ...clip.toJson(),
                  'slowPanZoom': clip.streetview.panZoom,
                  'cameraMotion': StreetviewMotion.native(clip),
                  if (project.isStreetview3d && clip.isTimed)
                    'orbitPlaneFrames': [
                      for (int f = 0; f < count; f++)
                        OrbitMediaPose.at(
                          'media',
                          (f / 30) / scene.duration,
                          scene: geometry,
                        ).native,
                    ],
                }
              : {
                  ...clip.toJson(),
                  'path': paths.first,
                  'edits': <String, dynamic>{},
                  'isVideo': false,
                  'isGif': false,
                  'duration': scene.duration,
                  'trimStart': 0.0,
                  'zoom': 1.0,
                  'panX': 0.0,
                },
        );
      }

      if (isCancelled()) throw const FormatException('Export cancelled');

      onPhase(ExportPhase.encoding);
      onStatus('Encoding video…');
      onPosition(0);
      onCapturePosition(null);

      progressSubscription = renderer.progress.listen((v) {
        onProgress(.35 + .65 * v);
        onPosition(project.duration * v);
      });

      final path = await renderer.exportFeed(
        clips: clips,
        overlays: overlays,
        frames: frames,
        transitions: List.filled(clips.length, 0),
        music: project.music,
      );

      if (isCancelled()) throw const FormatException('Export cancelled');
      return path;
    } finally {
      await progressSubscription?.cancel();
    }
  }
}
