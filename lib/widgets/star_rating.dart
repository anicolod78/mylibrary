import 'package:flutter/material.dart';

/// Valutazione a stelle (0-5).
///
/// Se [onChanged] è fornito è interattiva: toccare una stella imposta il voto;
/// toccando la stella corrispondente al voto corrente lo azzera.
/// Se [onChanged] è null è in sola lettura.
class StarRating extends StatelessWidget {
  final int rating;
  final double size;
  final ValueChanged<int>? onChanged;
  final Color color;

  const StarRating({
    super.key,
    required this.rating,
    this.size = 24,
    this.onChanged,
    this.color = const Color(0xFFF5A623),
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < rating;
        final star = Icon(
          filled ? Icons.star : Icons.star_border,
          size: size,
          color: filled ? color : Colors.grey,
        );
        if (onChanged == null) return star;
        return InkResponse(
          onTap: () => onChanged!(rating == i + 1 ? 0 : i + 1),
          radius: size * 0.8,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: star,
          ),
        );
      }),
    );
  }
}
