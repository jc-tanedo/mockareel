import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mockareel/model/maps_web_result.dart';
import 'package:mockareel/model/project.dart';
import 'package:mockareel/pages/maps_editor_page.dart';
import 'package:mockareel/pages/maps_web_search_page.dart';
import 'package:mockareel/services/maps_editor_actions.dart';
import 'package:mockareel/services/project_store.dart';
import 'package:mockareel/widgets/maps_editor_scaffold.dart';
import 'package:mockareel/widgets/place_form_controllers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('lookup uses newly saved API settings without reopening search', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) {
            context = c;
            return const Scaffold();
          },
        ),
      ),
    );
    var currentKey = '', useApiHeaders = false;
    var settingsRequests = 0, mapLoads = 0;
    final form = PlaceFormControllers();
    final project = ReelProject(headerMode: 'map');
    final pending = MapsEditorActions.findPlace(
      context: context,
      project: project,
      form: form,
      getApiKey: () => currentKey,
      getUseApiHeaders: () => useApiHeaders,
      onRequestApiKey: () async {
        settingsRequests++;
        currentKey = 'new-key';
        useApiHeaders = true;
      },
      onLoadMap: () async {
        mapLoads++;
      },
      onChanged: () {},
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final page = tester.widget<MapsWebSearchPage>(
      find.byType(MapsWebSearchPage),
    );
    expect(await page.requestApiKey!(), 'new-key');
    expect(await page.requestApiKey!(), 'new-key');
    expect(settingsRequests, 1);
    Navigator.of(
      tester.element(find.byType(MapsWebSearchPage)),
    ).pop(MapsWebImport(PlaceDetails(name: 'Imported place')));
    await tester.pumpAndSettle();
    await pending;
    expect(project.place.name, 'Imported place');
    expect(form.name.text, 'Imported place');
    expect(mapLoads, 1);
    await tester.pumpWidget(const SizedBox());
    form.dispose();
  });

  testWidgets('place import downloads and applies its automatic map header', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'mapsApiKey': 'test-key',
      'mapsUseApiHeaders': true,
    });
    late Directory dir;
    late ProjectStore store;
    late Uint8List png;
    await tester.runAsync(() async {
      dir = await Directory.systemTemp.createTemp('maps-import-');
      store = ProjectStore(root: dir);
      await store.initialize();
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawColor(Colors.teal, BlendMode.src);
      final picture = recorder.endRecording();
      final image = await picture.toImage(2, 2);
      png = (await image.toByteData(
        format: ui.ImageByteFormat.png,
      ))!.buffer.asUint8List();
      image.dispose();
      picture.dispose();
    });
    final project = ReelProject(headerMode: 'map');
    var requests = 0;
    Uri? requested;
    try {
      await tester.runAsync(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: MapsEditorPage(store: store, initialProject: project),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      final scaffold = tester.widget<MapsEditorScaffold>(
        find.byType(MapsEditorScaffold),
      );
      http.runWithClient(
        scaffold.onFindPlace,
        () => MockClient((request) async {
          requests++;
          requested = request.url;
          return http.Response.bytes(
            png,
            200,
            headers: {'content-type': 'image/png'},
          );
        }),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      Navigator.of(tester.element(find.byType(MapsWebSearchPage))).pop(
        MapsWebImport(
          PlaceDetails(
            name: 'Imported place',
            latitude: 14.58,
            longitude: 120.98,
          ),
        ),
      );
      for (var i = 0; i < 30 && project.mapHeaderPath == null; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
      }
      expect(requests, 1);
      expect(requested!.host, 'maps.googleapis.com');
      expect(requested!.queryParameters['key'], 'test-key');
      expect(requested!.queryParameters['center'], '14.58,120.98');
      expect(
        project.mapHeaderPath,
        isNotNull,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data)
            .join(' | '),
      );
      expect(project.mapSource, 'google');
      expect(project.place.name, 'Imported place');
      await tester.runAsync(() async {
        expect(await File(project.mapHeaderPath!).readAsBytes(), png);
      });
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        // Drain any in-flight autosave before removing its store.
        await store.projects();
        await dir.delete(recursive: true);
      });
    }
  });
}
