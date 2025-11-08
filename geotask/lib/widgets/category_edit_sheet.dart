import 'package:flutter/material.dart';
import 'palette_selector.dart';

/// Bottom sheet widget used to edit or create a category.
///
/// Returns a [CategoryEditResult] via `Navigator.pop` when the user saves.
class CategoryEditSheet extends StatefulWidget {
  final String initialName;
  final int initialColor;
  final List<Color> palette;

  const CategoryEditSheet({
    super.key,
    required this.initialName,
    required this.initialColor,
    required this.palette,
  });

  @override
  State<CategoryEditSheet> createState() => _CategoryEditSheetState();
}

class _CategoryEditSheetState extends State<CategoryEditSheet> {
  late final TextEditingController _ctrl = TextEditingController(text: widget.initialName);
  late int _color = widget.initialColor;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Editar categoria', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: _ctrl,
              decoration: const InputDecoration(labelText: 'Nome', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            PaletteSelector(
              palette: widget.palette,
              selectedColor: _color,
              onSelected: (c) => setState(() => _color = c),
              itemSize: 36,
              spacing: 12,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      final name = _ctrl.text.trim();
                      if (name.isEmpty) return;
                      Navigator.of(context).pop(CategoryEditResult(name: name, color: _color));
                    },
                    child: const Text('Guardar'),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8 + MediaQuery.viewPaddingOf(context).bottom),
          ],
        ),
      ),
    );
  }
}

class CategoryEditResult {
  final String name;
  final int color;
  CategoryEditResult({required this.name, required this.color});
}
