import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MapsAdvancedSettings {
  final String key;
  final bool useApiHeaders;
  const MapsAdvancedSettings(this.key, {this.useApiHeaders = false});

  static Future<MapsAdvancedSettings> load({String defaultKey = ''}) async {
    final prefs = await SharedPreferences.getInstance();
    return MapsAdvancedSettings(
      prefs.getString('mapsApiKey') ?? defaultKey,
      useApiHeaders: prefs.getBool('mapsUseApiHeaders') ?? false,
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('mapsApiKey', key);
    await prefs.setBool('mapsUseApiHeaders', useApiHeaders);
  }

  static Future<MapsAdvancedSettings?> show(
    BuildContext context, {
    required String initialKey,
    required bool useApiHeaders,
  }) =>
      showDialog<MapsAdvancedSettings>(
        context: context,
        builder: (_) => MapsKeyDialog(
          initialValue: initialKey,
          useApiHeaders: useApiHeaders,
        ),
      );
}

class MapsKeyDialog extends StatefulWidget {
  final String initialValue;
  final bool useApiHeaders;
  const MapsKeyDialog({
    super.key,
    required this.initialValue,
    this.useApiHeaders = false,
  });
  @override
  State<MapsKeyDialog> createState() => _MapsKeyDialogState();
}

class _MapsKeyDialogState extends State<MapsKeyDialog> {
  late final _controller = TextEditingController(text: widget.initialValue);
  late bool _apiHeaders = widget.useApiHeaders;
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return AlertDialog(
      icon: const Icon(Icons.map_outlined),
      title: const Text('Advanced · Google Maps'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Optional API access',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'By default, Mockareel captures map imagery directly using the '
                'built-in browser engine — no API keys or billing required. '
                'If you prefer Google Static Maps API imagery, provide a key '
                'below.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Google Maps API key',
                  hintText: 'AIzaSy…',
                  border: const OutlineInputBorder(),
                  suffixIcon: _controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(_controller.clear),
                        )
                      : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _apiHeaders,
                onChanged: (v) => setState(() => _apiHeaders = v),
                title: const Text('Prefer API headers'),
                subtitle: const Text(
                  'Use Static Maps API for Place headers when a key is set',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            MapsAdvancedSettings(_controller.text.trim(),
                useApiHeaders: _apiHeaders),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
