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
  const CreationSteps({
    super.key,
    required this.selected,
    required this.completed,
    required this.onSelected,
  });
  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xff202023),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Row(
              children: [
                Text(
                  'CREATE YOUR REEL',
                  style: TextStyle(
                    fontSize: 8,
                    letterSpacing: 1.4,
                    color: Colors.white54,
                  ),
                ),
                Spacer(),
                Text(
                  'Tap any step',
                  style: TextStyle(fontSize: 9, color: Colors.white38),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (var i = 0; i < labels.length; i++)
                  Expanded(
                    child: Semantics(
                      excludeSemantics: true,
                      onTap: () => onSelected(i),
                      label:
                          'Step ${i + 1} of 5, ${labels[i]}${i == 2 || i == 3 ? ', optional' : ''}',
                      selected: selected == i,
                      button: true,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
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
                                          : Colors.white12,
                                    ),
                                  ),
                                  Container(
                                    width: 23,
                                    height: 23,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: selected == i
                                          ? const Color(0xffb1a6ff)
                                          : Colors.transparent,
                                      border: Border.all(
                                        color: selected == i
                                            ? const Color(0xffb1a6ff)
                                            : completed[i]
                                            ? const Color(0xff79718f)
                                            : Colors.white24,
                                      ),
                                    ),
                                    child: completed[i] && selected != i
                                        ? const Icon(
                                            Icons.check,
                                            size: 13,
                                            color: Color(0xffb1a6ff),
                                          )
                                        : Text(
                                            '${i + 1}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: selected == i
                                                  ? const Color(0xff171719)
                                                  : Colors.white54,
                                            ),
                                          ),
                                  ),
                                  Expanded(
                                    child: Divider(
                                      color: i == 4
                                          ? Colors.transparent
                                          : Colors.white12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                labels[i],
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: selected == i
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: selected == i
                                      ? const Color(0xffd3ccff)
                                      : Colors.white60,
                                ),
                              ),
                              Text(
                                i == 2 || i == 3 ? 'Optional' : ' ',
                                style: const TextStyle(
                                  fontSize: 8,
                                  color: Colors.white30,
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
  );
}

class CreationStepHeading extends StatelessWidget {
  final int step;
  final VoidCallback onNext;
  const CreationStepHeading({
    super.key,
    required this.step,
    required this.onNext,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'STEP ${step + 1} OF 5',
                style: const TextStyle(
                  fontSize: 9,
                  letterSpacing: 1.5,
                  color: Color(0xffb1a6ff),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                CreationSteps.titles[step],
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                CreationSteps.descriptions[step],
                style: const TextStyle(fontSize: 11, color: Colors.white54),
              ),
            ],
          ),
        ),
        if (step < 4)
          Tooltip(
            message: 'Next step: ${CreationSteps.labels[step + 1]}',
            child: TextButton(
              onPressed: onNext,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Next'),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward, size: 17),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}
