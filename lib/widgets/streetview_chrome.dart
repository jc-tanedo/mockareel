import 'package:flutter/material.dart';
import '../model/project.dart';
import 'streetview_place_sheet.dart';
import 'streetview_map_scene.dart';
import 'streetview_3d_chrome.dart';

export 'streetview_place_sheet.dart';
export 'streetview_map_scene.dart';
export 'streetview_arrows.dart';
export 'streetview_3d_chrome.dart';
export 'streetview_3d_world_overlay.dart';

class StreetviewChrome extends StatelessWidget {
  final StreetviewMedia settings;
  final bool dark;
  final bool is3d;
  const StreetviewChrome({
    super.key,
    required this.settings,
    required this.dark,
    this.is3d = false,
  });

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned(
        left: 12,
        top: 22,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 230),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0x99000000),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'G',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  [
                    settings.attribution,
                    settings.date,
                  ].where((s) => s.isNotEmpty).join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 9),
                ),
              ),
            ],
          ),
        ),
      ),
      if (settings.showControls) ...[
        Positioned(
          right: 48,
          top: 20,
          child: streetviewRoundButton(Icons.more_vert, 'More options'),
        ),
        Positioned(
          right: 12,
          top: 20,
          child: streetviewRoundButton(Icons.close, 'Back to Maps'),
        ),
        if (settings.aerialLabel.isNotEmpty)
          Positioned(
            left: 12,
            bottom: 100,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 230),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xaa000000),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.accessibility_new,
                    color: Colors.white,
                    size: 14,
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      settings.aerialLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 9),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Positioned(
          right: 12,
          bottom: 100,
          child: streetviewRoundButton(
            is3d ? Icons.close_fullscreen : Icons.open_in_full,
            is3d ? 'Collapse Street View' : 'Expand Street View',
          ),
        ),
      ],
      if (settings.showLocation)
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: is3d
              ? Streetview3dPlaceSheet(settings: settings, dark: dark)
              : StreetviewPlaceSheet(
                  settings: settings,
                  dark: dark,
                  map: false,
                ),
        ),
    ],
  );
}
