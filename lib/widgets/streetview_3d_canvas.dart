import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../model/project.dart';
import '../model/streetview_3d_camera.dart';
import '../model/streetview_timeline.dart';
import 'media_frame.dart';
import 'streetview_chrome.dart';

/// 3D on-rails Street View canvas for both live preview and 30fps export.
class Streetview3dCanvas extends StatefulWidget {
  final ReelProject project;
  final double position;
  final bool playing, overlayOnly, posterOnly;
  final Map<String, String> posters;

  const Streetview3dCanvas({
    super.key,
    required this.project,
    this.position = 0,
    this.playing = false,
    this.overlayOnly = false,
    this.posterOnly = false,
    this.posters = const {},
  });

  @override
  State<Streetview3dCanvas> createState() => _Streetview3dCanvasState();
}

class _Streetview3dCanvasState extends State<Streetview3dCanvas> {
  final Map<String, ui.Image> _images = {};
  final Set<String> _loading = {};

  @override
  void dispose() {
    for (final img in _images.values) {
      img.dispose();
    }
    _images.clear();
    super.dispose();
  }

  ui.Image? _resolveImage(String? path) {
    if (path == null || path.isEmpty) return null;
    final cached = _images[path];
    if (cached != null) return cached;
    if (_loading.contains(path)) return null;
    _loading.add(path);
    _decodeFile(path).then((img) {
      _loading.remove(path);
      if (!mounted || img == null) return;
      setState(() => _images[path] = img);
    });
    return null;
  }

  Future<ui.Image?> _decodeFile(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final completer = Completer<ui.Image>();
      ui.decodeImageFromList(bytes, completer.complete);
      return await completer.future;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final project = widget.project;
    final scene = StreetviewTimeline.at(project, widget.position);
    final i = scene.mediaIndex;
    final clip = project.clips[i];
    final settings = clip.streetview;
    final elapsed = scene.elapsed(widget.position);

    final isMap = scene.kind == 'map' || scene.kind == 'ending-map';
    final isSwoop = scene.kind == 'swoop';
    final isArrow = scene.kind == 'arrow';
    final isMedia = scene.kind == 'media';

    final walkthrough = project.streetview.walkthroughFrames;
    if (walkthrough.isNotEmpty) {
      return FittedBox(
        child: SizedBox(
          width: 360,
          height: 640,
          child: DefaultTextStyle(
            style: const TextStyle(fontFamily: 'Roboto'),
            child: ClipRect(
              child: _buildWalkthrough(
                walkthrough: walkthrough,
                clip: clip,
                clipIndex: i,
                settings: settings,
                elapsed: elapsed,
                isMedia: isMedia,
                sceneDuration: scene.duration,
              ),
            ),
          ),
        ),
      );
    }

    final mapImage = _resolveImage(settings.mapPath);
    final outgoingPath =
        widget.posters['${clip.id}:end'] ?? widget.posters[clip.id];
    final outgoingImage = _resolveImage(outgoingPath);
    final nextClip = i + 1 < project.clips.length ? project.clips[i + 1] : null;
    final incomingPath = nextClip == null ? null : widget.posters[nextClip.id];
    final incomingImage = _resolveImage(incomingPath);

    final swoopT = isSwoop
        ? (elapsed / max(0.001, scene.duration)).clamp(0.0, 1.0)
        : 0.0;
    final hopT = isArrow
        ? ((elapsed - StreetviewTimeline.rippleSeconds) /
                  max(0.001, scene.duration - StreetviewTimeline.rippleSeconds))
              .clamp(0.0, 1.0)
        : 0.0;

    final Widget content;
    if (isMap) {
      content = Streetview3dAerialScene(
        settings: settings,
        dark: project.darkOutput,
        thumbnail: ClipPoster(
          clip: clip,
          position: 0,
          resolvedPath: widget.posters[clip.id],
        ),
      );
    } else if (isSwoop) {
      content = Streetview3dAerialSwoopScene(
        progress: swoopT,
        settings: settings,
        streetClip: ClipPoster(
          clip: clip,
          position: 0,
          resolvedPath: outgoingPath,
        ),
        mapImage: mapImage,
        streetImage: outgoingImage,
        dark: project.darkOutput,
      );
    } else if (isArrow && nextClip != null) {
      content = Streetview3dDollyScene(
        progress: hopT,
        outgoingMedia: ClipPoster(
          clip: clip,
          position: clip.duration,
          resolvedPath: outgoingPath,
        ),
        incomingMedia: ClipPoster(
          clip: nextClip,
          position: 0,
          resolvedPath: incomingPath,
        ),
        settings: settings,
        dark: project.darkOutput,
        outgoingImage: outgoingImage,
        incomingImage: incomingImage,
      );
    } else {
      // Media rest scene: when overlayOnly is true (during export), native
      // ReelRenderer composites the video/photo underneath, so only draw HUD.
      const camera = Camera3D.streetRest;
      content = Stack(
        fit: StackFit.expand,
        children: [
          if (!widget.overlayOnly)
            widget.posterOnly
                ? ClipPoster(
                    clip: clip,
                    position: elapsed,
                    resolvedPath: widget.posters[clip.id],
                  )
                : MediaFrame(
                    key: ValueKey(clip.id),
                    clip: clip,
                    position: elapsed,
                    playing:
                        widget.playing &&
                        isMedia &&
                        widget.position < project.duration,
                  ),
          if (settings.showArrows || settings.showPoiPins)
            Positioned.fill(
              child: IgnorePointer(
                child: Streetview3dWorldOverlay(
                  camera: camera,
                  settings: settings,
                  showChevrons: settings.showArrows,
                ),
              ),
            ),
          Positioned.fill(
            child: StreetviewChrome(
              settings: settings,
              dark: project.darkOutput,
              is3d: true,
            ),
          ),
        ],
      );
    }

    return FittedBox(
      child: SizedBox(
        width: 360,
        height: 640,
        child: DefaultTextStyle(
          style: const TextStyle(fontFamily: 'Roboto'),
          child: ClipRect(child: content),
        ),
      ),
    );
  }

  Widget _buildWalkthrough({
    required List<String> walkthrough,
    required ReelClip clip,
    required int clipIndex,
    required StreetviewMedia settings,
    required double elapsed,
    required bool isMedia,
    required double sceneDuration,
  }) {
    final total = max(0.001, widget.project.duration);
    final progress = (widget.position / total).clamp(0.0, 1.0);
    final exactIdx = progress * (walkthrough.length - 1);
    final idxA = exactIdx.floor().clamp(0, walkthrough.length - 1);
    final idxB = exactIdx.ceil().clamp(0, walkthrough.length - 1);
    final blend = exactIdx - idxA;

    final sideSign = clipIndex.isEven ? -1.0 : 1.0;
    final sceneT = (elapsed / max(0.001, sceneDuration)).clamp(0.0, 1.0);
    final ease = Curves.easeOutCubic.transform(min(1.0, sceneT * 2.2));
    final tiltY = sideSign * 0.28;
    final dx = sideSign * (1.0 - ease) * 40.0 + sideSign * 26.0;
    final scale = 0.62 + 0.14 * ease;

    final surfaceMatrix = Matrix4.identity()
      ..setEntry(3, 2, 0.0018)
      ..rotateY(tiltY);

    return Stack(
      fit: StackFit.expand,
      children: [
        if (!widget.overlayOnly) ...[
          Image.file(
            File(walkthrough[idxA]),
            fit: BoxFit.cover,
            gaplessPlayback: true,
          ),
          if (idxB != idxA)
            Opacity(
              opacity: blend,
              child: Image.file(
                File(walkthrough[idxB]),
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            ),
        ],
        if (isMedia)
          Center(
            child: Transform.translate(
              offset: Offset(dx, -10),
              child: Transform.scale(
                scale: scale,
                child: Transform(
                  alignment: Alignment.center,
                  transform: surfaceMatrix,
                  child: Container(
                    width: 240,
                    height: 390,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.85),
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.45),
                          blurRadius: 18,
                          offset: Offset(sideSign * 8, 10),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: widget.posterOnly
                        ? ClipPoster(
                            clip: clip,
                            position: elapsed,
                            resolvedPath: widget.posters[clip.id],
                          )
                        : MediaFrame(
                            key: ValueKey(clip.id),
                            clip: clip,
                            position: elapsed,
                            playing:
                                widget.playing &&
                                widget.position < widget.project.duration,
                          ),
                  ),
                ),
              ),
            ),
          ),
        Positioned.fill(
          child: StreetviewChrome(
            settings: settings,
            dark: widget.project.darkOutput,
            is3d: true,
          ),
        ),
      ],
    );
  }
}
