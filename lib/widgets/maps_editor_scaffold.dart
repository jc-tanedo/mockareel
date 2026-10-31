import 'dart:math';
import 'package:flutter/material.dart';
import '../model/project.dart';
import '../services/project_store.dart';
import 'creation_steps.dart';
import 'editor_app_bar.dart';
import 'editor_export_overlay.dart';
import 'editor_workspace.dart';
import 'export_monitor.dart';
import 'maps_editor_inspector.dart';
import 'place_form_controllers.dart';
import 'text_editor.dart';

class MapsEditorScaffold extends StatelessWidget {
  final int tab;
  final ReelProject project;
  final ProjectStore store;
  final bool dirty;
  final bool exporting;
  final bool importing;
  final int selected;
  final int placeTool;
  final int timelineTool;
  final bool useApiHeaders;
  final String apiKey;
  final PlaceFormControllers form;
  final String status;
  final ExportPhase exportPhase;
  final double? progress;
  final double exportPosition;
  final String exportFormat;
  final bool cancelled;
  final VoidCallback onCancelExport;
  final VoidCallback onBack;
  final VoidCallback onRename;
  final VoidCallback onSave;
  final VoidCallback onPopSave;
  final ValueChanged<String> onMenuSelected;
  final ValueChanged<int> onGoToStep;
  final ValueChanged<int> onSelectPlaceTool;
  final ValueChanged<int> onSelectTimelineTool;
  final ValueChanged<int> onSelectClip;
  final ValueChanged<int> onRemoveClip;
  final void Function(int index, int delta) onMoveClip;
  final VoidCallback onFindPlace;
  final VoidCallback onLoadMap;
  final VoidCallback onUploadMap;
  final VoidCallback onGoToTimeline;
  final VoidCallback onGoToPlaceHeader;
  final VoidCallback onPickMedia;
  final VoidCallback onPickMusic;
  final VoidCallback onExport;
  final ValueChanged<bool> onExportPng;
  final VoidCallback onBackup;
  final VoidCallback onChanged;
  final VoidCallback onPreviewUpdated;
  final Widget Function(double height) previewBuilder;
  final Widget captureStage;
  final Widget exportPreview;

  const MapsEditorScaffold({
    super.key,
    required this.tab,
    required this.project,
    required this.store,
    required this.dirty,
    required this.exporting,
    required this.importing,
    required this.selected,
    required this.placeTool,
    required this.timelineTool,
    required this.useApiHeaders,
    required this.apiKey,
    required this.form,
    required this.status,
    required this.exportPhase,
    required this.progress,
    required this.exportPosition,
    required this.exportFormat,
    required this.cancelled,
    required this.onCancelExport,
    required this.onBack,
    required this.onRename,
    required this.onSave,
    required this.onPopSave,
    required this.onMenuSelected,
    required this.onGoToStep,
    required this.onSelectPlaceTool,
    required this.onSelectTimelineTool,
    required this.onSelectClip,
    required this.onRemoveClip,
    required this.onMoveClip,
    required this.onFindPlace,
    required this.onLoadMap,
    required this.onUploadMap,
    required this.onGoToTimeline,
    required this.onGoToPlaceHeader,
    required this.onPickMedia,
    required this.onPickMusic,
    required this.onExport,
    required this.onExportPng,
    required this.onBackup,
    required this.onChanged,
    required this.onPreviewUpdated,
    required this.previewBuilder,
    required this.captureStage,
    required this.exportPreview,
  });

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    return PopScope(
      canPop: !exporting,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && dirty) onPopSave();
      },
      child: Stack(
        children: [
          captureStage,
          Scaffold(
            appBar: EditorAppBar(
              title: project.title,
              formatLabel: project.isStreetview
                  ? 'STREET VIEW JOURNEY · 9:16'
                  : 'MAPS PLACE STORY · 9:16',
              dirty: dirty,
              exporting: exporting,
              onBack: onBack,
              onRename: onRename,
              onSave: onSave,
              onMenuSelected: onMenuSelected,
              menuItems: EditorAppBar.standardMenuItems(
                extra: const [
                  PopupMenuItem(
                    value: 'settings',
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.tune_outlined),
                      title: Text('Advanced · Google Maps'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'projects',
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.folder_open_outlined),
                      title: Text('Open or import a project'),
                    ),
                  ),
                ],
              ),
            ),
            body: Column(
              children: [
                if (!keyboard)
                  CreationStepHeading(
                    step: tab,
                    onNext: () => onGoToStep(min(4, tab + 1)),
                  ),
                Expanded(
                  child: tab == 2
                      ? TextEditor(
                          keyboardVisible: keyboard,
                          key: ValueKey(project.id),
                          project: project,
                          selectedClip: selected,
                          onChanged: onChanged,
                        )
                      : EditorWorkspace(
                          key: ValueKey('workspace-$tab'),
                          keyboardVisible: keyboard,
                          previewFraction: tab == 1
                              ? .48
                              : tab == 4
                              ? .50
                              : .56,
                          previewBuilder: previewBuilder,
                          inspector: MapsEditorInspector(
                            tab: tab,
                            project: project,
                            store: store,
                            importing: importing,
                            selectedIndex: selected,
                            placeTool: placeTool,
                            timelineTool: timelineTool,
                            useApiHeaders: useApiHeaders,
                            apiKey: apiKey,
                            formControllers: form,
                            onSelectPlaceTool: onSelectPlaceTool,
                            onSelectTimelineTool: onSelectTimelineTool,
                            onSelectClip: onSelectClip,
                            onRemoveClip: onRemoveClip,
                            onMoveClip: onMoveClip,
                            onFindPlace: onFindPlace,
                            onLoadMap: onLoadMap,
                            onUploadMap: onUploadMap,
                            onGoToTimeline: onGoToTimeline,
                            onGoToPlaceHeader: onGoToPlaceHeader,
                            onPickMedia: onPickMedia,
                            onPickMusic: onPickMusic,
                            onExport: onExport,
                            onExportPng: onExportPng,
                            onBackup: onBackup,
                            onChanged: onChanged,
                            onPreviewUpdated: onPreviewUpdated,
                          ),
                        ),
                ),
              ],
            ),
            bottomNavigationBar: keyboard
                ? null
                : CreationSteps(
                    selected: tab,
                    completed: [
                      project.place.name.trim().isNotEmpty,
                      project.clips.isNotEmpty,
                      project.tags.isNotEmpty,
                      project.music != null,
                      false,
                    ],
                    onSelected: onGoToStep,
                  ),
          ),
          if (exporting)
            EditorExportOverlay(
              title: project.title,
              status: status,
              phase: exportPhase,
              progress: progress,
              position: exportPosition,
              duration: project.duration,
              format: exportFormat,
              preview: exportPreview,
              cancelled: cancelled,
              onCancel: onCancelExport,
            ),
        ],
      ),
    );
  }
}
