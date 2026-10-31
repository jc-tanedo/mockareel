import 'package:flutter/material.dart';

class StoryChromeOverlay extends StatelessWidget {
  const StoryChromeOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return const Stack(
      children: [
        Positioned(
          left: 16,
          top: 20,
          child: Icon(Icons.close, color: Colors.white, size: 22),
        ),
        Positioned(
          right: 20,
          top: 20,
          child: Text(
            'Aa',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Positioned(
          right: 20,
          top: 54,
          child: Icon(
            Icons.sentiment_satisfied_alt,
            color: Colors.white,
            size: 20,
          ),
        ),
        _SideTool(top: 106, icon: Icons.music_note),
        _SideTool(top: 142, icon: Icons.auto_awesome),
        _SideTool(top: 178, icon: Icons.favorite_border),
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
