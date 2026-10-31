import 'package:flutter/material.dart';
import '../model/streetview_layout.dart';

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
