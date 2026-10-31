import 'package:flutter/material.dart';
import '../model/project.dart';
import 'media_frame.dart';

class ClipStrip extends StatelessWidget {
  final ReelProject project;
  final int selectedIndex;
  final ValueChanged<int> onSelectClip;

  const ClipStrip({
    super.key,
    required this.project,
    required this.selectedIndex,
    required this.onSelectClip,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: 74,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: project.clips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final c = project.clips[i];
          final active = i == selectedIndex;
          return Semantics(
            label: 'Clip ${i + 1}: ${c.name}',
            selected: active,
            button: true,
            child: Tooltip(
              message: c.name,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => onSelectClip(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: (c.duration * 12).clamp(78, 150),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: active ? colors.primary : colors.outlineVariant,
                      width: active ? 2 : 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipPoster(clip: c),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black87],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 6,
                          top: 5,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: active ? colors.primary : Colors.black54,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${i + 1}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: active ? colors.onPrimary : Colors.white,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 6,
                          right: 4,
                          bottom: 5,
                          child: Text(
                            '${c.duration.toStringAsFixed(c.isGif ? 2 : 1)}s',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: active
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: active ? colors.primary : Colors.white70,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
