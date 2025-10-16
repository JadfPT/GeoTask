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

  late final TextEditingController title;
  late final TextEditingController note;

  DateTime? due;
  LatLng? point;
  double radius = 150;

  @override
  void initState() {
    super.initState();
    title = TextEditingController(text: widget.initial?.title ?? '');
    note  = TextEditingController(text: widget.initial?.note ?? '');
    due   = widget.initial?.due;
    point = widget.initial?.point;
    radius = widget.initial?.radiusMeters ?? 150;
  }

  @override
  void dispose() {
    title.dispose();
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<TaskStore>();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initial == null ? 'Nova tarefa' : 'Editar tarefa'),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
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
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Data limite'),
              subtitle: Text(due?.toString() ?? 'Sem data'),
              trailing: IconButton(
                icon: const Icon(Icons.calendar_today),
                onPressed: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: now,
                    lastDate: now.add(const Duration(days: 365 * 3)),
                    initialDate: due ?? now,
                  );
                  if (picked != null) setState(() => due = picked);
                },
              ),
            ),
            const Divider(height: 24),

            // === Localização via mapa ===
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Associar localização'),
              value: point != null,
              onChanged: (v) async {
                if (v) {
                  final res = await context.push<PickLocationResult>(
                    '/map/pick',
                    extra: PickLocationArgs(
                      initialPoint: point,
                      initialRadius: radius,
                    ),
                  );
                  if (res != null) {
                    setState(() {
                      point = res.point;
                      radius = res.radius;
                    });
                  }
                } else {
                  setState(() {
                    point = null;
                  });
                }
              },
              subtitle: point == null
                  ? const Text('Desativado')
                  : Text(
                      'Lat: ${point!.latitude.toStringAsFixed(5)}, '
                      'Lng: ${point!.longitude.toStringAsFixed(5)}  •  '
                      'Raio: ${radius.round()} m',
                    ),
            ),
            if (point != null) ...[
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                onPressed: () async {
                  final res = await context.push<PickLocationResult>(
                    '/map/pick',
                    extra: PickLocationArgs(
                      initialPoint: point,
                      initialRadius: radius,
                    ),
                  );
                  if (res != null) {
                    setState(() {
                      point = res.point;
                      radius = res.radius;
                    });
                  }
                },
                icon: const Icon(Icons.edit_location_alt),
                label: const Text('Escolher no mapa'),
              ),
            ],

            const SizedBox(height: 20),
            FilledButton.icon(
              icon: const Icon(Icons.save),
              label: const Text('Guardar'),
              onPressed: () {
                if (!_form.currentState!.validate()) return;

                final base = widget.initial ??
                    Task(
                      id: DateTime.now()
                          .millisecondsSinceEpoch
                          .toString(),
                      title: title.text,
                    );

                // se tiveres Task.copyWith, usa-o; senão altera conforme o teu modelo
                final updated = base.copyWith(
                  title: title.text.trim(),
                  note: note.text.trim().isEmpty ? null : note.text.trim(),
                  due: due,
                  point: point,
                  radiusMeters: radius,
                );

                if (widget.initial == null) {
                  store.add(updated);
                } else {
                  store.update(updated);
                }
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}
