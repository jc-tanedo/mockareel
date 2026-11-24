import 'package:flutter/material.dart';
import '../data/orbit_scene_loader.dart';
import '../model/orbit_scene.dart';

class OrbitCoverage extends StatefulWidget {
  final String path;
  const OrbitCoverage({super.key, required this.path});
  @override
  State<OrbitCoverage> createState() => _OrbitCoverageState();
}

class _OrbitCoverageState extends State<OrbitCoverage> {
  late var scene = OrbitSceneLoader.load(widget.path);
  @override
  void didUpdateWidget(OrbitCoverage old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) scene = OrbitSceneLoader.load(widget.path);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<OrbitScene>(
    future: scene,
    builder: (context, snapshot) => Text(
      snapshot.data?.coverage ??
          (snapshot.hasError
              ? 'Orbit unavailable · replace captured map'
              : 'Reading orbit…'),
    ),
  );
}
