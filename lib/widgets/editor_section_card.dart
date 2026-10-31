import 'package:flutter/material.dart';

/// A visible settings group. Every peer section has the same heading inset,
/// surface, border and spacing; secondary groups stay inside that surface.
class EditorSectionCard extends StatelessWidget {
  final Widget title;
  final Widget? subtitle;
  final List<Widget> children;
  final double spacing;
  final bool embedded;
  const EditorSectionCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
    this.spacing = 12,
    this.embedded = false,
  });

  @override
  Widget build(BuildContext context) {
    if (embedded) {
      return EditorControlGroup(
        title: title,
        subtitle: subtitle,
        children: children,
      );
    }
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: .6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Theme(
          data: theme.copyWith(
            inputDecorationTheme: theme.inputDecorationTheme.copyWith(
              fillColor: colors.surfaceContainerHigh,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 14,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                header: true,
                child: DefaultTextStyle.merge(
                  style: theme.textTheme.titleSmall!.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface,
                  ),
                  child: title,
                ),
              ),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: DefaultTextStyle.merge(
                    style: theme.textTheme.bodySmall!.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.4,
                    ),
                    child: subtitle!,
                  ),
                ),
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                spacing: spacing,
                children: children,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// An explicitly subordinate group, without another card or a disclosure arrow.
class EditorControlGroup extends StatelessWidget {
  final Widget title;
  final Widget? subtitle;
  final List<Widget> children;
  const EditorControlGroup({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
  });
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      DefaultTextStyle.merge(
        style: Theme.of(context).textTheme.labelLarge!.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        child: title,
      ),
      if (subtitle != null)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: DefaultTextStyle.merge(
            style: Theme.of(context).textTheme.bodySmall!,
            child: subtitle!,
          ),
        ),
      const SizedBox(height: 12),
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: 12,
        children: children,
      ),
    ],
  );
}

class EditorSlider extends StatelessWidget {
  final String label, valueLabel;
  final double value, min, max;
  final ValueChanged<double> onChanged;
  const EditorSlider({
    super.key,
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          const SizedBox(width: 12),
          Text(
            valueLabel,
            style: Theme.of(context).textTheme.labelMedium!.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
      Slider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        padding: const EdgeInsets.symmetric(vertical: 12),
        onChanged: onChanged,
      ),
    ],
  );
}
