import 'package:flutter/material.dart';

/// A small horizontal palette selector used in the app for picking category
/// colors. It renders a horizontal list of circular color swatches and calls
/// [onSelected] with the color's ARGB32 integer when the user taps one.
class PaletteSelector extends StatelessWidget {
  final List<Color> palette;
  final int selectedColor;
  final ValueChanged<int> onSelected;
  final double itemSize;
  final double spacing;

  const PaletteSelector({
    super.key,
    required this.palette,
    required this.selectedColor,
    required this.onSelected,
    this.itemSize = 40,
    this.spacing = 12,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: itemSize,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: palette.length,
  separatorBuilder: (context, index) => SizedBox(width: spacing),
        itemBuilder: (context, i) {
          final color = palette[i];
          final selected = selectedColor == color.toARGB32();
          return GestureDetector(
            onTap: () => onSelected(color.toARGB32()),
            child: Container(
              width: itemSize,
              height: itemSize,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                  border: Border.all(
                  color: selected ? Colors.white : Colors.black.withValues(alpha: .15),
                  width: selected ? 3 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .08),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
