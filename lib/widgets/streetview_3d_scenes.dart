import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../model/project.dart';
import 'streetview_chrome.dart';

/// Full-bleed opening aerial map hold for Streetview 3D (0.0s .. 1.25s).
class Streetview3dAerialScene extends StatelessWidget {
  final StreetviewMedia settings;
  final bool dark;
  final Widget? thumbnail;
  final VoidCallback? onStreetTap;

  const Streetview3dAerialScene({
    super.key,
    required this.settings,
    required this.dark,
    this.thumbnail,
    this.onStreetTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: ColoredBox(
            color: dark ? const Color(0xff15222e) : const Color(0xff233a54),
          ),
        ),
        if (settings.mapPath != null)
          Positioned.fill(
            child: Image.file(File(settings.mapPath!), fit: BoxFit.cover),
          ),
        Positioned(
          right: 14,
          top: 20,
          child: streetviewRoundButton(Icons.close, 'Close aerial view'),
        ),
        Positioned(
          left: 14,
          bottom: 24,
          child: GestureDetector(
            onTap: onStreetTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xcc000000),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24, width: 0.5),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.directions_walk, color: Colors.white, size: 15),
                  SizedBox(width: 6),
                  Text(
                    'Street',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 3D Ground-plane aerial-to-street swoop dive with sky horizon and descent blur.
class Streetview3dAerialSwoopScene extends StatelessWidget {
  final double progress; // 0.0 .. 1.0
  final StreetviewMedia settings;
  final Widget streetClip;
  final bool dark;

  const Streetview3dAerialSwoopScene({
    super.key,
    required this.progress,
    required this.settings,
    required this.streetClip,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final u = progress.clamp(0.0, 1.0);
    final pitchT = Curves.easeInOutCubic.transform(u);
    final mapScale = 1.0 + Curves.easeIn.transform(u) * 2.2;
    final mapTranslateY = Curves.easeIn.transform(u) * 140.0;
    final mapOpacity = (1.0 - ((u - 0.48) / 0.40)).clamp(0.0, 1.0);
    final descentBlurY = sin(u * pi) * 14.0;

    // Street-level clip cross-fades in during second half of dive
    final streetOpacity = ((u - 0.45) / 0.45).clamp(0.0, 1.0);
    final streetScale = 0.86 + 0.14 * ((u - 0.45) / 0.55).clamp(0.0, 1.0);

    // Bottom sheet slides up in final 25% of swoop
    final sheetT = ((u - 0.75) / 0.25).clamp(0.0, 1.0);
    final sheetSlideY = (1.0 - Curves.easeOutCubic.transform(sheetT)) * 95.0;

    // Pill position moves from bottom: 24 to bottom: 98
    final pillBottom = ui.lerpDouble(24.0, 98.0, sheetT)!;
    final pillLabel = sheetT >= 0.5 ? 'Aerial' : 'Street';

    final Matrix4 groundPitch = Matrix4.identity()
      ..setEntry(3, 2, 0.0024)
      ..rotateX(pitchT * 1.22);

    return Stack(
      fit: StackFit.expand,
      children: [
        // Sky horizon gradient across upper screen
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 250,
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xff4a90e2),
                  Color(0xff8ec3f8),
                  Color(0xffc8e4ff),
                  Color(0xfff0f7ff),
                ],
                stops: [0.0, 0.4, 0.8, 1.0],
              ),
            ),
          ),
        ),
        // Street media fading in underneath
        if (streetOpacity > 0)
          Positioned.fill(
            child: Opacity(
              opacity: streetOpacity,
              child: Transform.scale(scale: streetScale, child: streetClip),
            ),
          ),
        // Ground plane aerial map diving downward
        if (mapOpacity > 0 && settings.mapPath != null)
          Positioned.fill(
            child: Opacity(
              opacity: mapOpacity,
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(
                  sigmaX: 0,
                  sigmaY: descentBlurY,
                ),
                child: Transform.translate(
                  offset: Offset(0, mapTranslateY),
                  child: Transform.scale(
                    scale: mapScale,
                    alignment: const Alignment(0, -0.2),
                    child: Transform(
                      transform: groundPitch,
                      alignment: const Alignment(0, -0.2),
                      child: Image.file(
                        File(settings.mapPath!),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        // Full Street View 3D Chrome fading in and bottom sheet sliding up
        if (sheetT > 0)
          Positioned.fill(
            child: Opacity(
              opacity: sheetT,
              child: Transform.translate(
                offset: Offset(0, sheetSlideY),
                child: StreetviewChrome(
                  settings: settings,
                  dark: dark,
                  is3d: true,
                ),
              ),
            ),
          ),
        // During early swoop, keep the simple aerial close and street pill
        if (sheetT < 1.0) ...[
          Positioned(
            right: 14,
            top: 20,
            child: Opacity(
              opacity: 1.0 - sheetT,
              child: streetviewRoundButton(Icons.close, 'Close aerial view'),
            ),
          ),
          Positioned(
            left: 14,
            bottom: 24,
            child: Opacity(
              opacity: 1.0 - sheetT,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xcc000000),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white24, width: 0.5),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.directions_walk, color: Colors.white, size: 15),
                    SizedBox(width: 6),
                    Text(
                      'Street',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Continuous zoom-through on-rails dolly transition between stops.
/// Outgoing clip remains 100% opaque (zero black fade!) while incoming clip zooms in.
class Streetview3dDollyScene extends StatelessWidget {
  final double progress; // 0.0 .. 1.0 forward rush progress
  final Widget outgoingMedia;
  final Widget incomingMedia;
  final StreetviewMedia settings;

  const Streetview3dDollyScene({
    super.key,
    required this.progress,
    required this.outgoingMedia,
    required this.incomingMedia,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    final t = progress.clamp(0.0, 1.0);
    final blurX = sin(t * pi) * 10.0;
    final blurY = sin(t * pi) * 26.0;

    // Outgoing clip stays at 100% opacity, zooming forward into horizon vanishing point
    final outgoingScale = 1.0 + Curves.easeInCubic.transform(t) * 1.55;

    // Incoming clip zooms in with full-bleed coverage
    final incomingOpacity = Curves.easeInOut.transform(
      ((t - 0.12) / 0.76).clamp(0.0, 1.0),
    );
    final incomingScale = 1.0 + (1.0 - Curves.easeOutCubic.transform(t)) * 0.18;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Outgoing base layer (ALWAYS 100% opaque)
        ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: blurX, sigmaY: blurY),
          child: Transform.scale(
            scale: outgoingScale,
            alignment: const Alignment(0.0, -0.06),
            child: outgoingMedia,
          ),
        ),
        // Incoming top layer fading in smoothly
        if (incomingOpacity > 0)
          Opacity(
            opacity: incomingOpacity,
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 0, sigmaY: blurY * 0.7),
              child: Transform.scale(
                scale: incomingScale,
                alignment: const Alignment(0.0, -0.06),
                child: incomingMedia,
              ),
            ),
          ),
        // Road text sliding underfoot during camera rush
        Streetview3dRailOverlay(settings: settings, transitionProgress: t),
      ],
    );
  }
}
