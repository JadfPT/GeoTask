import 'package:flutter/material.dart';
import 'app_snackbar.dart';
import '../models/category.dart';

/// Multi-seletor de categorias
/// - Mostra cores de cada categoria
/// - “Mostrar mais/menos” sem overflows (trunca por contagem)
class CategoriesMultiSelector extends StatefulWidget {
  final List<Category> items;
  final List<String> selectedIds;
  final ValueChanged<List<String>> onChanged;

  /// Nº de chips visíveis quando colapsado
  final int previewCount;

  /// Limite de seleção (ex.: 3)
  final int maxSelected;

  const CategoriesMultiSelector({
    super.key,
    required this.items,
    required this.selectedIds,
    required this.onChanged,
    this.previewCount = 6,
    this.maxSelected = 3,
  });

  @override
  State<CategoriesMultiSelector> createState() =>
      _CategoriesMultiSelectorState();
}

class _CategoriesMultiSelectorState extends State<CategoriesMultiSelector> {
  bool _expanded = false;

  void _toggle(String id) {
    final sel = [...widget.selectedIds];
    if (sel.contains(id)) {
      sel.remove(id);
      widget.onChanged(sel);
      return;
    }
    if (sel.length >= widget.maxSelected) {
      showAppSnackBar(context, 'Máximo de ${widget.maxSelected} categorias.');
      return;
    }
    sel.add(id);
    widget.onChanged(sel);
  }

  @override
  Widget build(BuildContext context) {
    final list = _expanded
        ? widget.items
        : widget.items.take(widget.previewCount).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: list.map((c) {
            final selected = widget.selectedIds.contains(c.id);
            final color = Color(c.color);
            final bg    = selected ? color.withValues(alpha: .22) : null;
            final border= selected ? BorderSide.none : BorderSide(color: color);

            return FilterChip(
              selected: selected,
              label: Text(c.name),
              onSelected: (_) => _toggle(c.id),
              showCheckmark: false,
              avatar: selected ? const Icon(Icons.check, size: 16) : null,
              selectedColor: bg,
              side: border,
              labelStyle: TextStyle(
                color: selected ? null : color, // cor do texto quando off
              ),
            );
          }).toList(),
        ),
        if (widget.items.length > widget.previewCount) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => setState(() => _expanded = !_expanded),
            icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
            label: Text(_expanded ? 'Mostrar menos' : 'Mostrar mais'),
          ),
        ],
      ],
    );
  }
}
