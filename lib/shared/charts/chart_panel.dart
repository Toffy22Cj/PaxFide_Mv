import 'package:flutter/material.dart';

import 'chart_preference_store.dart';

/// Un tipo de gráfico que se puede elegir en un panel.
class ChartOption {
  const ChartOption(this.id, this.label, this.build);
  final String id;
  final String label;
  final WidgetBuilder build;
}

/// Plan del paso 3 (decisiones de Manuel del 2026-11-15 y del 2026-11-16): un gráfico simple y uno avanzado a la vez.
/// Solo los roles aprobados ven el selector («cada rol en lo que ya ve»); el resto, los predeterminados (el primero de
/// cada lista), aunque haya una elección guardada. El selector es presentación: el backend autoriza cada lectura.
class ChartPanel extends StatefulWidget {
  const ChartPanel({
    super.key,
    required this.panel,
    required this.simple,
    required this.advanced,
    required this.canChoose,
    required this.store,
    this.accountId,
  });

  final ChartPanelId panel;
  final List<ChartOption> simple;
  final List<ChartOption> advanced;
  final bool canChoose;
  final ChartPreferenceStore store;

  /// Identificador opaco de la cuenta (de `/me`); sin él no se guarda nada.
  final String? accountId;

  @override
  State<ChartPanel> createState() => _ChartPanelState();
}

class _ChartPanelState extends State<ChartPanel> {
  ChartChoice _choice = const ChartChoice();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ChartPanel old) {
    super.didUpdateWidget(old);
    if (old.accountId != widget.accountId || old.canChoose != widget.canChoose) _load();
  }

  Future<void> _load() async {
    final account = widget.accountId;
    if (!widget.canChoose || account == null) {
      if (mounted) setState(() => _choice = const ChartChoice());
      return;
    }
    final c = await widget.store.read(
      account,
      widget.panel,
      simple: [for (final o in widget.simple) o.id],
      advanced: [for (final o in widget.advanced) o.id],
    );
    if (mounted) setState(() => _choice = c);
  }

  ChartOption _pick(List<ChartOption> options, String? id) =>
      (widget.canChoose ? options.where((o) => o.id == id).firstOrNull : null) ?? options.first;

  void _select({String? simple, String? advanced}) {
    setState(() => _choice = _choice.copyWith(simple: simple, advanced: advanced));
    final account = widget.accountId;
    // Si no se puede guardar, la elección vale para esta sesión
    if (account != null) widget.store.write(account, widget.panel, _choice);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.simple.isEmpty || widget.advanced.isEmpty) return const SizedBox.shrink();
    final simple = _pick(widget.simple, _choice.simple);
    final advanced = _pick(widget.advanced, _choice.advanced);
    final prefix = 'charts.${widget.panel.name}';
    return Column(
      key: Key(prefix),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Slot(
          title: 'Gráfico simple',
          testKey: '$prefix.simple',
          options: widget.simple,
          selected: simple,
          canChoose: widget.canChoose,
          onSelect: (id) => _select(simple: id),
        ),
        const SizedBox(height: 16),
        _Slot(
          title: 'Gráfico avanzado',
          testKey: '$prefix.advanced',
          options: widget.advanced,
          selected: advanced,
          canChoose: widget.canChoose,
          onSelect: (id) => _select(advanced: id),
        ),
      ],
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({
    required this.title,
    required this.testKey,
    required this.options,
    required this.selected,
    required this.canChoose,
    required this.onSelect,
  });
  final String title;
  final String testKey;
  final List<ChartOption> options;
  final ChartOption selected;
  final bool canChoose;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      key: Key('$testKey.${selected.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('$title: ${selected.label}', style: theme.textTheme.titleSmall),
        if (canChoose && options.length > 1)
          // Ancho completo y texto recortado: a anchos de teléfono una etiqueta larga no desborda
          DropdownButton<String>(
            key: Key('$testKey.select'),
            value: selected.id,
            isDense: true,
            isExpanded: true,
            onChanged: (id) {
              if (id != null) onSelect(id);
            },
            items: [
              for (final o in options)
                DropdownMenuItem(
                  value: o.id,
                  child: Text(o.label, overflow: TextOverflow.ellipsis),
                ),
            ],
          ),
        const SizedBox(height: 8),
        selected.build(context),
      ],
    );
  }
}
