import 'package:flutter/material.dart';

class EditorAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String formatLabel;
  final bool dirty;
  final bool exporting;
  final VoidCallback? onBack;
  final VoidCallback? onRename;
  final VoidCallback? onSave;
  final List<PopupMenuEntry<String>> menuItems;
  final PopupMenuItemSelected<String>? onMenuSelected;

  const EditorAppBar({
    super.key,
    required this.title,
    required this.formatLabel,
    required this.dirty,
    required this.exporting,
    this.onBack,
    this.onRename,
    this.onSave,
    this.menuItems = const [],
    this.onMenuSelected,
  });

  static List<PopupMenuEntry<String>> standardMenuItems({
    bool hasBackup = true,
    List<PopupMenuEntry<String>> extra = const [],
  }) => [
    const PopupMenuItem(
      value: 'rename',
      child: ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.drive_file_rename_outline),
        title: Text('Rename project'),
      ),
    ),
    if (hasBackup)
      const PopupMenuItem(
        value: 'backup',
        child: ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.ios_share_outlined),
          title: Text('Share project backup'),
        ),
      ),
    ...extra,
  ];

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AppBar(
      titleSpacing: 0,
      leading: IconButton(
        tooltip: 'Back to projects',
        onPressed: exporting ? null : onBack,
        icon: const Icon(Icons.arrow_back),
      ),
      title: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onRename,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.edit_outlined,
                    size: 13,
                    color: colors.onSurfaceVariant,
                  ),
                ],
              ),
              Text(
                formatLabel,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: colors.primary,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        IconButton(
          tooltip: 'Save project',
          onPressed: onSave,
          icon: Icon(
            dirty ? Icons.save_outlined : Icons.check_circle_outline,
            color: dirty ? colors.primary : colors.onSurfaceVariant,
          ),
        ),
        if (menuItems.isNotEmpty)
          PopupMenuButton<String>(
            tooltip: 'More project options',
            icon: const Icon(Icons.more_vert),
            onSelected: onMenuSelected,
            itemBuilder: (_) => menuItems,
          ),
      ],
    );
  }
}
