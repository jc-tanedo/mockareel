import 'package:flutter/material.dart';
import 'model/project.dart';
import 'services/project_store.dart';
import 'pages/library_page.dart';
import 'pages/maps_editor_page.dart';
import 'theme/app_theme.dart';

class MockareelApp extends StatefulWidget {
  final ProjectStore? store;
  final ReelProject? editorProject;
  const MockareelApp({super.key, this.store, this.editorProject});

  @override
  State<MockareelApp> createState() => _MockareelAppState();
}

class _MockareelAppState extends State<MockareelApp> {
  @override
  void initState() {
    super.initState();
    AppThemeController.instance.load();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppThemePreset>(
      valueListenable: AppThemeController.instance,
      builder: (context, preset, _) {
        return MaterialApp(
          title: 'Mockareel',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(preset),
          home: widget.editorProject == null
              ? LibraryPage(store: widget.store)
              : MapsEditorPage(
                  store: widget.store,
                  initialProject: widget.editorProject,
                ),
        );
      },
    );
  }
}
