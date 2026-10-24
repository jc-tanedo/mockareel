import 'package:flutter/material.dart';
import 'model/project.dart';
import 'services/project_store.dart';
import 'pages/library_page.dart';
import 'pages/maps_editor_page.dart';
import 'theme/app_theme.dart';

class MockareelApp extends StatelessWidget {
  final ProjectStore? store;
  final ReelProject? editorProject;
  const MockareelApp({super.key, this.store, this.editorProject});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Mockareel',
    debugShowCheckedModeBanner: false,
    theme: buildAppTheme(),
    home: editorProject == null
        ? LibraryPage(store: store)
        : MapsEditorPage(store: store, initialProject: editorProject),
  );
}
