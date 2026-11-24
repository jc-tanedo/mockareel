import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mockareel/model/place_details.dart';
import 'package:mockareel/widgets/maps_key_dialog.dart';
import '../data/open_orbit_map.dart';
import '../model/orbit_scene.dart';
import 'google_orbit_capture_page.dart';

Future<({List<int> bytes, String coverage})?> captureOrbit(
  BuildContext context,
  PlaceDetails place,
) async {
  if (place.latitude == null || place.longitude == null) {
    final coords = await showDialog<(double, double)>(
      context: context,
      builder: (_) => const _PinCoordinates(),
    );
    if (coords == null || !context.mounted) return null;
    place.latitude = coords.$1;
    place.longitude = coords.$2;
  }
  final config = await MapsAdvancedSettings.load(
    defaultKey: const String.fromEnvironment('MAPS_API_KEY'),
  );
  if (!context.mounted) return null;
  String? scene, fallbackReason;
  if (config.key.trim().isNotEmpty) {
    final result = await Navigator.of(context).push<GoogleOrbitResult>(
      MaterialPageRoute(
        builder: (_) => GoogleOrbitCapturePage(
          apiKey: config.key.trim(),
          latitude: place.latitude!,
          longitude: place.longitude!,
        ),
      ),
    );
    if (result == null || !context.mounted) return null;
    scene = result.scene;
    fallbackReason = result.reason;
  }
  scene ??= await OpenOrbitMap.fetch(place.latitude!, place.longitude!);
  final coverage = [
    ?fallbackReason,
    OrbitScene.decode(scene).coverage,
  ].join(' ');
  return (bytes: utf8.encode(scene), coverage: coverage);
}

class _PinCoordinates extends StatefulWidget {
  const _PinCoordinates();
  @override
  State<_PinCoordinates> createState() => _PinCoordinatesState();
}

class _PinCoordinatesState extends State<_PinCoordinates> {
  String lat = '', lon = '';
  @override
  Widget build(BuildContext context) {
    final latitude = double.tryParse(lat.trim()),
        longitude = double.tryParse(lon.trim());
    final valid =
        latitude != null &&
        latitude.abs() <= 85 &&
        longitude != null &&
        longitude.abs() <= 180;
    return AlertDialog(
      title: const Text('Enter pin coordinates'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'The selected place did not include coordinates. Enter its pin to load buildings and terrain.',
            ),
            TextField(
              decoration: const InputDecoration(labelText: 'Latitude'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              onChanged: (v) => setState(() => lat = v),
            ),
            TextField(
              decoration: const InputDecoration(labelText: 'Longitude'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              onChanged: (v) => setState(() => lon = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: valid
              ? () => Navigator.pop(context, (latitude, longitude))
              : null,
          child: const Text('Load map'),
        ),
      ],
    );
  }
}
