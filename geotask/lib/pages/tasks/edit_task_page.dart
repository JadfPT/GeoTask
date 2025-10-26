import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/task_store.dart';
import '../../models/task.dart';
import '../../data/categories_store.dart';
import '../map/pick_location_page.dart';

class EditTaskPage extends StatefulWidget {
  final Task? initial;
  const EditTaskPage({super.key, this.initial});

  @override
  State<EditTaskPage> createState() => _EditTaskPageState();
}

class _EditTaskPageState extends State<EditTaskPage> {
  final _form = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  DateTime? _due;
  bool _linkLocation = false;
  LatLng? _point;
  double _radius = 150;

  /// Multiseleção de categorias (apenas UI; Task ainda não persiste categorias)
  final Set<String> _selectedCategoryIds = <String>{};

  @override
  void initState() {
    super.initState();
    final t = widget.initial;
    if (t != null) {
      _titleCtrl.text = t.title;
      _noteCtrl.text = t.note ?? '';
      _due = t.due;
      _linkLocation = t.point != null;
      _point = t.point;
      _radius = t.radiusMeters;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final base = _due ?? now;
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      initialDate: DateTime(base.year, base.month, base.day),
      helpText: 'Selecionar data',
    );
    if (date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
      helpText: 'Selecionar hora',
    );
    if (time == null) {
      setState(() => _due = DateTime(date.year, date.month, date.day));
      return;
    }
    setState(() => _due = DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _openPickLocation() async {
    final result = await context.push<PickLocationResult>(
      '/tasks/edit/pickLocation',
      extra: PickLocationArgs(initialPoint: _point, initialRadius: _radius),
    );
    if (result != null) {
      setState(() {
        _point = result.point;
        _radius = result.radius;
        _linkLocation = true;
      });
    }
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    final store = context.read<TaskStore>();
    final t = widget.initial;

    final updated = Task(
      id: t?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleCtrl.text.trim(),
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      due: _due,
      done: t?.done ?? false,
      point: _linkLocation ? _point : null,
      radiusMeters: _linkLocation ? _radius : (t?.radiusMeters ?? 150),
    );

    if (t == null) {
      store.add(updated);
    } else {
      store.update(updated);
    }
    Navigator.of(context).pop();
  }

  String _formatDue(DateTime d) {
    final dd = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$dd $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Editar tarefa' : 'Nova tarefa')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'Título'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _noteCtrl,
              decoration: const InputDecoration(labelText: 'Notas'),
              minLines: 3,
              maxLines: 5,
            ),
            const SizedBox(height: 18),

            // --------- Categoria (colapsável) ----------
            Text('Categoria', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _CategoriesMultiSelector(
              selectedIds: _selectedCategoryIds,
              maxSelected: 3,
              onChanged: (s) {
                setState(() {
                  _selectedCategoryIds
                    ..clear()
                    ..addAll(s);
                });
              },
            ),
            const SizedBox(height: 16),
            const Divider(),

            // --------- Data limite ----------
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: const Text('Data limite'),
              subtitle: Text(_due == null ? 'Sem data' : _formatDue(_due!)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_due != null)
                    IconButton(
                      tooltip: 'Limpar',
                      onPressed: () => setState(() => _due = null),
                      icon: const Icon(Icons.clear),
                    ),
                  IconButton(
                    tooltip: 'Escolher data e hora',
                    onPressed: _pickDateTime,
                    icon: const Icon(Icons.calendar_today_outlined),
                  ),
                ],
              ),
            ),
            const Divider(),
            const SizedBox(height: 4),

            // --------- Localização ----------
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _linkLocation,
              title: const Text('Associar localização'),
              subtitle: Text(_linkLocation ? 'Ativado' : 'Desativado'),
              onChanged: (v) {
                setState(() => _linkLocation = v);
                if (v) _openPickLocation();
              },
            ),
            if (_linkLocation) ...[
              Row(
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _openPickLocation,
                    icon: const Icon(Icons.place_outlined),
                    label: const Text('Escolher no mapa'),
                  ),
                  const SizedBox(width: 12),
                  if (_point != null)
                    Chip(
                      avatar: const Icon(Icons.radar, size: 18),
                      label: Text('${_radius.toStringAsFixed(0)} m'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}

/// ---------------------- CATEGORIES SELECTOR (colapsável) ----------------------
/// Mostra no máx. 2 linhas **e** no máx. [kCollapsedMaxChips] chips quando colapsado.
/// Mantém botão “Mostrar mais / menos”.

class _CategoriesMultiSelector extends StatefulWidget {
  final Set<String> selectedIds;
  final int maxSelected;
  final ValueChanged<Set<String>> onChanged;

  const _CategoriesMultiSelector({
    required this.selectedIds,
    required this.onChanged,
    this.maxSelected = 3,
  });

  @override
  State<_CategoriesMultiSelector> createState() => _CategoriesMultiSelectorState();
}

class _CategoriesMultiSelectorState extends State<_CategoriesMultiSelector> {
  String? _warning;
  bool _expanded = false;

  // Fácil de ajustar: quantos chips no máximo quando colapsado.
  static const int kCollapsedMaxChips = 6;
  static const int kCollapsedMaxLines = 2;

  void _toggle(String id) {
    final next = {...widget.selectedIds};
    if (next.contains(id)) {
      next.remove(id);
      _warning = null;
    } else {
      if (next.length >= widget.maxSelected) {
        _warning = 'Podes selecionar no máximo ${widget.maxSelected} categorias.';
      } else {
        next.add(id);
        _warning = null;
      }
    }
    widget.onChanged(next);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cats = context.watch<CategoriesStore>().items;

    return LayoutBuilder(builder: (context, constraints) {
      final maxWidth = constraints.maxWidth;
      const spacing = 10.0;

      // decide quais índices mostrar quando colapsado,
      // respeitando 2 linhas **e** máximo de chips
      final visible = <int>[];
      if (!_expanded) {
        var rowWidth = 0.0;
        var rows = 1;
        for (var i = 0; i < cats.length; i++) {
          if (visible.length >= kCollapsedMaxChips) break;

          final c = cats[i];
          final est = _estimateChipWidth(
            context,
            c.name,
            selected: widget.selectedIds.contains(c.id),
          );

          if (visible.isEmpty) {
            visible.add(i);
            rowWidth = est;
            continue;
          }

          if (rowWidth + spacing + est <= maxWidth) {
            visible.add(i);
            rowWidth += spacing + est;
          } else {
            rows += 1;
            if (rows > kCollapsedMaxLines) break;
            visible.add(i);
            rowWidth = est;
          }
        }
      }

      final toShow = _expanded ? List<int>.generate(cats.length, (i) => i) : visible;
      final hiddenCount = cats.length - toShow.length;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: spacing,
            runSpacing: 10,
            children: [
              for (final i in toShow)
                _CategoryChip(
                  id: cats[i].id,
                  label: cats[i].name,
                  color: Color(cats[i].color),
                  selected: widget.selectedIds.contains(cats[i].id),
                  onTap: () => _toggle(cats[i].id),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (hiddenCount > 0 || _expanded)
            TextButton.icon(
              onPressed: () => setState(() => _expanded = !_expanded),
              icon: Icon(_expanded ? Icons.unfold_less : Icons.unfold_more),
              label: Text(_expanded
                  ? 'Mostrar menos'
                  : 'Mostrar mais${hiddenCount > 0 ? ' ($hiddenCount)' : ''}'),
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
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
    });
  }

  double _estimateChipWidth(BuildContext context, String label, {required bool selected}) {
    final base = Theme.of(context).textTheme.labelLarge ?? const TextStyle(fontSize: 14);
    final style = selected ? base.copyWith(fontWeight: FontWeight.w600) : base;
    final tp = TextPainter(
      text: TextSpan(text: label, style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    return tp.width + 28; // texto + paddings/borda aproximados do FilterChip
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
