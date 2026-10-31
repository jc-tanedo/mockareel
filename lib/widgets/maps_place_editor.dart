import 'package:flutter/material.dart';
import '../model/project.dart';
import '../services/project_store.dart';
import 'editor_section_card.dart';
import 'editor_workspace.dart';
import 'output_theme_picker.dart';
import 'place_actions_editor.dart';
import 'streetview_inspector.dart';
import 'template_content_editor.dart';

class MapsPlaceEditor extends StatelessWidget {
  final ReelProject project;
  final int placeTool;
  final bool importing;
  final bool useApiHeaders;
  final String apiKey;
  final ProjectStore store;
  final int selectedClipIndex;
  final TextEditingController nameController;
  final TextEditingController categoryController;
  final TextEditingController addressController;
  final TextEditingController ratingController;
  final TextEditingController localNameController;
  final TextEditingController reviewsController;
  final TextEditingController priceController;
  final TextEditingController hoursController;
  final ValueChanged<int> onSelectPlaceTool;
  final VoidCallback onFindPlace;
  final VoidCallback onLoadMap;
  final VoidCallback onUploadMap;
  final VoidCallback onGoToTimeline;
  final Widget clipStrip;
  final Widget addMediaButton;
  final VoidCallback onChanged;
  final VoidCallback onPreviewUpdated;

  const MapsPlaceEditor({
    super.key,
    required this.project,
    required this.placeTool,
    required this.importing,
    required this.useApiHeaders,
    required this.apiKey,
    required this.store,
    required this.selectedClipIndex,
    required this.nameController,
    required this.categoryController,
    required this.addressController,
    required this.ratingController,
    required this.localNameController,
    required this.reviewsController,
    required this.priceController,
    required this.hoursController,
    required this.onSelectPlaceTool,
    required this.onFindPlace,
    required this.onLoadMap,
    required this.onUploadMap,
    required this.onGoToTimeline,
    required this.clipStrip,
    required this.addMediaButton,
    required this.onChanged,
    required this.onPreviewUpdated,
  });

  Widget _field(
    String name,
    TextEditingController controller, {
    TextInputType? keyboard,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        onChanged: (_) => onChanged(),
        decoration: InputDecoration(labelText: name),
      ),
    );
  }

  Widget _heroPicker() {
    return DropdownButtonFormField<String>(
      key: ValueKey('hero-${project.id}-${project.heroClip?.id}'),
      initialValue: project.heroClip?.id,
      decoration: const InputDecoration(labelText: 'Peeking header photo'),
      isExpanded: true,
      items: project.clips
          .map(
            (c) => DropdownMenuItem(
              value: c.id,
              child: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: (id) {
        project.heroClipId = id;
        onPreviewUpdated();
        onChanged();
      },
    );
  }

  Widget _streetviewTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        OutputThemePicker(project: project, onChanged: onChanged),
        if (project.clips.isEmpty)
          addMediaButton
        else ...[
          clipStrip,
          StreetviewInspector(
            key: ValueKey(project.clips[selectedClipIndex].id),
            project: project,
            clip: project.clips[selectedClipIndex],
            store: store,
            onChanged: onChanged,
          ),
        ],
      ],
    );
  }

  Widget _mapsEditTab() {
    return Column(
      children: [
        InspectorTabs(
          labels: const ['Details', 'Look', 'Header', 'Buttons', 'Review'],
          selected: placeTool,
          onSelected: onSelectPlaceTool,
        ),
        Expanded(
          child: ListView(
            key: ValueKey('place-inspector-$placeTool'),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            children: switch (placeTool) {
              0 => [
                EditorSectionCard(
                  title: const Text('Place details'),
                  spacing: 0,
                  children: [
                    FilledButton.icon(
                      onPressed: onFindPlace,
                      icon: const Icon(Icons.search, size: 18),
                      label: const Text('Find a place on Google Maps'),
                    ),
                    const SizedBox(height: 16),
                    _field('Place name', nameController),
                    _field('Category & description', categoryController),
                    _field('Address', addressController),
                  ],
                ),
                EditorSectionCard(
                  title: const Text('More place details'),
                  children: [
                    _field(
                      'Rating',
                      ratingController,
                      keyboard: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    _field('Local / alternate place name', localNameController),
                    _field(
                      'Review count',
                      reviewsController,
                      keyboard: TextInputType.number,
                    ),
                    _field('Price / price range', priceController),
                    _field('Hours / open status', hoursController),
                  ],
                ),
              ],
              1 => [
                OutputThemePicker(project: project, onChanged: onChanged),
                EditorSectionCard(
                  title: const Text('Story controls'),
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Story controls overlay'),
                      subtitle: const Text(
                        'Decorative controls from the reference',
                      ),
                      value: project.storyChrome,
                      onChanged: (v) {
                        project.storyChrome = v;
                        onChanged();
                      },
                    ),
                  ],
                ),
              ],
              2 => [
                TemplateContentEditor(
                  project: project,
                  loading: importing,
                  showReview: false,
                  onChanged: onChanged,
                  onLoadMap: onLoadMap,
                  useApiHeaders: useApiHeaders && apiKey.isNotEmpty,
                  onUploadMap: onUploadMap,
                ),
                if (project.headerMode == 'photo' && project.clips.isNotEmpty)
                  _heroPicker(),
                if (project.headerMode == 'photo' && project.clips.isEmpty)
                  TextButton.icon(
                    onPressed: onGoToTimeline,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: const Text('Add media in Timeline'),
                  ),
              ],
              3 => [
                PlaceActionsEditor(
                  key: ValueKey(
                    'actions-${project.id}-${project.place.placeId}',
                  ),
                  place: project.place,
                  onChanged: onChanged,
                ),
              ],
              _ => [
                TemplateContentEditor(
                  project: project,
                  loading: importing,
                  showHeader: false,
                  onChanged: onChanged,
                  onLoadMap: onLoadMap,
                  useApiHeaders: useApiHeaders && apiKey.isNotEmpty,
                  onUploadMap: onUploadMap,
                ),
              ],
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return project.isStreetview ? _streetviewTab() : _mapsEditTab();
  }
}
