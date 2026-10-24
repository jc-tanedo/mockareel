import 'dart:io';
import 'package:flutter/material.dart';

/// Keep the location centered as the story header shrinks. Retain the original
/// footer pixels (Google branding and attribution) along its bottom edge.
class BrowserMapHeaderImage extends StatelessWidget {
  final String path;
  const BrowserMapHeaderImage({super.key, required this.path});
  Widget _image() => Image.file(
    File(path),
    fit: BoxFit.cover,
    errorBuilder: (_, __, ___) => const SizedBox(),
  );
  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      _image(),
      Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        height: 24,
        child: ClipRect(
          child: OverflowBox(
            alignment: Alignment.bottomCenter,
            minWidth: 360,
            maxWidth: 360,
            minHeight: 225,
            maxHeight: 225,
            child: _image(),
          ),
        ),
      ),
    ],
  );
}
