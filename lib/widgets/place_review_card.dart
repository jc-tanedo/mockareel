import 'package:flutter/material.dart';
import '../model/project.dart';
import 'output_palette.dart';
import 'star_rating.dart';

class PlaceReviewCard extends StatelessWidget {
  final FeaturedReview review;
  final OutputPalette colors;

  const PlaceReviewCard({
    super.key,
    required this.review,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final author = review.author.trim();
    final initial = author.isEmpty
        ? '★'
        : String.fromCharCodes(author.runes.take(1)).toUpperCase();

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.reviewSurface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: const Color(0xffe97e16),
                child: Text(
                  initial,
                  style: const TextStyle(fontSize: 11, color: Colors.white),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      author.isEmpty ? 'Featured review' : author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: colors.text,
                        height: 1.2,
                      ),
                    ),
                    StarRating(
                      rating: review.rating.toDouble(),
                      size: 10,
                      color: const Color(0xffedb928),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Expanded(
            child: Text(
              review.text.trim(),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: colors.reviewText,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
