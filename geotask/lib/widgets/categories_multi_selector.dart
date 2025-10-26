import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/categories_store.dart';
import '../models/category.dart' as model;

/// Selector de categorias com:
///  - multi-seleção (toggle)
///  - limite máximo (default 3)
///  - aviso automático quando ultrapassa o limite
///
/// Usa Provider<CategoriesStore> para obter a lista de categorias.
/// A seleção vive fora do widget e é passada por `selectedIds`.
class CategoriesMultiSelector extends StatefulWidget {
  final Set<String> selectedIds;          // ids selecionados (externos)
  final int maxSelected;                  // limite (default 3)
  final ValueChanged<Set<String>> onChanged;

  const CategoriesMultiSelector({
    super.key,
    required this.selectedIds,
    required this.onChanged,
    this.maxSelected = 3,
  });

  @override
  State<CategoriesMultiSelector> createState() => _CategoriesMultiSelectorState();
}

class _CategoriesMultiSelectorState extends State<CategoriesMultiSelector> {
  String? _warning;

  void _toggle(String id) {
    final sel = {...widget.selectedIds};
    if (sel.contains(id)) {
      sel.remove(id);
      _warning = null;
    } else {
      if (sel.length >= widget.maxSelected) {
        _warning = 'Podes selecionar no máximo ${widget.maxSelected} categorias.';
      } else {
        sel.add(id);
        _warning = null;
      }
    }
    widget.onChanged(sel);
    setState(() {}); // para mostrar/ocultar o aviso
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CategoriesStore>();
    final cats = store.items;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final c in cats)
              _CategoryChip(
                id: c.id,
                label: c.name,
                color: Color(c.color),
                selected: widget.selectedIds.contains(c.id),
                onTap: () => _toggle(c.id),
              ),
          ],
        ),
        const SizedBox(height: 6),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _warning == null
              ? const SizedBox.shrink()
              : Padding(
                  key: const ValueKey('warn'),
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    _warning!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String id;
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.id,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      showCheckmark: true,
      onSelected: (_) => onTap(), // toggle
      checkmarkColor: color,
      selectedColor: color.withValues(alpha: .20),
      backgroundColor: color.withValues(alpha: .12),
      shape: StadiumBorder(side: BorderSide(color: color.withValues(alpha: .45))),
      labelStyle: TextStyle(
        color: selected ? color : null,
        fontWeight: selected ? FontWeight.w600 : null,
      ),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }
}
