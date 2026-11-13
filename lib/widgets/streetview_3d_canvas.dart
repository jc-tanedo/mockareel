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
    final ripple = isMap && scene.kind != 'ending-map'
        ? (elapsed - scene.duration + StreetviewTimeline.rippleSeconds) /
              StreetviewTimeline.rippleSeconds
        : isArrow
        ? elapsed / StreetviewTimeline.rippleSeconds
        : -1.0;

    final Widget content;
    if (isMap) {
      content = Streetview3dAerialScene(
        settings: settings,
        mapImage: mapImage,
        dark: project.darkOutput,
        ripple: ripple,
      );
    } else if (isSwoop) {
      content = Streetview3dAerialSwoopScene(
        settings: settings,
        mapImage: mapImage,
        streetImage: outgoingImage,
        t: swoopT,
        dark: project.darkOutput,
      );
    } else if (isArrow && nextClip != null) {
      content = Streetview3dDollyScene(
        settings: settings,
        nextSettings: nextClip.streetview,
        outgoingImage: outgoingImage,
        incomingImage: incomingImage,
        t: hopT,
        ripple: ripple,
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
              map: false,
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
}
