import 'package:flutter/material.dart';

/// Colours are assigned by the cat's position in the (sorted) list rather than by
/// hashing its name, so the visible set is always distinct. Hashing collides more
/// often than it looks over a handful of names, and two cats sharing a colour is
/// worse than none.
const _palette = <Color>[
  Color(0xFFFF7B66), // SadaPay coral
  Color(0xFF164A64), // steel
  Color(0xFF0E9F6E), // positive green
  Color(0xFF8C5BD8),
  Color(0xFFE08A2E),
];

Color catColor(int index) => _palette[index % _palette.length];

class CatAvatar extends StatelessWidget {
  const CatAvatar({
    super.key,
    required this.name,
    required this.colorIndex,
    this.size = 36,
  });

  final String name;
  final int colorIndex;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = catColor(colorIndex);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: Text(
        name.isEmpty ? '?' : name[0].toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
