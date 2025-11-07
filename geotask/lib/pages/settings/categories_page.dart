import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/categories_store.dart';
import '../../models/category.dart';

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  final _nameCtrl = TextEditingController();

  static const _palette = <Color>[
    Color(0xFF7C4DFF),
    Color(0xFF536DFE),
    Color(0xFF26A69A),
    Color(0xFF00BCD4),
    Color(0xFFFF9800),
    Color(0xFFFFC107),
    Color(0xFF66BB6A),
    Color(0xFF8E24AA),
    Color(0xFF5C6BC0),
    Color(0xFF29B6F6),
    Color(0xFFFF7043),
    Color(0xFF9CCC65),
  ];

  int _selectedColor = _palette.first.toARGB32();

  List<Category> _buffer = const [];
  bool _hydrated = false;
  bool _dirty = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  // Só inicializa o buffer depois do store carregar.
  void _tryInitFromStore(CategoriesStore store) {
    if (_hydrated || !store.isLoaded) return;
    _buffer = store.items
        .map((c) => Category(id: c.id, name: c.name, color: c.color))
        .toList(growable: true);
    _hydrated = true;
  }

  void _markDirty() => setState(() => _dirty = true);

  void _addLocal() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escreve um nome para a categoria.')),
      );
      return;
    }
    final exists =
        _buffer.any((c) => c.name.toLowerCase() == name.toLowerCase());
    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Já existe uma categoria com esse nome.')),
      );
      return;
    }
    _buffer = [
      ..._buffer,
      Category(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        color: _selectedColor,
      ),
    ];
    _nameCtrl.clear();
    FocusScope.of(context).unfocus();
    _markDirty();
  }

  void _removeLocal(String id) {
    _buffer = _buffer.where((c) => c.id != id).toList(growable: true);
    _markDirty();
  }

  Future<void> _editLocal(Category c) async {
    final result = await showModalBottomSheet<_EditResult>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        final bottom = MediaQuery.viewInsetsOf(sheetCtx).bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottom),
          child: _EditSheet(
            initialName: c.name,
            initialColor: c.color,
            palette: _palette,
          ),
        );
      },
    );
  if (result == null) return;
  if (!mounted) return;

    final dup = _buffer.any((x) =>
        x.id != c.id && x.name.toLowerCase() == result.name.toLowerCase());
    if (dup) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Já existe uma categoria com esse nome.')),
      );
      return;
    }

    _buffer = _buffer
        .map((x) =>
            x.id == c.id ? Category(id: x.id, name: result.name, color: result.color) : x)
        .toList(growable: true);
    _markDirty();
  }

  void _reorderLocal(int oldIndex, int newIndex) {
    final list = [..._buffer];
    if (newIndex > oldIndex) newIndex -= 1;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    _buffer = list;
    _markDirty();
  }

  Future<bool> _confirmLeaveIfDirty() async {
    if (!_dirty) return true;
    final store = context.read<CategoriesStore>();
    final ok = await showDialog<_LeaveAction>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        title: const Text('Sair sem guardar?'),
        content: const Text(
            'Tens alterações por guardar. Queres descartar ou guardar agora?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(_LeaveAction.cancel),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(_LeaveAction.discard),
            child: const Text('Descartar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(_LeaveAction.save),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (ok == _LeaveAction.save) {
      await _applyBufferToStore(store);
      return true;
    }
    if (ok == _LeaveAction.discard) return true;
    return false;
  }

  Future<void> _save() async {
    final store = context.read<CategoriesStore>();
    await _applyBufferToStore(store);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Categorias guardadas.')),
    );
  }

  Future<void> _applyBufferToStore(CategoriesStore store) async {
    final current = List<Category>.from(store.items);

    // Remover
    for (final c in current) {
      if (!_buffer.any((b) => b.id == c.id)) {
        store.remove(c.id);
      }
    }

    // Adicionar/Atualizar
    for (final b in _buffer) {
      final idx = current.indexWhere((c) => c.id == b.id);
      if (idx == -1) {
        store.add(b.name, b.color);
      } else {
        final cur = current[idx];
        if (cur.name != b.name || cur.color != b.color) {
          store.update(b.id, name: b.name, color: b.color);
        }
      }
    }

    // Reordenar para corresponder ao buffer (por id)
    for (int target = 0; target < _buffer.length; target++) {
      final id = _buffer[target].id;
      final currIndex = store.items.indexWhere((c) => c.id == id);
      if (currIndex != -1 && currIndex != target) {
        store.reorder(currIndex, target);
      }
    }

    _dirty = false;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CategoriesStore>(
      builder: (context, store, child) {
        _tryInitFromStore(store);

        // WillPopScope is deprecated after Flutter 3.12; keep it for compatibility
        // and silence the linter for now.
        // ignore: deprecated_member_use
        return WillPopScope(
          onWillPop: _confirmLeaveIfDirty,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Categorias'),
              actions: [
                TextButton(
                  onPressed: _dirty ? _save : null,
                  child: Text(
                    'Guardar',
                    style: TextStyle(
                      color: _dirty
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outline,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            body: !store.isLoaded
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _nameCtrl,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _addLocal(),
                              decoration: const InputDecoration(
                                labelText: 'Nova categoria',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.icon(
                            onPressed: _addLocal,
                            icon: const Icon(Icons.add),
                            label: const Text('Adicionar'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Paleta
                      SizedBox(
                        height: 56,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _palette.length,
                          separatorBuilder: (context, index) => const SizedBox(width: 12),
                              itemBuilder: (context, i) {
                            final color = _palette[i];
                            final selected = _selectedColor == color.toARGB32();
                            return GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedColor = color.toARGB32()),
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: selected
                                        ? Colors.white
                                        : Colors.black.withValues(alpha: .15),
                                    width: selected ? 3 : 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: .15),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 16),

                      if (_buffer.isEmpty)
                        const _EmptyHint()
                      else
                        ReorderableListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          onReorder: _reorderLocal,
                          itemCount: _buffer.length,
                          itemBuilder: (context, index) {
                            final c = _buffer[index];
                            return Dismissible(
                              key: ValueKey('dismiss_${c.id}'),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .errorContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.delete_outline,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onErrorContainer,
                                ),
                              ),
                              onDismissed: (_) => _removeLocal(c.id),
                              child: Card(
                                key: ValueKey('card_${c.id}'),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Color(c.color),
                                  ),
                                  title: Text(c.name),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined),
                                        onPressed: () => _editLocal(c),
                                        tooltip: 'Editar',
                                      ),
                                      const SizedBox(width: 4),
                                      ReorderableDragStartListener(
                                        index: index,
                                        child: const Icon(Icons.drag_handle),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

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
              'Ainda não tens categorias. Escreve um nome, escolhe uma cor e toca em “Adicionar”.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditSheet extends StatefulWidget {
  final String initialName;
  final int initialColor;
  final List<Color> palette;

  const _EditSheet({
    required this.initialName,
    required this.initialColor,
    required this.palette,
  });

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initialName);
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
            Text('Editar categoria',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: _ctrl,
              decoration: const InputDecoration(
                labelText: 'Nome',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 56,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: widget.palette.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, i) {
                  final color = widget.palette[i];
                  final selected = _color == color.toARGB32();
                  return GestureDetector(
                    onTap: () => setState(() => _color = color.toARGB32()),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected
                              ? Colors.white
                              : Colors.black.withValues(alpha: .15),
                          width: selected ? 3 : 1,
                        ),
                      ),
                    ),
                  );
                },
              ),
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
                      Navigator.of(context).pop(
                        _EditResult(name: name, color: _color),
                      );
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

class _EditResult {
  final String name;
  final int color;
  _EditResult({required this.name, required this.color});
}

enum _LeaveAction { cancel, discard, save }
