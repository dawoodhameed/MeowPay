import 'package:flutter/material.dart';

import '../api/models.dart';
import 'cat_avatar.dart';

/// Horizontal row of selectable cats.
///
/// A row of tappable chips rather than a dropdown: with a handful of cats every
/// option and its balance is visible at once, where a dropdown hides them behind
/// a tap and shows one at a time.
class CatPicker extends StatelessWidget {
  const CatPicker({
    super.key,
    required this.cats,
    required this.selected,
    required this.onSelect,
    this.disabledId,
    this.showBalance = true,
  });

  final List<Cat> cats;
  final Cat? selected;
  final ValueChanged<Cat> onSelect;

  /// Excluded because a cat cannot send treats to itself. Shown greyed rather
  /// than removed, so the list does not reflow as the sender changes.
  final String? disabledId;
  final bool showBalance;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < cats.length; i++)
            Padding(
              padding: EdgeInsets.only(right: i == cats.length - 1 ? 0 : 8),
              child: _CatChip(
                cat: cats[i],
                colorIndex: i,
                isSelected: selected?.id == cats[i].id,
                isDisabled: cats[i].id == disabledId,
                showBalance: showBalance,
                onTap: () => onSelect(cats[i]),
              ),
            ),
        ],
      ),
    );
  }
}

class _CatChip extends StatelessWidget {
  const _CatChip({
    required this.cat,
    required this.colorIndex,
    required this.isSelected,
    required this.isDisabled,
    required this.showBalance,
    required this.onTap,
  });

  final Cat cat;
  final int colorIndex;
  final bool isSelected;
  final bool isDisabled;
  final bool showBalance;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = catColor(colorIndex);
    return Semantics(
      button: true,
      selected: isSelected,
      enabled: !isDisabled,
      label: showBalance ? '${cat.name}, ${cat.balance} treats' : cat.name,
      child: Opacity(
        opacity: isDisabled ? 0.35 : 1,
        child: Material(
          color: isSelected
              ? color.withValues(alpha: 0.12)
              : const Color(0xFF12151B),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: isDisabled ? null : onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? color.withValues(alpha: 0.5) : const Color(0xFF1E222B),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CatAvatar(name: cat.name, colorIndex: colorIndex, size: 28),
                  const SizedBox(width: 9),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        cat.name,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFFECEEF2),
                        ),
                      ),
                      if (showBalance)
                        Text(
                          '${cat.balance} treats',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF6F7889),
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
