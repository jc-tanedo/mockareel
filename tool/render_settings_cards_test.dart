// Optional visual review: flutter test tool/render_settings_cards_test.dart
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockareel/app.dart';
import 'package:mockareel/model/project.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../test/support/memory_project_store.dart';

void main() {
  testWidgets('render settings cards for visual review', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1100, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final output = Directory('/tmp/mockareel-settings-cards');
    await tester.runAsync(() async {
      await output.create(recursive: true);
      final sdk = Platform.environment['FLUTTER_ROOT']!;
      for (final font in [
        ('Roboto', 'Roboto-Regular.ttf'),
        ('MaterialIcons', 'MaterialIcons-Regular.otf'),
      ]) {
        await (FontLoader(font.$1)..addFont(
              File(
                '$sdk/bin/cache/artifacts/material_fonts/${font.$2}',
              ).readAsBytes().then(ByteData.sublistView),
            ))
            .load();
      }
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 360, 640),
        Paint()..color = const Color(0xffa0c4cd),
      );
      canvas.drawRect(
        const Rect.fromLTWH(0, 350, 360, 290),
        Paint()..color = const Color(0xff6b8765),
      );
      canvas.drawRect(
        const Rect.fromLTWH(0, 440, 360, 90),
        Paint()..color = const Color(0xffb9b5a9),
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(360, 640);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '${output.path}/source.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
      picture.dispose();
    });
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    final store = MemoryProjectStore();
    final clip = ReelClip(
      id: 'a',
      path: '${output.path}/source.png',
      name: 'Park.jpg',
      isVideo: false,
    );
    clip.streetview.place.name = 'Lakeshore Pampanga';
    clip.streetview.slowZoom = true;
    clip.streetview.turntable = true;
    final project = ReelProject(
      title: 'Afternoon at Lakeshore',
      template: 'streetview',
      clips: [clip],
    );
    await store.save(project);
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MockareelApp(store: store, editorProject: project),
      ),
    );
    await tester.pumpAndSettle();
    Future<void> capture(String name) async {
      await tester.runAsync(() async {
        final image =
            await (key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '${output.path}/$name.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    for (final size in [const Size(1100, 900), const Size(390, 844)]) {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      final label = size.width > 680 ? 'tablet' : 'phone';
      for (final title in [
        'Camera motion',
        'Street View overlays',
        'Journey timing and ending',
      ]) {
        await Scrollable.ensureVisible(
          tester.element(find.text(title)),
          alignment: 0,
        );
        await tester.pumpAndSettle();
        await capture('$label-${title.split(' ').first.toLowerCase()}');
      }
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
