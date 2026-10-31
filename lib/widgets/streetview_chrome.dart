import 'dart:io';
import 'package:flutter/material.dart';
import '../model/project.dart';
import '../model/streetview_layout.dart';
import 'story_tags.dart';

class StreetviewChrome extends StatelessWidget {
  final StreetviewMedia settings;
  final bool dark;
  const StreetviewChrome({
    super.key,
    required this.settings,
    required this.dark,
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
          child: _round(Icons.more_vert, 'More options'),
        ),
        Positioned(
          right: 12,
          top: 20,
          child: _round(Icons.close, 'Back to Maps'),
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
          child: _round(Icons.open_in_full, 'Expand Street View'),
        ),
      ],
      if (settings.showLocation)
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: StreetviewPlaceSheet(
            settings: settings,
            dark: dark,
            map: false,
          ),
        ),
    ],
  );
}

class StreetviewMapScene extends StatelessWidget {
  final StreetviewMedia settings;
  final bool dark;
  final Widget thumbnail;
  const StreetviewMapScene({
    super.key,
    required this.settings,
    required this.dark,
    required this.thumbnail,
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
          child: _round(
            Icons.layers_outlined,
            'Map layers',
            color: surface,
            ink: foreground,
          ),
        ),
        Positioned(
          right: 12,
          bottom: 106,
          child: _round(
            Icons.my_location,
            'Current location',
            color: surface,
            ink: const Color(0xff77a8ff),
          ),
        ),
        Positioned(
          left: StreetviewLayout.thumbnailLeft,
          top: StreetviewLayout.thumbnailTop,
          width: StreetviewLayout.thumbnailWidth,
          height: StreetviewLayout.thumbnailHeight,
          child: Container(
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
                        padding: EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 4,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.threesixty,
                              color: Colors.white,
                              size: 10,
                            ),
                            SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                'Street View',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                ),
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
          ),
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

Widget _round(
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

class StreetviewPlaceSheet extends StatelessWidget {
  final StreetviewMedia settings;
  final bool dark, map;
  const StreetviewPlaceSheet({
    super.key,
    required this.settings,
    required this.dark,
    required this.map,
  });
  static List<PlaceAction> actions(PlaceDetails place, {required bool map}) =>
      place.actionOverrides ??
      [
        PlaceAction(kind: 'directions', label: 'Directions'),
        PlaceAction(kind: 'start', label: 'Start'),
        if (map) ...[
          PlaceAction(kind: 'ask', label: 'Ask'),
          if (place.phone.isNotEmpty) PlaceAction(kind: 'call', label: 'Call'),
          if (place.website.isNotEmpty)
            PlaceAction(kind: 'directory', label: 'Directory')
          else
            PlaceAction(kind: 'save', label: 'Save'),
        ] else ...[
          PlaceAction(kind: 'share', label: 'Share'),
          PlaceAction(kind: 'save', label: 'Save'),
          PlaceAction(kind: 'add_label', label: 'Add label'),
        ],
      ];
  @override
  Widget build(BuildContext context) {
    final ink = dark ? Colors.white : const Color(0xff202124);
    final title = !map && settings.streetviewTitle.isNotEmpty
        ? settings.streetviewTitle
        : settings.place.name.isEmpty
        ? 'Dropped pin'
        : settings.place.name;
    return Container(
      height: StreetviewLayout.sheetHeight,
      decoration: BoxDecoration(
        color: dark ? const Color(0xff111111) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        children: [
          Container(
            width: 30,
            height: 3,
            margin: const EdgeInsets.only(top: 6, bottom: 6),
            decoration: BoxDecoration(
              color: dark ? Colors.white30 : Colors.black26,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                for (final icon in [
                  Icons.bookmark_border,
                  Icons.share_outlined,
                  Icons.close,
                ]) ...[
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: dark
                          ? Colors.white10
                          : Colors.black.withValues(alpha: .04),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 14, color: ink),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  for (final action in actions(settings.place, map: map))
                    Padding(
                      padding: const EdgeInsets.only(right: 7),
                      child: Container(
                        height: 29,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: action.kind == 'directions'
                              ? const Color(0xff65c5cf)
                              : dark
                              ? const Color(0xff003e46)
                              : const Color(0xffd7f1f3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              placeActionIcon(action.kind),
                              size: 13,
                              color: action.kind == 'directions'
                                  ? const Color(0xff00333c)
                                  : dark
                                  ? const Color(0xffb2f2f6)
                                  : const Color(0xff00545d),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              action.label,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w500,
                                color: action.kind == 'directions'
                                    ? const Color(0xff00333c)
                                    : dark
                                    ? const Color(0xffb2f2f6)
                                    : const Color(0xff00545d),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StreetviewArrows extends StatelessWidget {
  const StreetviewArrows({super.key});
  @override
  Widget build(BuildContext context) => const Stack(
    children: [
      Positioned(
        left: StreetviewLayout.arrowLeft,
        top: StreetviewLayout.arrowTop,
        width: StreetviewLayout.arrowWidth,
        height: StreetviewLayout.arrowHeight,
        child: StreetviewArrow(left: true),
      ),
      Positioned(
        right: StreetviewLayout.arrowLeft,
        top: StreetviewLayout.arrowTop,
        width: StreetviewLayout.arrowWidth,
        height: StreetviewLayout.arrowHeight,
        child: StreetviewArrow(left: false),
      ),
    ],
  );
}

class StreetviewArrow extends StatelessWidget {
  final bool left;
  const StreetviewArrow({super.key, required this.left});
  @override
  Widget build(BuildContext context) => Semantics(
    label: left ? 'Navigate left' : 'Navigate right',
    child: CustomPaint(painter: _ArrowPainter(left)),
  );
}

class _ArrowPainter extends CustomPainter {
  final bool left;
  _ArrowPainter(this.left);
  @override
  void paint(Canvas canvas, Size size) {
    if (!left) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    final path = Path()
      ..moveTo(size.width * .56, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width * .45, size.height * .5)
      ..lineTo(size.width * .77, size.height * .84)
      ..lineTo(size.width * .34, size.height * .84)
      ..lineTo(0, size.height * .5)
      ..close();
    canvas.drawShadow(path, Colors.black54, 3, true);
    canvas.drawPath(
      path.shift(const Offset(0, 5)),
      Paint()..color = const Color(0xff8c8c82),
    );
    canvas.drawPath(path, Paint()..color = const Color(0xffe7e6e0));
  }

  @override
  bool shouldRepaint(_ArrowPainter oldDelegate) => left != oldDelegate.left;
}
