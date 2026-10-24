import 'package:flutter/material.dart';

class ProjectNameDialog extends StatefulWidget {
  final String initialValue;
  const ProjectNameDialog({super.key, required this.initialValue});
  @override
  State<ProjectNameDialog> createState() => _ProjectNameDialogState();
}

class _ProjectNameDialogState extends State<ProjectNameDialog> {
  late final _controller = TextEditingController(text: widget.initialValue);
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Project name'),
    content: TextField(controller: _controller, autofocus: true, maxLength: 80),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _controller.text.trim()),
        child: const Text('Save'),
      ),
    ],
  );
}
