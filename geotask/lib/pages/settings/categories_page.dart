import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/categories_store.dart';
import '../../models/category.dart';
import '../../widgets/category_edit_sheet.dart';
import '../../widgets/empty_hint.dart';
import '../../widgets/palette_selector.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/app_card.dart';
import '../../theme/palette.dart';

/*
  Ficheiro: categories_page.dart
  Propósito: Gestão das categorias do utilizador — criar, editar, apagar e ordenar.

  Pontos importantes:
  - Mantém um buffer local para edição off-line; aplica alterações ao `CategoriesStore` quando o utilizador grava.
  - Fornece reordenação com `ReorderableListView` e validações contra nomes duplicados.
*/

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  final _nameCtrl = TextEditingController();
  
  // A palette foi movida para uma constante central para que possa ser utilizada em toda a app.
  int _selectedColor = appPalette.first.toARGB32();

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
      showAppSnackBar(context, 'Escreve um nome para a categoria.');
      return;
    }
    final exists =
        _buffer.any((c) => c.name.toLowerCase() == name.toLowerCase());
    if (exists) {
      showAppSnackBar(context, 'Já existe uma categoria com esse nome.');
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
    final result = await showModalBottomSheet<CategoryEditResult>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) {
        final bottom = MediaQuery.viewInsetsOf(sheetCtx).bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottom),
          child: CategoryEditSheet(initialName: c.name, initialColor: c.color, palette: appPalette),
        );
      },
    );
    if (result == null) return;
  if (!mounted) return;

    final dup = _buffer.any((x) =>
        x.id != c.id && x.name.toLowerCase() == result.name.toLowerCase());
    if (dup) {
      showAppSnackBar(context, 'Já existe uma categoria com esse nome.');
      return;
    }

  _buffer = _buffer.map((x) => x.id == c.id ? Category(id: x.id, name: result.name, color: result.color) : x).toList(growable: true);
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
    showAppSnackBar(context, 'Categorias guardadas.');
  }

  Future<void> _applyBufferToStore(CategoriesStore store) async {
    final current = List<Category>.from(store.items);

    // Remover
    for (final c in current) {
      if (!_buffer.any((b) => b.id == c.id)) {
        await store.remove(c.id);
      }
    }

    // Adicionar/Atualizar
    for (final b in _buffer) {
      final idx = current.indexWhere((c) => c.id == b.id);
      if (idx == -1) {
        await store.add(b.name, b.color);
      } else {
        final cur = current[idx];
        if (cur.name != b.name || cur.color != b.color) {
          await store.update(b.id, name: b.name, color: b.color);
        }
      }
    }

    // Reordenar para corresponder ao buffer (por id)
    for (int target = 0; target < _buffer.length; target++) {
      final id = _buffer[target].id;
      final currIndex = store.items.indexWhere((c) => c.id == id);
      if (currIndex != -1 && currIndex != target) {
        await store.reorder(currIndex, target);
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
                      PaletteSelector(
                        palette: appPalette,
                        selectedColor: _selectedColor,
                        onSelected: (c) => setState(() => _selectedColor = c),
                        itemSize: 40,
                        spacing: 12,
                      ),

                      const SizedBox(height: 16),

                      if (_buffer.isEmpty)
                        EmptyHint(
                          title: 'Sem categorias',
                          message: 'Nenhuma categoria encontrada. Crie uma para classificar as suas tarefas.',
                          onNew: _addLocal,
                        )
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
                              child: AppCard(
                                key: ValueKey('card_${c.id}'),
                                leading: CircleAvatar(backgroundColor: Color(c.color)),
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



enum _LeaveAction { cancel, discard, save }
