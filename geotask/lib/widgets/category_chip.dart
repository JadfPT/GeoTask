import 'package:flutter/material.dart';

/// Reusable category/label chip used across the app.
///
/// - If [color] is provided the chip shows a colored background (a faint
///   tint of the color) and uses a readable text color on top of it.
/// - When [color] is null the chip uses the theme's surface container and a
///   muted text/icon color (this matches previous plain-chip behaviour).
class CategoryChip extends StatelessWidget {
  final String label;
  final Color? color;
  final IconData icon;

  const CategoryChip({super.key, required this.label, this.color, this.icon = Icons.sell_outlined});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (color == null) {
      final bg = cs.surfaceContainerHighest;
      final fg = cs.onSurfaceVariant;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: cs.onSurface)),
        ]),
      );
    }

    // Colored variant: pick readable foreground on top of the color tint.
    final textColor = color!.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  final bg = color!.withValues(alpha: .18);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: textColor)),
      ]),
    );
  }
}
