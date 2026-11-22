import 'package:flutter/material.dart';
import '../model/project.dart';
import '../model/streetview_motion.dart';

class StreetviewCamera extends StatelessWidget {
  final ReelClip clip;
  final double seconds;
  final Widget child;
  const StreetviewCamera({
    super.key,
    required this.clip,
    required this.seconds,
    required this.child,
  });
  @override
  Widget build(BuildContext context) {
    return StreetviewCameraTransform(
      pose: StreetviewMotion.at(clip, seconds),
      child: child,
    );
  }
}

class StreetviewCameraTransform extends StatelessWidget {
  final StreetviewPose pose;
  final Widget child;
  const StreetviewCameraTransform({
    super.key,
    required this.pose,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Transform.translate(
        offset: Offset(pose.offsetX, 0),
        child: Transform.scale(
          scale: pose.scale,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, StreetviewPose.perspective)
              ..rotateY(pose.yaw),
            child: child,
          ),
        ),
      ),
    );
  }
}
