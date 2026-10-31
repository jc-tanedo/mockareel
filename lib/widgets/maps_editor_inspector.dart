import 'dart:math';
import 'package:flutter/material.dart';
import '../model/project.dart';
import '../services/project_store.dart';
import 'audio_editor.dart';
import 'maps_export_panel.dart';
import 'maps_place_editor.dart';
import 'maps_timeline_editor.dart';
import 'place_form_controllers.dart';

class MapsEditorInspector extends StatelessWidget {
  final int tab;
  final ReelProject project;
  final ProjectStore store;
  final bool importing;
  final int selectedIndex;
  final int placeTool;
  final int timelineTool;
  final bool useApiHeaders;
  final String apiKey;
  final PlaceFormControllers formControllers;
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

  const MapsEditorInspector({
    super.key,
    required this.tab,
    required this.project,
    required this.store,
    required this.importing,
    required this.selectedIndex,
    required this.placeTool,
    required this.timelineTool,
    required this.useApiHeaders,
    required this.apiKey,
    required this.formControllers,
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
  });

  Widget _addMediaButton() => OutlinedButton.icon(
    onPressed: importing ? null : onPickMedia,
    icon: importing
        ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.add_photo_alternate_outlined),
    label: Text(importing ? 'Importing media…' : 'Add photos & videos'),
  );

  @override
  Widget build(BuildContext context) {
    final addMedia = _addMediaButton();
    return switch (tab) {
      0 => MapsPlaceEditor(
        project: project,
        placeTool: placeTool,
        importing: importing,
        useApiHeaders: useApiHeaders,
        apiKey: apiKey,
        store: store,
        selectedClipIndex: selectedIndex.clamp(
          0,
          max(0, project.clips.length - 1),
        ),
        nameController: formControllers.name,
        categoryController: formControllers.category,
        addressController: formControllers.address,
        ratingController: formControllers.rating,
        localNameController: formControllers.localName,
        reviewsController: formControllers.reviews,
        priceController: formControllers.price,
        hoursController: formControllers.hours,
        onSelectPlaceTool: onSelectPlaceTool,
        onFindPlace: onFindPlace,
        onLoadMap: onLoadMap,
        onUploadMap: onUploadMap,
        onGoToTimeline: onGoToTimeline,
        clipStrip: MapsTimelineEditor.buildClipStrip(
          context: context,
          project: project,
          selectedIndex: selectedIndex,
          onSelectClip: onSelectClip,
        ),
        addMediaButton: addMedia,
        onChanged: onChanged,
        onPreviewUpdated: onPreviewUpdated,
      ),
      1 => MapsTimelineEditor(
        project: project,
        selectedIndex: selectedIndex,
        timelineTool: timelineTool,
        importing: importing,
        store: store,
        onPickMedia: onPickMedia,
        addMediaButton: addMedia,
        onSelectClip: onSelectClip,
        onSelectTool: onSelectTimelineTool,
        onRemoveClip: onRemoveClip,
        onMoveClip: onMoveClip,
        onChanged: onChanged,
        onPreviewUpdated: onPreviewUpdated,
      ),
      3 => AudioEditor(
        project: project,
        importing: importing,
        onPick: onPickMusic,
        onChanged: onChanged,
      ),
      _ => MapsExportPanel(
        project: project,
        importing: importing,
        onExport: onExport,
        onExportPng: onExportPng,
        onBackup: onBackup,
        onSetupHeader: onGoToPlaceHeader,
      ),
    };
  }
}
