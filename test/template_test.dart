import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockareel/model/project.dart';
import 'package:mockareel/model/template_layout.dart';
import 'package:mockareel/widgets/reel_preview.dart';
import 'package:mockareel/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/memory_project_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  final files = <String>[];
  setUpAll(() async {
    root = await Directory.systemTemp.createTemp('mockareel-render-');
    final fontRoot = Platform.environment['FLUTTER_ROOT'];
    if (fontRoot != null) {
      final font = File(
        '$fontRoot/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
      );
      if (await font.exists()) {
        final loader = FontLoader('Roboto');
        loader.addFont(font.readAsBytes().then(ByteData.sublistView));
        await loader.load();
      }
    }
    if (fontRoot != null) {
      final icons = File(
        '$fontRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      );
      if (await icons.exists()) {
        final loader = FontLoader('MaterialIcons');
        loader.addFont(icons.readAsBytes().then(ByteData.sublistView));
        await loader.load();
      }
    }
    for (final color in [Colors.red, Colors.blue, Colors.green]) {
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawColor(color, BlendMode.src);
      final picture = recorder.endRecording();
      final image = await picture.toImage(120, 120);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      picture.dispose();
      final file = File('${root.path}/${files.length}.png');
      await file.writeAsBytes(png!.buffer.asUint8List());
      files.add(file.path);
    }
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    for (var i = 0; i < 3; i++) {
      canvas.drawRect(
        Rect.fromLTWH(i * 100, 0, 100, 100),
        Paint()..color = [Colors.red, Colors.green, Colors.blue][i],
      );
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(300, 100);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    final file = File('${root.path}/stripes.png');
    await file.writeAsBytes(png!.buffer.asUint8List());
    files.add(file.path);
  });
  tearDownAll(() async => root.delete(recursive: true));
  ReelProject sample() => ReelProject(
    title: 'Reference template',
    slideSeconds: .35,
    storyBadge: 'ig story idea :',
    place: PlaceDetails(
      name: 'Kura Sushi Nishishinjuku',
      localName: 'Kura Sushi · Nishishinjuku',
      category: 'Conveyor belt sushi restaurant',
      rating: '3.9',
      reviewCount: '2,186',
      price: '¥1,000–2,000',
      hours: 'Open · Closes 00:00',
      address: 'Shinjuku, Tokyo, Japan',
    ),
    clips: List.generate(
      3,
      (i) => ReelClip(
        id: '$i',
        path: files[i],
        name: 'Photo $i',
        isVideo: false,
        duration: 1.56,
        cardWidth: .5,
      ),
    ),
  );
  Future<Uint8List> frame(
    WidgetTester tester,
    ReelProject project,
    double time, {
    bool transparent = false,
    String? artifact,
  }) async {
    tester.view.physicalSize = const Size(400, 700);
    tester.view.devicePixelRatio = 1;
    final key = GlobalKey();
    await tester.runAsync(() async {
      await tester.pumpWidget(MaterialApp(home: Container()));
      final context = tester.element(find.byType(Container).first);
      for (final c in project.clips) {
        await precacheImage(FileImage(File(c.path)), context);
      }
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 360,
                height: 640,
                child: RepaintBoundary(
                  key: key,
                  child: ReelCanvas(
                    project: project,
                    position: time,
                    overlayOnly: transparent,
                    posterOnly: true,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    final bytes = await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final artifactRoot = Platform.environment['MOCKAREEL_RENDER_ARTIFACTS'];
      if (artifactRoot != null && artifact != null) {
        await Directory(artifactRoot).create(recursive: true);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '$artifactRoot/$artifact.png',
        ).writeAsBytes(png!.buffer.asUint8List());
      }
      image.dispose();
      return rgba!.buffer.asUint8List();
    });
    expect(tester.takeException(), isNull);
    return bytes!;
  }

  Color pixel(Uint8List bytes, int x, int y) {
    final i = (y * 360 + x) * 4;
    return Color.fromARGB(bytes[i + 3], bytes[i], bytes[i + 1], bytes[i + 2]);
  }

  test(
    'snap includes movement within scene duration, then holds without drift',
    () {
      final p = sample();
      const step = 328 * .5 + 8;
      expect(TemplateLayout.offset(p, 0), 0);
      expect(TemplateLayout.offset(p, 1.56), 0);
      expect(TemplateLayout.offset(p, 1.56 + .175), closeTo(step * .875, 1e-8));
      expect(TemplateLayout.offset(p, 1.56 + .35), step);
      expect(TemplateLayout.offset(p, 3.0), step);
      expect(TemplateLayout.offset(p, p.duration), step * 2);
      expect(p.duration, closeTo(4.68, 1e-8));
    },
  );
  test(
    'old project JSON opens with bounded card geometry and new optional fields',
    () {
      final p = ReelProject.fromJson({
        'clips': [
          {'path': 'a.jpg', 'isVideo': false},
        ],
      });
      expect(p.clips.single.cardWidth, .78);
      expect(p.clips.single.cardHeight, 1);
      p.clips.single
        ..zoom = double.nan
        ..panX = 10
        ..cardWidth = 4;
      p.clips.single.normalize();
      expect(p.clips.single.zoom, 1);
      expect(p.clips.single.panX, 1);
      expect(p.clips.single.cardWidth, 1);
      expect(p.storyBadge, '');
      expect(p.place.reviewCount, '');
    },
  );
  testWidgets('transparent PNG keeps real alpha only in the photo window', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final p = sample()..storyBadge = '';
    final bytes = await frame(
      tester,
      p,
      0,
      transparent: true,
      artifact: 'template-cutout',
    );
    expect(pixel(bytes, 180, 300).a, 0);
    expect(pixel(bytes, 350, 210), Colors.white);
    expect(pixel(bytes, 350, 600), Colors.white);
    expect(pixel(bytes, 10, 20).a, 1);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('cards scroll while the place header and footer stay fixed', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final p = sample();
    final first = await frame(tester, p, 0, artifact: 'scroll-first');
    final middle = await frame(tester, p, 1.735, artifact: 'scroll-moving');
    final hold = await frame(tester, p, 1.91, artifact: 'scroll-snapped');
    expect(pixel(first, 50, 375), const Color(0xfff44336));
    expect(pixel(first, 220, 375), const Color(0xff2196f3));
    expect(pixel(middle, 50, 375), const Color(0xff2196f3));
    expect(pixel(hold, 50, 375), const Color(0xff2196f3));
    expect(pixel(hold, 250, 375), const Color(0xff4caf50));
    expect(
      first.sublist(100 * 360 * 4, 230 * 360 * 4),
      hold.sublist(100 * 360 * 4, 230 * 360 * 4),
    );
    expect(first.sublist(530 * 360 * 4), hold.sublist(530 * 360 * 4));
    expect(pixel(hold, 17, 251), Colors.white, reason: 'rounded card corners');
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'horizontal crop selects the expected side of the original image',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final p = sample();
      p.clips
        ..clear()
        ..add(
          ReelClip(
            id: 'wide',
            path: files[3],
            name: 'Wide photo',
            isVideo: false,
            cardWidth: 1,
          ),
        );
      p.clips.single.panX = -1;
      final left = await frame(tester, p, 0);
      p.clips.single.panX = 1;
      final right = await frame(tester, p, 0);
      expect(pixel(left, 180, 375), const Color(0xfff44336));
      expect(pixel(right, 180, 375), const Color(0xff2196f3));
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'real export buttons share full-size transparent and snapshot PNGs',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final store = MemoryProjectStore()..root = root;
      await tester.runAsync(
        () => Directory('${root.path}/exports').create(recursive: true),
      );
      final p = sample();
      await store.save(p);
      const share = MethodChannel('dev.fluttercommunity.plus/share');
      final paths = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(share, (
        call,
      ) async {
        paths.add(((call.arguments as Map)['paths'] as List).single as String);
        return 'success';
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          share,
          null,
        ),
      );
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MockareelApp(store: store));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Export').last);
      await tester.pumpAndSettle();
      for (final label in ['Transparent template PNG', 'Full snapshot PNG']) {
        final count = paths.length;
        await tester.ensureVisible(find.text(label));
        await tester.tap(find.text(label));
        for (var i = 0; i < 120 && paths.length == count; i++) {
          await tester.pump(const Duration(milliseconds: 20));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
        }
        expect(paths.length, count + 1, reason: label);
        await tester.pumpAndSettle();
        final result = await tester.runAsync(() async {
          final codec = await ui.instantiateImageCodec(
            await File(paths.last).readAsBytes(),
          );
          final frame = await codec.getNextFrame();
          final bytes = await frame.image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          final result = [
            frame.image.width,
            frame.image.height,
            bytes!.getUint8((375 * 3 * 1080 + 50 * 3) * 4 + 3),
          ];
          frame.image.dispose();
          codec.dispose();
          return result;
        });
        expect(result, [1080, 1920, label.startsWith('Transparent') ? 0 : 255]);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
    },
  );
}
