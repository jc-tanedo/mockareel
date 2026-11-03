import 'package:flutter/material.dart';

class StoryChromeOverlay extends StatelessWidget {
  final bool showClose;
  final bool showText;
  final bool showStickers;
  final bool showMusic;
  final bool showEffects;
  final bool showLike;

  const StoryChromeOverlay({
    super.key,
    this.showClose = true,
    this.showText = true,
    this.showStickers = true,
    this.showMusic = true,
    this.showEffects = true,
    this.showLike = true,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (showClose)
          const Positioned(
            left: 14,
            top: 10,
            child: Icon(Icons.close, color: Colors.white, size: 22),
          ),
        if (showText)
          const Positioned(
            right: 16,
            top: 10,
            child: Text(
              'Aa',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        if (showStickers)
          const Positioned(
            right: 16,
            top: 40,
            child: Icon(
              Icons.sentiment_satisfied_alt,
              color: Colors.white,
              size: 20,
            ),
          ),
        if (showMusic) const _SideTool(top: 76, icon: Icons.music_note),
        if (showEffects) const _SideTool(top: 112, icon: Icons.auto_awesome),
        if (showLike) const _SideTool(top: 148, icon: Icons.favorite_border),
      ],
    );
  }
}

class _SideTool extends StatelessWidget {
  final double top;
  final IconData icon;
  const _SideTool({required this.top, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 10,
      top: top,
      child: Container(
        width: 29,
        height: 29,
        decoration: const BoxDecoration(
          color: Color(0xff929292),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 13, color: Colors.white),
      ),
    );
  }
}
