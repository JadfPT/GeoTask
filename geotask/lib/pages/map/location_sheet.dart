import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/task.dart';

class LocationSheet extends StatefulWidget {
  final List<Task> tasks;
  final LatLng? user;
  final ValueChanged<Task> onTapTask;

  const LocationSheet({
    super.key,
    required this.tasks,
    required this.user,
    required this.onTapTask,
  });

  @override
  State<LocationSheet> createState() => _LocationSheetState();
}

class _LocationSheetState extends State<LocationSheet> {
  final _ctrl = DraggableScrollableController();
  double _size = 0.0;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() {
      if (!mounted) return;
      setState(() => _size = _ctrl.size);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final h = MediaQuery.of(context).size.height;

    const peekPx = 32.0;                          // só a alça
    final minFrac = (peekPx / h).clamp(0.02, 0.07);
    final isPeek = _size == 0.0 || _size <= (minFrac + 0.002);

    final bgColor = isPeek ? Colors.transparent : cs.surfaceContainerHigh;
    final elev = isPeek ? 0.0 : 12.0;
    final radius =
        isPeek ? BorderRadius.zero : const BorderRadius.vertical(top: Radius.circular(18));

    // ✅ chave do problema: no peek tem de ser AlwaysScrollable
    final ScrollPhysics physics = isPeek
        ? const AlwaysScrollableScrollPhysics()
        : const ClampingScrollPhysics();

    return DraggableScrollableSheet(
      controller: _ctrl,
      minChildSize: minFrac,
      initialChildSize: minFrac,
      maxChildSize: 0.6,
      snap: true,
      builder: (context, scrollCtrl) {
        return Material(
          color: bgColor,
          elevation: elev,
          borderRadius: radius,
          child: ListView(
            controller: scrollCtrl,
            physics: physics,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            children: [
              const SizedBox(height: 8),
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              if (!isPeek) ..._buildOpenContent(context),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildOpenContent(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasContent = widget.tasks.isNotEmpty;
    final children = <Widget>[
      const SizedBox(height: 8),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
        child: Row(
          children: [
            Text(
              hasContent ? 'Locais (${widget.tasks.length})' : 'Locais',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const Spacer(),
            const Icon(Icons.expand_more, size: 18),
          ],
        ),
      ),
    ];

    if (hasContent) {
      for (var i = 0; i < widget.tasks.length; i++) {
        final t = widget.tasks[i];
        children.add(_TaskTile(
          task: t,
          distanceText: _formatDistance(widget.user, t.point),
          onTap: () => widget.onTapTask(t),
        ));
        if (i != widget.tasks.length - 1) {
          children.add(const SizedBox(height: 8));
        }
      }
    } else {
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.place_outlined, color: cs.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Sem locais com localização associada.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    children.add(const SizedBox(height: 12));
    return children;
  }

  String? _formatDistance(LatLng? a, LatLng? b) {
    if (a == null || b == null) return null;
    final d = Geolocator.distanceBetween(
      a.latitude, a.longitude, b.latitude, b.longitude,
    );
    if (d >= 1000) return '${(d / 1000).toStringAsFixed(1)} km';
    return '${d.toStringAsFixed(0)} m';
  }
}

class _TaskTile extends StatelessWidget {
  final Task task;
  final String? distanceText;
  final VoidCallback onTap;

  const _TaskTile({
    required this.task,
    required this.onTap,
    this.distanceText,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.place_outlined),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(task.title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (task.category != null)
                        Chip(
                          label: Text(task.category!),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      if (task.due != null)
                        _Pill(
                          icon: Icons.schedule,
                          text:
                              '${task.due!.day.toString().padLeft(2, '0')}/${task.due!.month.toString().padLeft(2, '0')} '
                              '${task.due!.hour.toString().padLeft(2, '0')}:${task.due!.minute.toString().padLeft(2, '0')}',
                        ),
                      if (distanceText != null)
                        _Pill(icon: Icons.social_distance, text: distanceText!),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Pill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 4),
          Text(text, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}
