import 'package:flutter/material.dart';

class MapsAdvancedSettings {
  final String key;
  final bool useApiHeaders;
  const MapsAdvancedSettings(this.key, {this.useApiHeaders = false});
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
              const SizedBox(height: 8),
              Text(
                'Browser search and map capture work without a key. Add your own Google Cloud key to use API lookup or automatic static map headers.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Enable these APIs in your Google Cloud project:',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '1. Places API (New) — API place search and details.\n2. Maps Static API — automatic map header images.\n\nEnable billing for API requests. Maps SDK for Android, Maps JavaScript API and Geocoding API are not required by Mockareel.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'API key (optional)',
                  prefixIcon: Icon(Icons.key_outlined),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Use API map headers'),
                subtitle: const Text(
                  'Load Google map uses Maps Static API instead of browser capture.',
                ),
                value: _apiHeaders && _controller.text.trim().isNotEmpty,
                onChanged: _controller.text.trim().isEmpty
                    ? null
                    : (v) => setState(() => _apiHeaders = v),
              ),
              const SizedBox(height: 8),
              Text(
                'API lookup is in the Google Maps search menu. Restrict your key to the APIs you use and set quotas in Google Cloud. Requests go directly to the web APIs; Android package/SHA restrictions alone may not work with these HTTP endpoints.\n\nThe key is stored in app-private preferences on this device, not encrypted storage, and is excluded from project backups. Clear the field to remove it.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontSize: 12,
                  height: 1.5,
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
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            MapsAdvancedSettings(
              _controller.text.trim(),
              useApiHeaders: _apiHeaders && _controller.text.trim().isNotEmpty,
            ),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
