import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:share_plus/share_plus.dart';
import '../features/streetview_3d/data/orbit_scene_loader.dart';
import '../features/streetview_3d/model/orbit_media_pose.dart';
import '../features/streetview_3d/model/orbit_scene.dart';
import '../model/export_phase.dart';
import '../model/m3_motion.dart';
import '../model/project.dart';
import '../model/streetview_motion.dart';
import '../model/streetview_timeline.dart';
import '../model/template_layout.dart';
import 'export_maps.dart';
import 'native_renderer.dart';
import 'project_store.dart';
import 'streetview_capture_plan.dart';

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
              await OrbitSceneLoader.loadForExport(c.streetview.mapPath!);
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
        onProgress(.10 * i / project.clips.length);

        final data = await onCapturePng();
        final file = File('${temp.path}/$i.png');
        await file.writeAsBytes(data);
        overlays.add(file.path);
      }

      final introFrames = <String>[];
      final maxFrame =
          (min(project.sheetIntroSeconds, project.duration) *
                  M3Motion.exportFps)
              .ceil();
      for (var frame = 0; frame < maxFrame; frame++) {
        if (isCancelled()) throw const FormatException('Export cancelled');
        final position = frame / M3Motion.exportFps;
        onCapturePosition(position);
        onPosition(position);
        onStatus('Preparing opening animation…');
        onProgress(.10 + .12 * frame / max(1, maxFrame));
        onCaptureIndex(max(0, project.clipAt(position)));

        final file = File('${temp.path}/intro_$frame.png');
        await file.writeAsBytes(await onCapturePng());
        introFrames.add(file.path);
      }

      final slideFrames = <List<String>>[];
      final totalSlideFrames = List.generate(
        project.clips.length,
        (i) => i == 0
            ? 0
            : (TemplateLayout.transitionDuration(project, i) *
                      M3Motion.exportFps)
                  .ceil(),
      ).fold<int>(0, (sum, n) => sum + n);
      var capturedSlides = 0;
      for (var i = 0; i < project.clips.length; i++) {
        if (i == 0) {
          slideFrames.add(const []);
          continue;
        }
        final slideDur = TemplateLayout.transitionDuration(project, i);
        final count = (slideDur * M3Motion.exportFps).ceil();
        final list = <String>[];
        for (var frame = 0; frame < count; frame++) {
          if (isCancelled()) throw const FormatException('Export cancelled');
          final position = project.startOf(i) + frame / M3Motion.exportFps;
          onCapturePosition(position);
          onPosition(position);
          onStatus('Preparing card transition $i…');
          onProgress(.22 + .13 * capturedSlides / max(1, totalSlideFrames));
          onCaptureIndex(i);

          final file = File('${temp.path}/slide_${i}_$frame.png');
          await file.writeAsBytes(await onCapturePng());
          list.add(file.path);
          capturedSlides++;
        }
        slideFrames.add(list);
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
        slideFrames: slideFrames,
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
      final overlayDurations = <double>[];

      for (var i = 0; i < scenes.length; i++) {
        final scene = scenes[i];
        final clip = project.clips[scene.mediaIndex];
        final orbit = project.isStreetview3d;
        final media = scene.kind == 'media';
        final followsMap =
            !orbit &&
            media &&
            StreetviewTimeline.followsMap(project, scene.mediaIndex);
        // Whole-project precaching can evict early assets on longer reels.
        // Decode this scene's actual pixels immediately before its first paint;
        // otherwise a resolved Image.file can still capture a transparent frame.
        OrbitScene? geometry;
        if (orbit && clip.streetview.mapPath != null) {
          geometry = await OrbitSceneLoader.loadForExport(
            clip.streetview.mapPath!,
          );
          final nextPath =
              (scene.kind == 'arrow' || scene.kind == 'back') &&
                  scene.mediaIndex + 1 < project.clips.length
              ? project.clips[scene.mediaIndex + 1].streetview.mapPath
              : null;
          if (nextPath != null) {
            await OrbitSceneLoader.loadForExport(nextPath);
          }
        }
        final nextMap =
            orbit &&
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
          if (orbit && !clip.isTimed && clip.streetview.walking)
            ...clip.streetview.walkLayers,
          if (orbit &&
              scene.kind == 'arrow' &&
              project.clips[scene.mediaIndex + 1].streetview.walking)
            ...project.clips[scene.mediaIndex + 1].streetview.walkLayers,
          if (scene.kind == 'map' || (orbit && media && !clip.isTimed))
            posters[clip.id]!,
          if (scene.kind == 'ending-map' ||
              scene.kind == 'back' ||
              scene.kind == 'arrow')
            posters['${clip.id}:end']!,
          if (scene.kind == 'arrow' || nextMap != clip)
            posters[project.clips[scene.mediaIndex + 1].id]!,
          if ((scene.kind == 'map' ||
                  scene.kind == 'ending-map' ||
                  scene.kind == 'back' ||
                  followsMap) &&
              !orbit &&
              clip.streetview.mapPath != null)
            clip.streetview.mapPath!,
        };
        for (final asset in assets) {
          if (isCancelled()) throw const FormatException('Export cancelled');
          await onPrecache(asset);
        }

        final animatedArrows =
            media &&
            clip.streetview.showArrows &&
            StreetviewMotion.active(clip);
        final expandDur = followsMap
            ? StreetviewTimeline.expandDuration(clip)
            : 0.0;

        Future<String> captureAt(String name, double capturePos) async {
          onCaptureSnapshot(false);
          onCapturePosition(capturePos);
          onPosition(capturePos);
          final file = File('${temp.path}/$name.png');
          await file.writeAsBytes(await onCapturePng());
          return file.path;
        }

        final paths = <String>[];
        if (!orbit && media && !animatedArrows && !followsMap) {
          onProgress(.35 * i / scenes.length);
          onStatus('Preparing journey scene ${i + 1} of ${scenes.length}…');
          final settled = await captureAt('streetview-$i-0', scene.start);
          overlays.add(settled);
          frames.add(const []);
          overlayDurations.add(0.0);
        } else if (media && !animatedArrows && followsMap) {
          final count = (expandDur * M3Motion.exportFps).ceil();
          for (var f = 0; f < count; f++) {
            if (isCancelled()) throw const FormatException('Export cancelled');
            onProgress(.35 * (i + f / max(1, count + 1)) / scenes.length);
            onStatus('Preparing journey scene ${i + 1} of ${scenes.length}…');
            paths.add(
              await captureAt(
                'streetview-$i-$f',
                scene.start + f / M3Motion.exportFps,
              ),
            );
          }
          if (isCancelled()) throw const FormatException('Export cancelled');
          final settled = await captureAt(
            'streetview-$i-settled',
            scene.start + min(scene.duration - .001, expandDur + .001),
          );
          overlays.add(settled);
          frames.add(paths);
          overlayDurations.add(expandDur);
        } else {
          final count = (scene.duration * M3Motion.exportFps).ceil();
          final cached = <String, String>{};
          for (var f = 0; f < count; f++) {
            if (isCancelled()) throw const FormatException('Export cancelled');
            final key = orbit
                ? 'frame-$f'
                : StreetviewCapturePlan.key(project, scene, f);
            onProgress(.35 * (i + f / max(1, count)) / scenes.length);
            onStatus('Preparing journey scene ${i + 1} of ${scenes.length}…');
            final path = cached[key] ??= await captureAt(
              'streetview-$i-$f',
              scene.start + f / M3Motion.exportFps,
            );
            paths.add(path);
          }
          overlays.add(paths.last);
          frames.add(paths);
          overlayDurations.add(scene.duration);
        }

        clips.add(
          media
              ? {
                  ...clip.toJson(),
                  'slowPanZoom': clip.streetview.panZoom,
                  'cameraMotion': StreetviewMotion.native(clip),
                  if (followsMap && expandDur > 0)
                    'containerExpand': StreetviewContainerMotion.nativeExpand(
                      expandDur,
                    ),
                  if (orbit && clip.isTimed)
                    'orbitPlaneFrames': [
                      for (int f = 0; f < paths.length; f++)
                        OrbitMediaPose.at(
                          'media',
                          (f / M3Motion.exportFps) / scene.duration,
                          scene: geometry,
                          wallId: clip.streetview.wallId,
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
        overlayDurations: overlayDurations,
        music: project.music,
      );

      if (isCancelled()) throw const FormatException('Export cancelled');
      return path;
    } finally {
      await progressSubscription?.cancel();
    }
  }
}
