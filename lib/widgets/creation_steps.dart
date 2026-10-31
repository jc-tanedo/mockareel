import 'package:flutter/material.dart';

class CreationSteps extends StatelessWidget {
  static const labels = ['Place', 'Timeline', 'Text', 'Audio', 'Export'];
  static const titles = [
    'Choose your place',
    'Arrange your media',
    'Add text & tags',
    'Choose your music',
    'Review & export',
  ];
  static const descriptions = [
    'Choose a place and shape its look.',
    'Arrange media, then fine-tune each clip.',
    'Optional · add and style text layers.',
    'Optional · choose a soundtrack.',
    'Check the preview and create your reel.',
  ];
  final int selected;
  final List<bool> completed;
  final ValueChanged<int> onSelected;
  final List<String> customLabels;
  final Set<int> optionalSteps;
  const CreationSteps({
    super.key,
    required this.selected,
    required this.completed,
    required this.onSelected,
    this.customLabels = labels,
    this.optionalSteps = const {2, 3},
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final count = customLabels.length;
    return Material(
      color: colors.surfaceContainerLow,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: colors.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'CREATE YOUR REEL',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 9,
                        letterSpacing: 1.3,
                        fontWeight: FontWeight.w600,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Tap any step',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 10,
                        color: colors.onSurfaceVariant.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    for (var i = 0; i < count; i++)
                      Expanded(
                        child: Semantics(
                          excludeSemantics: true,
                          onTap: () => onSelected(i),
                          label:
                              'Step ${i + 1} of $count, '
                              '${customLabels[i]}' +
                              (optionalSteps.contains(i)
                                  ? ', optional'
                                  : ''),
                          selected: selected == i,
                          button: true,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => onSelected(i),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Divider(
                                          color: i == 0
                                              ? Colors.transparent
                                              : (i <= selected ||
                                                    (i < completed.length &&
                                                        completed[i - 1]))
                                              ? colors.primary.withValues(
                                                  alpha: 0.45,
                                                )
                                              : colors.outlineVariant
                                                    .withValues(alpha: 0.5),
                                        ),
                                      ),
                                      AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 240,
                                        ),
                                        curve: Curves.easeOutBack,
                                        width: selected == i ? 34 : 24,
                                        height: 24,
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                        ),
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          color: selected == i
                                              ? colors.primary
                                              : (i < completed.length &&
                                                    completed[i])
                                              ? colors.secondaryContainer
                                              : colors.surfaceContainerHigh,
                                          border: Border.all(
                                            color: selected == i
                                                ? colors.primary
                                                : (i < completed.length &&
                                                      completed[i])
                                                ? colors.primary.withValues(
                                                    alpha: 0.5,
                                                  )
                                                : colors.outlineVariant,
                                          ),
                                        ),
                                        child:
                                            (i < completed.length &&
                                                    completed[i]) &&
                                                selected != i
                                            ? Icon(
                                                Icons.check,
                                                size: 14,
                                                color:
                                                    colors.onSecondaryContainer,
                                              )
                                            : Text(
                                                '${i + 1}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: selected == i
                                                      ? colors.onPrimary
                                                      : colors.onSurfaceVariant,
                                                ),
                                              ),
                                      ),
                                      Expanded(
                                        child: Divider(
                                          color: i == count - 1
                                              ? Colors.transparent
                                              : (i < selected ||
                                                    (i < completed.length &&
                                                        completed[i]))
                                              ? colors.primary.withValues(
                                                  alpha: 0.45,
                                                )
                                              : colors.outlineVariant
                                                    .withValues(alpha: 0.5),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    customLabels[i],
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: selected == i
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: selected == i
                                          ? colors.primary
                                          : colors.onSurfaceVariant,
                                    ),
                                  ),
                                  Text(
                                    optionalSteps.contains(i)
                                        ? 'Optional'
                                        : ' ',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: colors.onSurfaceVariant.withValues(
                                        alpha: 0.65,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CreationStepHeading extends StatelessWidget {
  final int step;
  final VoidCallback onNext;
  final List<String> stepLabels;
  final List<String> stepTitles;
  final List<String>? stepDescriptions;
  const CreationStepHeading({
    super.key,
    required this.step,
    required this.onNext,
    this.stepLabels = CreationSteps.labels,
    this.stepTitles = CreationSteps.titles,
    this.stepDescriptions = CreationSteps.descriptions,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final total = stepLabels.length;
    final description =
        stepDescriptions != null && step < stepDescriptions!.length
        ? stepDescriptions![step]
        : null;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          bottom: BorderSide(
            color: colors.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'STEP ${step + 1} OF $total',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 10,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w700,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    stepTitles[step],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: colors.onSurface,
                    ),
                  ),
                  if (description != null)
                    Text(
                      description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            if (step < total - 1)
              Tooltip(
                message: 'Next step: ${stepLabels[step + 1]}',
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                  ),
                  onPressed: onNext,
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: const Text('Next'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
