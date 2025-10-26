import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../data/categories_store.dart';
import '../../models/category.dart';

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  final _controller = TextEditingController();
  final _uuid = const Uuid();
  late List<Category> _local; // edição offline
  int _selectedColor = _palette.first;
  bool _dirty = false;

  static const _palette = <int>[
    0xFF7C4DFF, 0xFF536DFE, 0xFF26A69A, 0xFF00BCD4,
    0xFFFF9800, 0xFFFFC107, 0xFF66BB6A, 0xFF8E24AA,
    0xFF5C6BC0, 0xFF26C6DA,
  ];

  @override
  void initState() {
    super.initState();
    final store = context.read<CategoriesStore>();
    _local = List<Category>.from(store.items); // tipado -> sem List<dynamic>
    if (_local.isNotEmpty) _selectedColor = _local.first.color;
  }

  Future<void> _save() async {
    await context.read<CategoriesStore>().setAll(_local);
    if (!mounted) return;
    setState(() => _dirty = false);
    Navigator.pop(context);
  }

  Future<bool> _confirmExit() async {
    if (!_dirty) return true;
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sair sem guardar?'),
        content: const Text('Tens alterações por guardar.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sair')),
          FilledButton(onPressed: _save, child: const Text('Guardar')),
        ],
      ),
    );
    return res ?? false;
  }

  void _add() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _local.add(Category(id: _uuid.v4(), name: name, color: _selectedColor));
      _controller.clear();
      _dirty = true;
    });
  }

  void _remove(Category c) {
    setState(() {
      _local.removeWhere((e) => e.id == c.id);
      _dirty = true;
    });
  }

  Future<void> _rename(Category c) async {
    final ctrl = TextEditingController(text: c.name);
    final ok = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Renomear categoria'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('Guardar')),
        ],
      ),
    );
    if (ok == null || ok.isEmpty) return;
    setState(() {
      final i = _local.indexWhere((e) => e.id == c.id);
      if (i != -1) _local[i] = _local[i].copyWith(name: ok);
      _dirty = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final leave = await _confirmExit();
        if (leave && mounted) Navigator.pop(context);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Categorias'),
          actions: [
            TextButton(
              onPressed: _dirty ? _save : null,
              child: const Text('Guardar'),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(hintText: 'Nova categoria'),
                    onSubmitted: (_) => _add(),
                  ),
                ),
                const SizedBox(width: 12),
                // contra overflow em ecrãs pequenos
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 140),
                  child: FilledButton.icon(
                    onPressed: _add,
                    icon: const Icon(Icons.add),
                    label: const FittedBox(child: Text('Adicionar')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // paleta scrollável -> sem overflow
            SizedBox(
              height: 46,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _palette.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final color = _palette[i];
                  final selected = color == _selectedColor;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = color),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Color(color),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? Colors.white : Colors.black.withValues(alpha: .2),
                          width: selected ? 3 : 1,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _local.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex -= 1;
                  final item = _local.removeAt(oldIndex);
                  _local.insert(newIndex, item);
                  _dirty = true;
                });
              },
              itemBuilder: (_, i) {
                final c = _local[i];
                return Container(
                  key: ValueKey(c.id),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.drag_indicator),
                    title: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            color: Color(c.color),
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(child: Text(c.name)),
                      ],
                    ),
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        IconButton(
                          tooltip: 'Editar nome',
                          onPressed: () => _rename(c),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: 'Remover',
                          onPressed: () => _remove(c),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
