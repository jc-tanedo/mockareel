import 'package:flutter/material.dart';
import '../model/feed.dart';

class SamsungWeatherCard extends StatelessWidget {
  final FeedSettings settings;
  const SamsungWeatherCard({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xff58a3e9).withValues(alpha: .9),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.topRight,
            child: SizedBox(
              width: 48,
              height: 38,
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    right: 2,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        color: Color(0xffffdf70),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const Positioned(
                    bottom: 0,
                    left: 0,
                    child: Icon(Icons.cloud, color: Colors.white, size: 40),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          Text(
            settings.weatherTemperature,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w300),
          ),
          const SizedBox(height: 4),
          Text(
            settings.weatherLocation,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10),
          ),
          const SizedBox(height: 3),
          Text(
            settings.date,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 8, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class SamsungBriefCard extends StatelessWidget {
  final String text;
  final bool health;
  const SamsungBriefCard({super.key, required this.text, required this.health});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xffe5eee7),
        borderRadius: BorderRadius.circular(35),
      ),
      child: Row(
        children: [
          if (!health) ...[
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                color: Color(0xff74d2d2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: Colors.white,
                size: 17,
              ),
            ),
            const SizedBox(width: 7),
          ],
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xff203844),
              ),
            ),
          ),
          if (health)
            const SizedBox(
              width: 38,
              height: 38,
              child: CustomPaint(painter: HealthRingsPainter()),
            ),
        ],
      ),
    );
  }
}

class GoogleSearchBarWidget extends StatelessWidget {
  final bool pixel;
  const GoogleSearchBarWidget({super.key, required this.pixel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xfff5f7f6),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CustomPaint(painter: GoogleMarkPainter()),
          ),
          const Spacer(),
          if (!pixel) ...[
            const Icon(Icons.auto_awesome, color: Color(0xff4b5963), size: 17),
            const SizedBox(width: 13),
          ],
          const Icon(Icons.mic, color: Color(0xff4285f4), size: 18),
          const SizedBox(width: 13),
          const Icon(
            Icons.camera_alt_outlined,
            color: Color(0xff4285f4),
            size: 18,
          ),
        ],
      ),
    );
  }
}

class HealthRingsPainter extends CustomPainter {
  const HealthRingsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 40, size.height / 40);
    final heart = Path()
      ..moveTo(20, 35)
      ..cubicTo(-8, 18, 6, -1, 20, 11)
      ..cubicTo(34, -1, 48, 18, 20, 35)
      ..close();
    for (final layer in [
      (1.0, const Color(0xff76cf43)),
      (.81, const Color(0xff47c9c9)),
      (.62, const Color(0xff8d6ada)),
      (.43, const Color(0xffef99d9)),
    ]) {
      canvas.save();
      canvas.translate(20, 20);
      canvas.scale(layer.$1);
      canvas.translate(-20, -20);
      canvas.drawPath(
        heart,
        Paint()
          ..color = layer.$2
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.2 / layer.$1
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant HealthRingsPainter old) => false;
}

class GoogleMarkPainter extends CustomPainter {
  const GoogleMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 20, size.height / 20);
    const bounds = Rect.fromLTWH(2, 2, 16, 16);
    for (final arc in [
      (0.0, 1.0, const Color(0xff4285f4)),
      (1.0, 1.6, const Color(0xff34a853)),
      (2.6, 1.3, const Color(0xfffbbc05)),
      (3.9, 1.6, const Color(0xffea4335)),
    ]) {
      canvas.drawArc(
        bounds,
        arc.$1,
        arc.$2,
        false,
        Paint()
          ..color = arc.$3
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.8,
      );
    }
    canvas.drawLine(
      const Offset(10, 10),
      const Offset(18, 10),
      Paint()
        ..color = const Color(0xff4285f4)
        ..strokeWidth = 3.8,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant GoogleMarkPainter old) => false;
}
