import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../data/task_store.dart';
import '../../models/task.dart';
import '../map/pick_location_page.dart';

class EditTaskPage extends StatefulWidget {
  final Task? initial;
  const EditTaskPage({super.key, this.initial});

  @override
  State<EditTaskPage> createState() => _EditTaskPageState();
}

class _EditTaskPageState extends State<EditTaskPage> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController title =
      TextEditingController(text: widget.initial?.title ?? '');
  late final TextEditingController note =
      TextEditingController(text: widget.initial?.note ?? '');

  DateTime? _date;
  TimeOfDay? _time;
  String? _category;
  LatLng? _point;
  double _radius = 150;
  bool _useLocation = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial?.due != null) {
      _date = DateTime(initial!.due!.year, initial.due!.month, initial.due!.day);
      _time = TimeOfDay.fromDateTime(initial.due!);
    }
    _category = initial?.category;
    _point = initial?.point;
    _radius = initial?.radiusMeters ?? 150;
    _useLocation = initial?.point != null;
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<TaskStore>();
    final isEditing = widget.initial != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Editar tarefa' : 'Nova tarefa')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Título'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: note,
                  decoration: const InputDecoration(labelText: 'Notas'),
                  minLines: 2,
                  maxLines: 3,
                ),
                const SizedBox(height: 16),

                // Categoria
                DropdownButtonFormField<String>(
                  value: _category,
                  items: [
                    for (final c in store.categories)
                      DropdownMenuItem(value: c, child: Text(c)),
                  ],
                  onChanged: (v) => setState(() => _category = v),
                  decoration: const InputDecoration(labelText: 'Categoria'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => context.go('/settings'),
                      icon: const Icon(Icons.tune),
                      label: const Text('Gerir categorias'),
                    ),
                    const Spacer(),
                    if (_category != null)
                      TextButton(
                        onPressed: () => setState(() => _category = null),
                        child: const Text('Limpar'),
                      ),
                  ],
                ),

                const Divider(height: 32),

                // Data e Hora
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_outlined),
                  title: const Text('Data limite'),
                  subtitle: Text(_date == null
                      ? 'Sem data'
                      : '${_date!.day.toString().padLeft(2, '0')}/${_date!.month.toString().padLeft(2, '0')}/${_date!.year}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: _pickDate,
                  ),
                  onTap: _pickDate,
                ),
                if (_date != null)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.access_time),
                    title: const Text('Hora limite'),
                    subtitle:
                        Text(_time == null ? 'Sem hora' : _time!.format(context)),
                    trailing: IconButton(
                      icon: const Icon(Icons.schedule),
                      onPressed: _pickTime,
                    ),
                    onTap: _pickTime,
                  ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () =>
                          setState(() {
                            _date = null;
                            _time = null;
                          }),
                      icon: const Icon(Icons.clear),
                      label: const Text('Limpar data/hora'),
                    ),
                  ],
                ),

                const Divider(height: 32),

                // Localização
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Associar localização'),
                  subtitle: Text(_useLocation ? 'Ativado' : 'Desativado'),
                  value: _useLocation,
                  onChanged: (v) => setState(() => _useLocation = v),
                ),
                if (_useLocation)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final res =
                                await context.push<PickLocationResult>(
                              '/tasks/pick-location',
                              extra: PickLocationArgs(
                                initialPoint: _point,
                                initialRadius: _radius,
                              ),
                            );
                            if (res != null) {
                              setState(() {
                                _point = res.point;
                                _radius = res.radius;
                              });
                            }
                          },
                          icon: const Icon(Icons.place_outlined),
                          label: Text(
                            _point == null
                                ? 'Escolher no mapa'
                                : 'Editar localização',
                          ),
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _save(context),
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Guardar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _date ?? DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      initialDate: initial,
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? TimeOfDay.now(),
    );
    if (picked != null) setState(() => _time = picked);
  }

  void _save(BuildContext context) {
    if (!(_form.currentState?.validate() ?? false)) return;
    final store = context.read<TaskStore>();

    DateTime? due;
    if (_date != null) {
      final t = _time ?? const TimeOfDay(hour: 0, minute: 0);
      due = DateTime(_date!.year, _date!.month, _date!.day, t.hour, t.minute);
    }

    final task = (widget.initial == null)
        ? Task(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: title.text.trim(),
            note: note.text.trim().isEmpty ? null : note.text.trim(),
            due: due,
            category: _category,
            point: _useLocation ? _point : null,
            radiusMeters: _useLocation ? _radius : 150,
          )
        : widget.initial!.copyWith(
            title: title.text.trim(),
            note: note.text.trim().isEmpty ? null : note.text.trim(),
            due: due,
            category: _category,
            point: _useLocation ? _point : null,
            radiusMeters: _useLocation ? _radius : 150,
          );

    if (widget.initial == null) {
      store.add(task);
    } else {
      store.update(task);
    }
    context.pop();
  }
}
