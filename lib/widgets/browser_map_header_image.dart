import 'dart:io';
import 'package:flutter/material.dart';

/// A single continuous map revealed behind the moving place sheet. Bottom
/// alignment keeps the captured Google footer in view without duplicating tiles.
class BrowserMapHeaderImage extends StatelessWidget {
  final String path;
  const BrowserMapHeaderImage({super.key, required this.path});
  @override
  Widget build(BuildContext context) => Image.file(
    File(path),
    fit: BoxFit.cover,
    alignment: Alignment.bottomCenter,
    errorBuilder: (_, __, ___) => const SizedBox(),
  );
}
