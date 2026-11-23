import 'dart:io';
import 'package:flutter/material.dart';
import '../model/project.dart';
import '../model/streetview_layout.dart';
import 'streetview_place_sheet.dart';

Widget streetviewRoundButton(
  IconData icon,
  String label, {
  Color color = const Color(0x99000000),
  Color ink = Colors.white,
}) => Semantics(
  label: label,
  child: Container(
    width: 30,
    height: 30,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    child: Icon(icon, color: ink, size: 18),
  ),
);

class StreetviewMapScene extends StatelessWidget {
  final StreetviewMedia settings;
  final bool dark, showThumbnail;
  final Widget thumbnail;
  const StreetviewMapScene({
    super.key,
    required this.settings,
    required this.dark,
    required this.thumbnail,
    this.showThumbnail = true,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = dark ? Colors.white : const Color(0xff202124);
    final surface = dark ? const Color(0xff383a3a) : Colors.white;
    return Stack(
      children: [
        Positioned.fill(
          child: ColoredBox(
            color: dark ? const Color(0xff1c2b40) : const Color(0xffe5eadf),
          ),
        ),
        if (settings.mapPath != null)
          Positioned(
            left: 0,
            top: 0,
            right: 0,
            height: StreetviewLayout.mapHeight,
            child: Image.file(File(settings.mapPath!), fit: BoxFit.contain),
          ),
        Positioned(
          left: 10,
          right: 10,
          top: 16,
          height: 38,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 4),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      settings.place.name.isEmpty
                          ? settings.place.address
                          : settings.place.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: foreground, fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(Icons.close, color: foreground, size: 19),
                ],
              ),
            ),
          ),
        ),
        if (settings.nearbyLabel.isNotEmpty)
          Positioned(
            top: 64,
            left: 65,
            right: 65,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  settings.nearbyLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: foreground, fontSize: 9),
                ),
              ),
            ),
          ),
        Positioned(
          right: 12,
          top: 98,
          child: streetviewRoundButton(
            Icons.layers_outlined,
            'Map layers',
            color: surface,
            ink: foreground,
          ),
        ),
        Positioned(
          right: 12,
          bottom: 106,
          child: streetviewRoundButton(
            Icons.my_location,
            'Current location',
            color: surface,
            ink: const Color(0xff77a8ff),
          ),
        ),
        if (showThumbnail)
          Positioned(
            left: StreetviewLayout.thumbnailLeft,
            top: StreetviewLayout.thumbnailTop,
            width: StreetviewLayout.thumbnailWidth,
            height: StreetviewLayout.thumbnailHeight,
            child: StreetviewMapThumbnail(thumbnail: thumbnail),
          ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: StreetviewPlaceSheet(
            settings: settings,
            dark: dark,
            map: true,
          ),
        ),
      ],
    );
  }
}

class StreetviewMapThumbnail extends StatelessWidget {
  final Widget thumbnail;
  const StreetviewMapThumbnail({super.key, required this.thumbnail});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      border: Border.all(color: Colors.white60),
      borderRadius: BorderRadius.circular(12),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(11),
      child: Stack(
        fit: StackFit.expand,
        children: [
          thumbnail,
          const Align(
            alignment: Alignment.bottomCenter,
            child: ColoredBox(
              color: Colors.black54,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                child: Row(
                  children: [
                    Icon(Icons.threesixty, color: Colors.white, size: 10),
                    SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        'Street View',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white, fontSize: 8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
