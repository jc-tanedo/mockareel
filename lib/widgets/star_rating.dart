import 'package:flutter/material.dart';

class StarRating extends StatelessWidget {
  final double rating;
  final int maxRating;
  final double size;
  final Color color;

  const StarRating({
    super.key,
    required this.rating,
    this.maxRating = 5,
    this.size = 12,
    this.color = const Color(0xffedb928),
  });

  @override
  Widget build(BuildContext context) {
    final rounded = rating.round();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        maxRating,
        (i) => Icon(
          i < rounded ? Icons.star : Icons.star_border,
          size: size,
          color: color,
        ),
      ),
    );
  }
}
