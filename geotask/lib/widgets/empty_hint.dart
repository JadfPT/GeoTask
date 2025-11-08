import 'package:flutter/material.dart';

/// Reusable empty hint used across pages to show a small illustration and
/// explanatory text when a list is empty.
class EmptyHint extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onNew;

  const EmptyHint({super.key, required this.title, required this.message, this.onNew});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: cs.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          if (onNew != null) ...[
            const SizedBox(width: 12),
            OutlinedButton.icon(onPressed: onNew, icon: const Icon(Icons.add), label: const Text('Nova')),
          ]
        ],
      ),
    );
  }
}
