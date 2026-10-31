import 'package:flutter/material.dart';
import '../model/project.dart';
import '../services/places.dart';

class PlaceSearchDialog extends StatefulWidget {
  final String apiKey, initial;
  const PlaceSearchDialog({
    super.key,
    required this.apiKey,
    required this.initial,
  });
  @override
  State<PlaceSearchDialog> createState() => _PlaceSearchDialogState();
}

class _PlaceSearchDialogState extends State<PlaceSearchDialog> {
  late final _query = TextEditingController(text: widget.initial);
  late final _places = PlacesService(widget.apiKey);
  List<PlaceDetails> _results = [];
  bool _loading = false;
  String? _message;
  Future<void> _search() async {
    if (_query.text.trim().isEmpty || _loading) return;
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final places = await _places.search(_query.text);
      if (mounted) {
        setState(() {
          _results = places;
          if (places.isEmpty) {
            _message = 'No places found. Try a name and city.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _message = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _query.dispose();
    _places.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return AlertDialog(
      icon: const Icon(Icons.travel_explore),
      title: const Text('Find a place'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _query,
                autofocus: true,
                onSubmitted: (_) => _search(),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Place name and city',
                  suffixIcon: IconButton(
                    onPressed: _loading ? null : _search,
                    icon: const Icon(Icons.search),
                  ),
                ),
              ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    _message!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ..._results.map(
                (p) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.place_outlined, color: colors.primary),
                  title: Text(p.name),
                  subtitle: Text(p.address),
                  onTap: () => Navigator.pop(context, p),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Google Maps',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
