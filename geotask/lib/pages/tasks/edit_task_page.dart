import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../data/categories_store.dart';
import '../../data/task_store.dart';
import '../../data/auth_store.dart';
import '../../models/task.dart';
import '../../widgets/categories_multi_selector.dart';
import '../../widgets/app_snackbar.dart';
import '../map/pick_location_page.dart'; // <-- IMPORT RESTAURADO

class EditTaskPage extends StatefulWidget {
  final Task? task;    // compat
  final Task? initial; // compat
  const EditTaskPage({super.key, this.task, this.initial});

  @override
  State<EditTaskPage> createState() => _EditTaskPageState();
}

class _EditTaskPageState extends State<EditTaskPage> {
  Task? get _t => widget.task ?? widget.initial;

  final _titleCtrl = TextEditingController();
  final _noteCtrl  = TextEditingController();

  DateTime? _due;
  double _radius = 150;
  LatLng? _point;
  bool _linkLocation = false;

  /// IDs das categorias selecionadas (máx. 3)
  final List<String> _selectedCategoryIds = [];

  @override
  void initState() {
    super.initState();
    final t = _t;
    if (t != null) {
      _titleCtrl.text = t.title;
      _noteCtrl.text  = t.note ?? '';
      _due            = t.due;
      _radius         = t.radiusMeters;
      _point          = t.point;
      _linkLocation   = t.point != null;

      // Pre-seleção (lista nova + legacy 1 categoria)
      final items = context.read<CategoriesStore>().items;
      final names = t.categoriesOrFallback;
      for (final n in names) {
        final m = items.where((c) => c.name == n);
        if (m.isNotEmpty) _selectedCategoryIds.add(m.first.id);
      }
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

Future<void> _pickLocation() async {
  final res = await Navigator.of(context).push<PickLocationResult>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => PickLocationPage(
        initialPoint: _point,
        initialRadius: _radius,
      ),
    ),
  );
  if (!mounted) return;
  if (res != null) {
    setState(() {
      _point = res.point;
      _radius = res.radius;
      _linkLocation = true;
    });
  }
}


  Future<void> _pickDue() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _due ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate:  now.add(const Duration(days: 365 * 5)),
    );
    if (d == null) return;
    if (!mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_due ?? now),
    );
    if (t == null) return;
    if (!mounted) return;
    setState(() {
      _due = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    });
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      showAppSnackBar(context, 'O título é obrigatório');
      return;
    }

    final catsStore = context.read<CategoriesStore>();
    final selectedNames = _selectedCategoryIds
        .map((id) => catsStore.items.firstWhere((c) => c.id == id).name)
        .toList();

    if (selectedNames.length > 3) {
      selectedNames.removeRange(3, selectedNames.length);
    }

    final t = _t;
    final updated = Task(
      id:   t?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      due:  _due,
      done: t?.done ?? false,
      categories: selectedNames,                 // novo
      category: selectedNames.isNotEmpty        // legacy (1ª)
          ? selectedNames.first
          : t?.category,
      point: _linkLocation ? _point : null,
      radiusMeters: _linkLocation ? _radius : (t?.radiusMeters ?? 150),
      ownerId: context.read<AuthStore>().currentUser?.id,
    );

    final store = context.read<TaskStore>();
    t == null ? store.add(updated) : store.update(updated);

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cats = context.watch<CategoriesStore>().items;

    return Scaffold(
      appBar: AppBar(
        title: Text(_t == null ? 'Nova tarefa' : 'Editar tarefa'),
        actions: [
          IconButton(icon: const Icon(Icons.save_outlined), onPressed: _save),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(
              labelText: 'Título',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _noteCtrl,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Descrição (opcional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            title: const Text('Data e hora'),
            subtitle: Text(
              _due != null
                  ? '${_due!.day.toString().padLeft(2, '0')}/${_due!.month.toString().padLeft(2, '0')} '
                    '${_due!.hour.toString().padLeft(2, '0')}:${_due!.minute.toString().padLeft(2, '0')}'
                  : 'Sem data',
            ),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: _pickDue,
          ),
          const Divider(),

          // Multi-seletor (cores + limite 3)
          CategoriesMultiSelector(
            items: cats,
            selectedIds: _selectedCategoryIds,
            onChanged: (sel) {
                if (sel.length > 3) {
                showAppSnackBar(context, 'Máximo de 3 categorias.');
                return;
              }
              setState(() {
                _selectedCategoryIds
                  ..clear()
                  ..addAll(sel);
              });
            },
            previewCount: 6,
            maxSelected: 3,
          ),

          const Divider(),
          SwitchListTile(
            title: const Text('Associar localização'),
            value: _linkLocation,
            onChanged: (v) => setState(() => _linkLocation = v),
          ),
          if (_linkLocation)
            ListTile(
              title: const Text('Escolher localização'),
              subtitle: Text(_point != null
                  ? 'Raio: ${_radius.toStringAsFixed(0)} m'
                  : 'Nenhuma selecionada'),
              trailing: const Icon(Icons.map_outlined),
              onTap: _pickLocation, // agora abre
            ),
        ],
      ),
    );
  }
}
