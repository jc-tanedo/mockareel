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
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: .55)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Theme(
          data: theme.copyWith(
            inputDecorationTheme: theme.inputDecorationTheme.copyWith(
              fillColor: colors.surfaceContainerHigh,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
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
                    letterSpacing: 0.1,
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        DefaultTextStyle.merge(
          style: theme.textTheme.labelLarge!.copyWith(
            color: colors.onSurface,
            fontWeight: FontWeight.w600,
          ),
          child: title,
        ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: DefaultTextStyle.merge(
              style: theme.textTheme.bodySmall!.copyWith(
                color: colors.onSurfaceVariant,
              ),
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: colors.secondaryContainer.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                valueLabel,
                style: theme.textTheme.labelMedium!.copyWith(
                  color: colors.onSecondaryContainer,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          padding: const EdgeInsets.symmetric(vertical: 10),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
