import 'package:flutter/material.dart';
import '../model/m3_motion.dart';

class _M3SpringCurve extends Curve {
  final M3Spring spring;
  const _M3SpringCurve(this.spring);

  @override
  double transformInternal(double t) => spring.eval(t);
}

/// Flutter [Curve] wrappers for Material 3 Expressive Spatial & Effects tokens.
abstract final class M3Curves {
  static const Curve fastSpatial = _M3SpringCurve(M3Motion.fastSpatial);
  static const Curve defaultSpatial = _M3SpringCurve(M3Motion.defaultSpatial);
  static const Curve slowSpatial = _M3SpringCurve(M3Motion.slowSpatial);

  static const Curve fastEffects = _M3SpringCurve(M3Motion.fastEffects);
  static const Curve defaultEffects = _M3SpringCurve(M3Motion.defaultEffects);
  static const Curve slowEffects = _M3SpringCurve(M3Motion.slowEffects);

  static double _eval(
    Animation<double> animation,
    Curve forward,
    Curve reverse,
  ) {
    final t = animation.value.clamp(0.0, 1.0);
    final curve = animation.status == AnimationStatus.reverse
        ? reverse.flipped
        : forward;
    return curve.transform(t);
  }

  /// Fade-and-slide transition without allocating per-build CurvedAnimations.
  static Widget fadeSlideTransition(
    Widget child,
    Animation<double> animation,
  ) => AnimatedBuilder(
    animation: animation,
    builder: (context, inner) {
      final opacity = _eval(
        animation,
        defaultEffects,
        fastEffects,
      ).clamp(0.0, 1.0);
      final slide = _eval(animation, fastSpatial, fastSpatial);
      return FractionalTranslation(
        translation: Offset(0, 0.025 * (1.0 - slide)),
        child: Opacity(opacity: opacity, child: inner),
      );
    },
    child: child,
  );
}

/// Material 3 Shared-Axis-X / Fade-Through page route transition.
class M3ExpressivePageTransitionsBuilder extends PageTransitionsBuilder {
  const M3ExpressivePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => AnimatedBuilder(
    animation: Listenable.merge([animation, secondaryAnimation]),
    builder: (context, inner) {
      final enterSlide = M3Curves._eval(
        animation,
        M3Curves.defaultSpatial,
        M3Curves.fastSpatial,
      );
      final enterFade = M3Curves._eval(
        animation,
        M3Curves.defaultEffects,
        M3Curves.fastEffects,
      );
      final exitSlide = M3Curves._eval(
        secondaryAnimation,
        M3Curves.defaultSpatial,
        M3Curves.defaultSpatial,
      );
      final exitFade = M3Curves._eval(
        secondaryAnimation,
        M3Curves.fastEffects,
        M3Curves.defaultEffects,
      );
      final inX = 24.0 * (1.0 - enterSlide);
      final outX = -16.0 * exitSlide;
      final opacity = (enterFade * (1.0 - 0.18 * exitFade)).clamp(0.0, 1.0);
      return Transform.translate(
        offset: Offset(inX + outX, 0),
        child: Opacity(opacity: opacity, child: inner),
      );
    },
    child: child,
  );
}
