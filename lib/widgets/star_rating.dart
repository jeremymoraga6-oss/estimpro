import 'package:flutter/material.dart';
import '../theme.dart';

const _kGold = Color(0xFFFFD700);
const _kStarEmpty = Color(0xFFCCCCCC);

class StarRating extends StatelessWidget {
  final String label;
  final String icon;
  final int rating; // 1-4
  final ValueChanged<int> onRatingChange;

  const StarRating({
    super.key,
    required this.label,
    required this.icon,
    required this.rating,
    required this.onRatingChange,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 13, color: kCharcoal, fontWeight: FontWeight.w500)),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(4, (i) {
              final filled = i < rating;
              return GestureDetector(
                onTap: () => onRatingChange(i + 1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Icon(
                    filled ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: filled ? _kGold : _kStarEmpty,
                    size: 26,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 28,
            child: Text(
              '$rating/4',
              style: const TextStyle(fontSize: 11, color: kGrey, fontWeight: FontWeight.w600),
              textAlign: TextAlign.right,
            ),
          ),
        ]),
      );
}

/// Display-only row for result/PDF preview (no tap handler)
class StarDisplay extends StatelessWidget {
  final String label;
  final int rating;
  final bool compact;

  const StarDisplay({super.key, required this.label, required this.rating, this.compact = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.symmetric(vertical: compact ? 3 : 5),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: TextStyle(fontSize: compact ? 11 : 12, color: kGrey)),
          Row(mainAxisSize: MainAxisSize.min, children: [
            ...List.generate(4, (i) => Icon(
              i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
              color: i < rating ? _kGold : _kStarEmpty,
              size: compact ? 14 : 17,
            )),
            const SizedBox(width: 5),
            Text('$rating/4', style: TextStyle(fontSize: compact ? 10 : 11, fontWeight: FontWeight.w700, color: kCharcoal)),
          ]),
        ]),
      );
}
