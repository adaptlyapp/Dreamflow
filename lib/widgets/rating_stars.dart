import 'package:flutter/material.dart';
import 'package:wellspring/theme.dart';

/// A compact 5-star rating row with optional review count.
/// - Rounds to the nearest 0.5 star
/// - Shows filled/half/outline stars accordingly
/// - Optionally displays review count as "(123)" or "• 123 reviews"
class RatingStars extends StatelessWidget {
  final double rating; // 0..5
  final int? reviews;
  final double size;
  final Color color;
  final bool showCount;
  final bool dottedSeparator; // if true, uses • before count

  const RatingStars({
    super.key,
    required this.rating,
    this.reviews,
    this.size = 14,
    this.color = Colors.amber,
    this.showCount = true,
    this.dottedSeparator = false,
  });

  @override
  Widget build(BuildContext context) {
    final r = rating.clamp(0, 5);
    final halfRounded = (r * 2).round() / 2.0; // to nearest 0.5
    final full = halfRounded.floor();
    final hasHalf = (halfRounded - full) == 0.5;

    List<Widget> stars = [];
    for (int i = 0; i < 5; i++) {
      IconData icon;
      if (i < full) {
        icon = Icons.star;
      } else if (i == full && hasHalf) {
        icon = Icons.star_half;
      } else {
        icon = Icons.star_border;
      }
      stars.add(Icon(icon, size: size, color: color));
    }

    final showReviews = showCount && (reviews != null) && (reviews! > 0);
    final reviewText = (reviews ?? 0).toString();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...stars,
        if (showReviews) ...[
          SizedBox(width: 6),
          Text(
            dottedSeparator ? '\u2022 $reviewText' : '($reviewText)',
            style: context.textStyles.bodySmall,
          )
        ]
      ],
    );
  }
}
