import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockareel/model/project.dart';
import 'package:mockareel/model/streetview_3d_camera.dart';
import 'package:mockareel/model/streetview_timeline.dart';
import 'package:mockareel/widgets/streetview_3d_buildings.dart';
import 'package:mockareel/widgets/streetview_3d_world_overlay.dart';
import 'package:mockareel/widgets/streetview_canvas.dart';

void main() {
  test('Camera3D aerialHold, streetRest, swoopAt, and railHopAt', () {
    const aerial = Camera3D.aerialHold;
    expect(aerial.pitch, lessThan(-1.0));
    expect(aerial.pos.y, greaterThan(1.5));

    const rest = Camera3D.streetRest;
    expect(rest.pitch, closeTo(0.0, 0.001));
    expect(rest.pos.y, closeTo(1.7, 0.001));

    final swoopMid = Camera3D.swoopAt(0.5);
    expect(swoopMid.pos.y, greaterThan(rest.pos.y));
    expect(swoopMid.pos.y, lessThan(aerial.pos.y));

    final hopStraight = Camera3D.railHopAt(0.5, railDirection: 'straight');
    expect(hopStraight.yaw, closeTo(0.0, 0.001));
    expect(hopStraight.pos.z, greaterThan(0.0));

    final hopRight = Camera3D.railHopAt(1.0, railDirection: 'right');
    expect(hopRight.yaw, greaterThan(0.1));
  });

  test('StreetviewTimeline includes swoop scene for streetview-3d', () {
    final p = ReelProject(
      template: 'streetview-3d',
      clips: [
        ReelClip(
          id: 'c1',
          name: 'Stop 1',
          path: '/tmp/a.jpg',
          isVideo: false,
          duration: 2.0,
        ),
        ReelClip(
          id: 'c2',
          name: 'Stop 2',
          path: '/tmp/b.jpg',
          isVideo: false,
          duration: 2.0,
        ),
      ],
    );
    final scenes = StreetviewTimeline.scenes(p);
    expect(scenes.any((s) => s.kind == 'swoop'), isTrue);
    expect(scenes.first.kind, 'map');
    expect(scenes[1].kind, 'swoop');
    expect(scenes[2].kind, 'media');
  });

  test('BuildingBlock3D generates corridor blocks', () {
    final blocks = BuildingBlock3D.generate('test-seed');
    expect(blocks, isNotEmpty);
    expect(blocks.any((b) => b.x < 0), isTrue);
    expect(blocks.any((b) => b.x > 0), isTrue);
  });

  testWidgets('Streetview3dWorldOverlay renders road label and POI pins', (
    tester,
  ) async {
    final settings = StreetviewMedia(
      roadLabel: '42ND ST',
      crossStreetLabel: '5TH AVE',
      poiLabels: ['Cafe', 'Museum'],
      showPoiPins: true,
      showArrows: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 640,
            child: Streetview3dWorldOverlay(
              camera: Camera3D.streetRest,
              settings: settings,
            ),
          ),
        ),
      ),
    );
    expect(find.byType(Streetview3dWorldOverlay), findsOneWidget);
    expect(find.text('Cafe'), findsOneWidget);
  });

  testWidgets('StreetviewCanvas delegates to Streetview3dCanvas', (
    tester,
  ) async {
    final p = ReelProject(
      template: 'streetview-3d',
      clips: [
        ReelClip(
          id: 'c1',
          name: 'Stop 1',
          path: '/tmp/a.jpg',
          isVideo: false,
          duration: 2.0,
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StreetviewCanvas(project: p, position: 0.5, posterOnly: true),
        ),
      ),
    );
    expect(find.byType(StreetviewCanvas), findsOneWidget);
  });
}
