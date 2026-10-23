import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockareel/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> openEditor(WidgetTester tester,
      {double width = 390, Map<String, Object> preferences = const {}}) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues(preferences);
    await tester.pumpWidget(const MockareelApp());
    await tester.pumpAndSettle();
  }

  testWidgets('editor and all tabs render on a narrow Android phone',
      (tester) async {
    await openEditor(tester, width: 360);
    expect(find.text('Google Maps Place'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(4));
    expect(tester.takeException(), isNull);

    for (final tab in ['Cards', 'Scroll', 'Export', 'Edit']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$tab layout');
    }
  });

  testWidgets('saved place, card timing and media restore together',
      (tester) async {
    await openEditor(tester, preferences: {
      'draft': jsonEncode({
        'version': 1,
        'place': {
          'name': 'Cafe Test',
          'subtitle': 'Coffee shop',
          'rating': '4.9',
          'address': 'Makati, Philippines',
        },
        'clipDurationsSeconds': [2, 2.5, 3, 3.5, 4],
        'media': ['/tmp/test-photo.jpg'],
      }),
    });

    final fields =
        tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(fields.map((f) => f.controller!.text),
        ['Cafe Test', 'Coffee shop', '4.9', 'Makati, Philippines']);
    await tester.tap(find.text('Scroll').last);
    await tester.pumpAndSettle();
    expect(find.text('2.0 sec'), findsOneWidget);
    expect(find.text('4.0 sec'), findsOneWidget);
    await tester.tap(find.text('Export').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('1 media clips'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('edited place survives saving and reopening the app',
      (tester) async {
    await openEditor(tester);
    await tester.enterText(find.byType(TextField).first, 'My weekend cafe');
    await tester.tap(find.byIcon(Icons.save_outlined));
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    final project =
        jsonDecode(prefs.getString('draft')!) as Map<String, dynamic>;
    expect(project['place']['name'], 'My weekend cafe');
    expect(project['clipDurationsSeconds'], hasLength(5));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(const MockareelApp());
    await tester.pumpAndSettle();
    expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        'My weekend cafe');
    expect(tester.takeException(), isNull);
  });
}
