import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import '../model/project.dart';
import '../model/streetview_3d_camera.dart';
import 'streetview_3d_buildings.dart';
import 'streetview_3d_corridor_painter.dart';
import 'streetview_3d_world_overlay.dart';
import 'streetview_chrome.dart';

/// Full-bleed opening aerial map hold for Streetview 3D.
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

/// 3D Ground-plane aerial-to-street swoop dive using [Camera3D],
/// [Streetview3dCorridorPainter], and [Streetview3dBuildingsPainter].
class Streetview3dAerialSwoopScene extends StatelessWidget {
  final double progress;
  final StreetviewMedia settings;
  final Widget streetClip;
  final bool dark;
  final ui.Image? mapImage;
  final ui.Image? streetImage;

  const Streetview3dAerialSwoopScene({
    super.key,
    required this.progress,
    required this.settings,
    required this.streetClip,
    required this.dark,
    this.mapImage,
    this.streetImage,
  });

  @override
  Widget build(BuildContext context) {
    final u = progress.clamp(0.0, 1.0);
    final cam = Camera3D.swoopAt(u);
    final mapAlpha = (1.0 - ((u - 0.55) / 0.35)).clamp(0.0, 1.0);
    final streetAlpha = ((u - 0.42) / 0.45).clamp(0.0, 1.0);
    final buildingHeight = Curves.easeOutCubic.transform(
      (u / 0.55).clamp(0.0, 1.0),
    );
    final buildingAlpha = u < 0.65
        ? 0.72
        : (1.0 - ((u - 0.65) / 0.30)).clamp(0.0, 1.0) * 0.72;
    final sheetT = ((u - 0.75) / 0.25).clamp(0.0, 1.0);
    final sheetSlideY = (1.0 - Curves.easeOutCubic.transform(sheetT)) * 95.0;
    final blocks = BuildingBlock3D.generate(settings.place.name);

    return Stack(
      fit: StackFit.expand,
      children: [
        if (streetImage == null && streetAlpha > 0)
          Positioned.fill(child: Opacity(opacity: streetAlpha, child: streetClip)),
        Positioned.fill(
          child: CustomPaint(
            painter: Streetview3dCorridorPainter(
              camera: cam,
              mapImage: mapImage,
              mapAlpha: mapAlpha,
              incomingImage: streetImage,
              incomingAlpha: streetAlpha,
              incomingZOffset: 0,
            ),
          ),
        ),
        if (settings.showBuildings && buildingAlpha > 0.01)
          Positioned.fill(
            child: CustomPaint(
              painter: Streetview3dBuildingsPainter(
                camera: cam,
                blocks: blocks,
                opacity: buildingAlpha,
                heightScale: buildingHeight,
                dark: dark,
              ),
            ),
          ),
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

/// Compact 3D Street View bottom sheet matching Google Maps 3D Immersive View.
class Streetview3dPlaceSheet extends StatelessWidget {
  final StreetviewMedia settings;
  final bool dark;

  const Streetview3dPlaceSheet({
    super.key,
    required this.settings,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final ink = dark ? Colors.white : const Color(0xff202124);
    final linkColor = dark ? const Color(0xff8ab4f8) : const Color(0xff1a73e8);
    final title = settings.streetviewTitle.isNotEmpty
        ? settings.streetviewTitle
        : settings.place.name.isEmpty
        ? (settings.place.address.isNotEmpty
              ? settings.place.address
              : 'Dropped pin')
        : settings.place.name;
    final dateSubtitle = settings.date.isNotEmpty
        ? settings.date
        : '11 months ago';
    final moreDates = settings.moreDatesLabel.isNotEmpty
        ? settings.moreDatesLabel
        : 'See more dates';

    return Container(
      height: 88,
      decoration: BoxDecoration(
        color: dark ? const Color(0xf016181c) : const Color(0xf5ffffff),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 32,
              height: 3,
              margin: const EdgeInsets.only(top: 8, bottom: 8),
              decoration: BoxDecoration(
                color: dark ? Colors.white24 : Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              dateSubtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: dark ? Colors.white70 : Colors.black54,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          Text(
                            ' · ',
                            style: TextStyle(
                              color: dark ? Colors.white70 : Colors.black54,
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            '$moreDates >',
                            style: TextStyle(
                              color: linkColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: dark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.share_outlined, size: 18, color: ink),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// True 3D on-rails forward/turn dolly transition between stops.
class Streetview3dDollyScene extends StatelessWidget {
  final double progress;
  final Widget outgoingMedia;
  final Widget incomingMedia;
  final StreetviewMedia settings;
  final bool dark;
  final ui.Image? outgoingImage;
  final ui.Image? incomingImage;

  const Streetview3dDollyScene({
    super.key,
    required this.progress,
    required this.outgoingMedia,
    required this.incomingMedia,
    required this.settings,
    this.dark = false,
    this.outgoingImage,
    this.incomingImage,
  });

  @override
  Widget build(BuildContext context) {
    final t = progress.clamp(0.0, 1.0);
    final cam = Camera3D.railHopAt(
      t,
      railStop: settings.railStop,
      railDirection: settings.railDirection,
    );
    final zOffset = settings.railStop == 'far' ? 28.0 : 18.0;
    final yawOffset = settings.railDirection == 'left'
        ? -1.12
        : settings.railDirection == 'right'
        ? 1.12
        : 0.0;
    final incomingAlpha = Curves.easeInOut.transform(
      ((t - 0.15) / 0.75).clamp(0.0, 1.0),
    );
    final buildingAlpha = sin(t * pi) * 0.45;
    final blocks = BuildingBlock3D.generate(settings.place.name);

    return Stack(
      fit: StackFit.expand,
      children: [
        if (outgoingImage == null) ...[
          Positioned.fill(child: outgoingMedia),
          if (incomingAlpha > 0)
            Positioned.fill(
              child: Opacity(opacity: incomingAlpha, child: incomingMedia),
            ),
        ] else
          Positioned.fill(
            child: CustomPaint(
              painter: Streetview3dCorridorPainter(
                camera: cam,
                outgoingImage: outgoingImage,
                incomingImage: incomingImage,
                incomingAlpha: incomingAlpha,
                incomingZOffset: zOffset,
                incomingYawOffset: yawOffset,
              ),
            ),
          ),
        if (settings.showBuildings && buildingAlpha > 0.01)
          Positioned.fill(
            child: CustomPaint(
              painter: Streetview3dBuildingsPainter(
                camera: cam,
                blocks: blocks,
                opacity: buildingAlpha,
                dark: dark,
              ),
            ),
          ),
        Positioned.fill(
          child: Streetview3dWorldOverlay(
            settings: settings,
            camera: cam,
            showChevrons: false,
          ),
        ),
      ],
    );
  }
}
