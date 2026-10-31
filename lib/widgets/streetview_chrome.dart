import 'package:flutter/material.dart';
import '../model/streetview.dart';

/// Only Street View UI. Media processing and the editor never enter this layer.
class StreetviewChrome extends StatelessWidget {
  final StreetviewMedia settings;
  final bool dark;
  const StreetviewChrome({
    super.key,
    required this.settings,
    required this.dark,
  });
  @override
  Widget build(BuildContext context) {
    final ink = dark ? Colors.white : const Color(0xff202124);
    return Stack(
      children: [
        Positioned(
          top: 88,
          left: 90,
          right: 90,
          child: Column(
            children: [
              Text(
                settings.attribution,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  letterSpacing: -.6,
                  shadows: [Shadow(color: Colors.black38, blurRadius: 3)],
                ),
              ),
              if (settings.copyright.isNotEmpty)
                Text(
                  settings.copyright,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    shadows: [Shadow(color: Colors.black38, blurRadius: 3)],
                  ),
                ),
            ],
          ),
        ),
        if (settings.showControls) ...[
          Positioned(
            left: 8,
            top: 90,
            child: _button(Icons.arrow_back_ios_new, 'Back to Maps'),
          ),
          Positioned(
            right: 62,
            top: 90,
            child: _button(Icons.ios_share, 'Share'),
          ),
          Positioned(
            right: 12,
            top: 90,
            child: _button(Icons.more_horiz, 'More options'),
          ),
        ],
        if (settings.showArrows) ...[
          const Positioned(
            left: 28,
            top: 456,
            width: 56,
            height: 70,
            child: StreetviewArrow(left: true),
          ),
          const Positioned(
            right: 28,
            top: 456,
            width: 56,
            height: 70,
            child: StreetviewArrow(left: false),
          ),
        ],
        if (settings.showLocation)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: dark ? const Color(0xff202124) : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(11),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 19),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 50,
                        height: 3,
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: dark ? Colors.white30 : Colors.black12,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Text(
                      settings.place.address.isEmpty
                          ? settings.place.name
                          : settings.place.address,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: ink, fontSize: 19, height: 1.18),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        if (settings.date.isNotEmpty)
                          Flexible(
                            child: Text(
                              '${settings.date} · ',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: ink, fontSize: 12),
                            ),
                          ),
                        if (settings.moreDatesLabel.isNotEmpty) ...[
                          Flexible(
                            child: Text(
                              settings.moreDatesLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: dark
                                    ? const Color(0xffa8dad5)
                                    : const Color(0xff236963),
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Icon(Icons.chevron_right, size: 16, color: ink),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _button(IconData icon, String label) => Semantics(
    label: label,
    child: Container(
      width: 36,
      height: 36,
      decoration: const BoxDecoration(
        color: Color(0x99000000),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.white, size: 23),
    ),
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
      ..moveTo(size.width * .45, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width * .5, size.height * .5)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width * .45, size.height)
      ..lineTo(0, size.height * .5)
      ..close();
    canvas.drawShadow(path, Colors.black87, 5, true);
    canvas.drawPath(path, Paint()..color = const Color(0xfffafafa));
  }

  @override
  bool shouldRepaint(_ArrowPainter oldDelegate) => left != oldDelegate.left;
}
