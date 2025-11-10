import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../models/task.dart';
import '../../data/categories_store.dart';
import '../../widgets/category_chip.dart';
import '../../widgets/empty_hint.dart';

/*
  Ficheiro: location_sheet.dart
  Propósito: Componente em forma de folha (sheet) que lista locais/tarefas com localização.

  Nota académica:
  - Mostra resumo compacto de cada tarefa com categorias e permite seleccionar
    para centrar o mapa na tarefa.
  - O comportamento visual (peek / expand) é controlado por `DraggableScrollableSheet`.
*/

typedef TaskTap = void Function(Task);

class LocationSheet extends StatefulWidget {
  final List<Task> tasks;
  final LatLng? user;
  final TaskTap? onTapTask;

  const LocationSheet({
    super.key,
    required this.tasks,
    this.user,
    this.onTapTask,
  });

  @override
  State<LocationSheet> createState() => _LocationSheetState();
}

class _LocationSheetState extends State<LocationSheet> {
  double _extent = 0; // fração atual do sheet (0..1)

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // ---- Peek (fechado) encostado ao fundo: só a “peg” visível ----
    const kTopPad = 10.0; // padding superior da lista
    const kPegH   = 4.0;  // altura da barrinha
    const kGap    = 10.0; // espaço abaixo da barrinha
    final screenH     = MediaQuery.sizeOf(context).height;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    final peekPx   = kTopPad + kPegH + kGap + bottomInset;
    final minFrac  = (peekPx / screenH).clamp(0.02, 0.18);
    final initFrac = (minFrac + 0.012).clamp(minFrac, 0.25);

    // Opacidade do fundo: 0 quando fechado, 1 quando começa a abrir (~+5%)
    final fadeSpan = 0.05; // 5% do ecrã
    final opacity = ((_extent - minFrac) / fadeSpan).clamp(0.0, 1.0);

    final count = widget.tasks.length;

    return Align(
      alignment: Alignment.bottomCenter,
      child: DraggableScrollableSheet(
        expand: false,
        minChildSize: minFrac,
        initialChildSize: initFrac,
        maxChildSize: 0.55,
        builder: (ctx, controller) {
          return NotificationListener<DraggableScrollableNotification>(
            onNotification: (n) {
              setState(() => _extent = n.extent);
              return false;
            },
            child: DecoratedBox(
                decoration: BoxDecoration(
                // Fundo totalmente transparente quando fechado,
                // vai ficando opaco suavemente ao abrir.
                color: cs.surface.withValues(alpha: opacity),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  if (opacity > 0)
                    BoxShadow(
                      color: cs.shadow.withValues(alpha: .15 * opacity),
                      blurRadius: 12,
                      offset: const Offset(0, -2),
                    ),
                ],
              ),
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                child: ListView(
                  controller: controller,
                  padding:
                      EdgeInsets.fromLTRB(12, kTopPad, 12, 12 + bottomInset),
                  children: [
                    // Handle: cinzenta e bem visível quando fechado
                    Center(
                      child: Container(
                        width: 44,
                        height: kPegH,
                        decoration: BoxDecoration(
                          color: (opacity == 0)
                              ? Colors.grey.shade400.withValues(alpha: .95)
                              : cs.onSurfaceVariant.withValues(alpha: .85),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: kGap),

                    Row(
                      children: [
                        Text(
                          'Locais ($count)',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Spacer(),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (count == 0)
                      EmptyHint(
                        title: 'Sem locais',
                        message: 'Sem locais para mostrar. Associa uma localização a uma tarefa para aparecer aqui.',
                      )
                    else
                      ...widget.tasks.map((t) => _TaskRow(
                            task: t,
                            onTap: () => widget.onTapTask?.call(t),
                          )),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// Hint vazia substituída pelo widget compartilhado EmptyHint em lib/widgets/empty_hint.dart

class _TaskRow extends StatelessWidget {
  final Task task;
  final VoidCallback? onTap;

  const _TaskRow({required this.task, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.location_on_outlined, color: cs.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: -4,
                      children: [
                        for (final name in task.categoriesOrFallback)
                          CategoryChip(label: name, color: (() {
                            final items = context.read<CategoriesStore>().items;
                            final match = items.where((c) => c.name == name);
                            return match.isNotEmpty ? Color(match.first.color) : null;
                          })()),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
