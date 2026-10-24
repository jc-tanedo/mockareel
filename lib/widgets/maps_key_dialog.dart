import 'package:flutter/material.dart';

class MapsKeyDialog extends StatefulWidget {
  final String initialValue;
  const MapsKeyDialog({super.key, required this.initialValue});
  @override
  State<MapsKeyDialog> createState() => _MapsKeyDialogState();
}

class _MapsKeyDialogState extends State<MapsKeyDialog> {
  late final _controller = TextEditingController(text: widget.initialValue);
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Google Places key'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Enable Places API (New), Maps Static API and billing in Google Cloud. Use a restricted client key. It is stored on this device and used for place search and map headers.',
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(labelText: 'API key'),
          ),
          const SizedBox(height: 10),
          const Text(
            'Manual place editing, uploaded maps and video export work without a key.',
            style: TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _controller.text.trim()),
        child: const Text('Save key'),
      ),
    ],
  );
}
