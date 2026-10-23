import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockareel/model/project.dart';
import 'package:mockareel/services/project_store.dart';
import 'package:mockareel/widgets/place_actions_editor.dart';
import 'package:mockareel/widgets/text_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'store actions omit food controls; food and contact data suggest relevant buttons',
    () {
      final store = PlaceDetails(
        types: ['hardware_store', 'store'],
        website: 'https://example.com',
      );
      expect(store.hasMenu, false);
      expect(store.actions.map((a) => a.kind), [
        'directions',
        'website',
        'save',
      ]);
      expect(store.footer, 'Visit website');
      final cafe = PlaceDetails(types: ['cafe'], phone: '123');
      expect(cafe.hasMenu, true);
      expect(cafe.actions.map((a) => a.kind), [
        'directions',
        'menu',
        'call',
        'save',
      ]);
      store.actionOverrides = [PlaceAction(kind: 'custom', label: 'Shop now')];
      store.menuOverride = true;
      store.footerOverride = 'Browse products';
      final restored = PlaceDetails.fromJson(store.toJson());
      expect(restored.actions.single.label, 'Shop now');
      expect(restored.hasMenu, true);
      expect(restored.footer, 'Browse products');
    },
  );
  test(
    'legacy badge becomes an editable tag and deleted tags stay deleted',
    () {
      final p = ReelProject.fromJson({'storyBadge': 'A hidden gem'});
      expect(p.tags.single.text, 'A hidden gem');
      p.tags.clear();
      expect(ReelProject.fromJson(p.toJson()).tags, isEmpty);
    },
  );
  test(
    'portable projects retain audio, text styles and edited place actions',
    () async {
      SharedPreferences.setMockInitialValues({});
      final root = await Directory.systemTemp.createTemp('mockareel-audio-');
      addTearDown(() => root.delete(recursive: true));
      final first = ProjectStore(root: Directory('${root.path}/first'));
      final second = ProjectStore(root: Directory('${root.path}/second'));
      await first.initialize();
      await second.initialize();
      final file = File('${root.path}/music.mp3');
      await file.writeAsBytes([1, 5, 9, 2]);
      final retained = await first.retainMedia(file.path, 'music.mp3');
      final p = ReelProject(
        music: MusicTrack(
          path: retained,
          name: 'Summer',
          sourceDuration: 25,
          trimStart: 3,
          volume: .4,
          loop: false,
        ),
        tags: [
          StoryTag(
            text: 'Weekend',
            x: .2,
            y: .7,
            size: 26,
            style: 'serif',
            rotation: .3,
            color: 0xffff8bba,
          ),
          StoryTag(text: 'Makati'),
        ],
        place: PlaceDetails(
          actionOverrides: [PlaceAction(kind: 'website', label: 'Shop')],
          menuOverride: false,
          footerOverride: 'Browse',
        ),
      );
      final backup = await first.backup(p);
      final restored = await second.importBackup(backup);
      await Directory('${root.path}/first').delete(recursive: true);
      await file.delete();
      expect(await File(restored.music!.path).readAsBytes(), [1, 5, 9, 2]);
      expect(restored.music!.trimStart, 3);
      expect(restored.music!.volume, .4);
      expect(restored.music!.loop, false);
      expect(restored.tags.map((t) => t.text), ['Weekend', 'Makati']);
      expect(restored.tags.first.toJson(), p.tags.first.toJson());
      expect(restored.place.actions.single.label, 'Shop');
    },
  );
  testWidgets(
    'button labels update and reset without leaving stale field values',
    (tester) async {
      final place = PlaceDetails(
        types: ['hardware_store'],
        website: 'https://example.com',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => SingleChildScrollView(
                child: PlaceActionsEditor(
                  place: place,
                  onChanged: () => setState(() {}),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Template buttons'));
      await tester.pumpAndSettle();
      final field = find.widgetWithText(TextFormField, 'Button 1 label');
      await tester.enterText(field, 'Navigate');
      await tester.pumpAndSettle();
      expect(place.actions.first.label, 'Navigate');
      await tester.tap(find.byTooltip('Remove button 1'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'Button 1 label'),
            )
            .initialValue,
        'Website',
      );
      await tester.ensureVisible(find.text('Reset suggestions'));
      await tester.tap(find.text('Reset suggestions'));
      await tester.pumpAndSettle();
      expect(place.actionOverrides, isNull);
      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'Button 1 label'),
            )
            .initialValue,
        'Directions',
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'text layers drag in canvas coordinates, duplicate and delete independently',
    (tester) async {
      tester.view.physicalSize = const Size(360, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final p = ReelProject(tags: [StoryTag(text: 'Hello', x: .5, y: .4)]);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextEditor(project: p, onChanged: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hello').first);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Duplicate tag'), findsOneWidget);
      await tester.drag(find.text('Hello').first, const Offset(30, 40));
      await tester.pumpAndSettle();
      expect(p.tags.single.x, greaterThan(.5));
      expect(p.tags.single.y, greaterThan(.4));
      await tester.ensureVisible(find.byTooltip('Duplicate tag'));
      await tester.tap(find.byTooltip('Duplicate tag'));
      await tester.pumpAndSettle();
      expect(p.tags.length, 2);
      expect(p.tags[0].id, isNot(p.tags[1].id));
      await tester.tap(find.byTooltip('Delete tag'));
      await tester.pumpAndSettle();
      expect(p.tags.length, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
