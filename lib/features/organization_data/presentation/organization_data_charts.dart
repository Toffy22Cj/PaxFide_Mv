import 'package:flutter/material.dart';

import '../../../shared/charts/chart_data.dart';
import '../../../shared/charts/chart_panel.dart';
import '../../../shared/charts/chart_preference_store.dart';
import '../../../shared/charts/charts.dart';
import '../../../shared/money.dart';
import '../../auth/domain/principal.dart';
import '../data/organization_data_api.dart';

// Enmienda 6 de ADR-043 (E6-1 a E6-4). Lógica de datos pura, como la de predicción y lotes: nada se inventa ni se rellena;
// los meses vacíos llegan del backend en «0» y se dibujan en cero; un valor que falta es `null` y queda vacío.

const _months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

/// `"2026-07"` → `"jul 2026"`. Si no tiene esa forma, se deja tal cual.
String shortMonth(String month) {
  final m = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(month);
  if (m == null) return month;
  final i = int.parse(m.group(2)!) - 1;
  return i < 0 || i > 11 ? month : '${_months[i]} ${m.group(1)}';
}

/// Monedas con filas, la de más importe primero (como la web).
List<String> monthlyCurrencies(MonthlyFunds funds) {
  final totals = <String, double>{};
  for (final r in funds.items) {
    totals[r.currency] = (totals[r.currency] ?? 0) + (double.tryParse(r.clearedAmount) ?? 0);
  }
  final list = totals.entries.toList()
    ..sort((a, b) {
      final c = b.value.compareTo(a.value);
      return c != 0 ? c : a.key.compareTo(b.key);
    });
  return [for (final e in list) e.key];
}

/// Recaudado por mes en una moneda (unidades mínimas). Nunca se suman monedas distintas.
CategoryChartData monthlyData(MonthlyFunds funds, String currency) {
  final rows = funds.items.where((r) => r.currency == currency).toList();
  return CategoryChartData(
    categories: [for (final r in rows) shortMonth(r.month)],
    series: [
      ChartSeries(
        key: 'cleared',
        label: 'Recaudado en $currency',
        nature: SeriesNature.fact,
        values: [for (final r in rows) double.tryParse(r.clearedAmount)],
      ),
    ],
    format: (v) => formatMinorUnits('${v.round()}', currency),
    unit: 'Mes',
  );
}

/// Barras del mes y línea del acumulado de estos meses (hecho en las dos).
CategoryChartData monthlyCumulativeData(MonthlyFunds funds, String currency) {
  final base = monthlyData(funds, currency);
  return CategoryChartData(
    categories: base.categories,
    series: [
      base.series.first,
      ChartSeries(
        key: 'cumulative',
        label: 'Acumulado de estos ${base.categories.length} meses',
        nature: SeriesNature.fact,
        values: cumulative(base.series.first.values),
      ),
    ],
    format: base.format,
    unit: base.unit,
  );
}

const activityLabels = <String, String>{
  'ASSET_REGISTERED': 'Lote registrado',
  'ASSET_DISPATCHED': 'Lote despachado',
  'ASSET_RECEIVED': 'Lote recibido',
  'ASSET_DELIVERED': 'Lote entregado',
  'ASSET_SPLIT': 'Lote dividido',
  'FUNDS_CLEARED': 'Donación confirmada',
  'CAMPAIGN_CLOSED': 'Convocatoria cerrada',
  'BATCH_ANCHORED': 'Anclaje en blockchain',
};

String _events(double n) => '${n.round()} ${n.round() == 1 ? 'evento' : 'eventos'}';

List<String> _typesIn(List<ActivityEvent> events) => [
  for (final t in activityLabels.keys)
    if (events.any((e) => e.type == t)) t,
];

CategoryChartData activityByType(List<ActivityEvent> events) {
  final types = _typesIn(events);
  return CategoryChartData(
    categories: [for (final t in types) activityLabels[t]!],
    series: [
      ChartSeries(
        key: 'events',
        label: 'Eventos',
        nature: SeriesNature.fact,
        values: [for (final t in types) events.where((e) => e.type == t).length.toDouble()],
      ),
    ],
    format: _events,
    unit: 'Tipo de evento',
  );
}

/// El día `AAAA-MM-DD` de un instante en Bogotá (UTC-5, sin horario de verano), la zona con la que el backend cuenta los
/// meses de fondos.
String dayInBogota(DateTime instant) {
  final d = instant.toUtc().subtract(const Duration(hours: 5));
  return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class ActivityOverTime {
  const ActivityOverTime(this.data, {required this.weekly});
  final CategoryChartData data;
  final bool weekly;
}

String _dayLabel(DateTime day) => '${day.day} ${_months[day.month - 1]}';

/// Eventos por día (o por semana si los cargados abarcan más de 31 días), del más antiguo al más reciente. Entre el primero
/// y el último, un periodo sin eventos cuenta 0: entre los eventos cargados, ese día no hubo ninguno.
ActivityOverTime activityOverTime(List<ActivityEvent> events, {bool byType = false}) {
  if (events.isEmpty) {
    return ActivityOverTime(
      CategoryChartData(categories: const [], series: const [], format: _events, unit: 'Día'),
      weekly: false,
    );
  }
  DateTime dayOf(ActivityEvent e) => DateTime.parse('${dayInBogota(e.occurredAt)}T00:00:00Z');
  final days = events.map(dayOf).toList()..sort();
  final first = days.first, last = days.last;
  final weekly = last.difference(first).inDays > 31;
  final step = weekly ? 7 : 1;
  final buckets = <DateTime>[for (var t = first; !t.isAfter(last); t = t.add(Duration(days: step))) t];
  int bucketOf(ActivityEvent e) => dayOf(e).difference(first).inDays ~/ step;
  List<double?> countWhere(bool Function(ActivityEvent) pred) => [
    for (var b = 0; b < buckets.length; b++) events.where((e) => bucketOf(e) == b && pred(e)).length.toDouble(),
  ];
  final types = _typesIn(events);
  return ActivityOverTime(
    CategoryChartData(
      categories: [for (final t in buckets) weekly ? 'sem. ${_dayLabel(t)}' : _dayLabel(t)],
      series: byType
          ? [
              for (final t in types)
                ChartSeries(
                  key: t,
                  label: activityLabels[t]!,
                  nature: SeriesNature.fact,
                  values: countWhere((e) => e.type == t),
                ),
            ]
          : [ChartSeries(key: 'events', label: 'Eventos', nature: SeriesNature.fact, values: countWhere((_) => true))],
      format: _events,
      unit: weekly ? 'Semana' : 'Día',
    ),
    weekly: weekly,
  );
}

/// Los gráficos de fondos mensuales. Con más de una moneda, el selector de moneda es de quien ve el panel: nunca se suman.
class FundsChartsPanel extends StatefulWidget {
  const FundsChartsPanel({super.key, required this.funds, required this.principal, required this.store});
  final MonthlyFunds funds;
  final Principal principal;
  final ChartPreferenceStore store;

  @override
  State<FundsChartsPanel> createState() => _FundsChartsPanelState();
}

class _FundsChartsPanelState extends State<FundsChartsPanel> {
  String? _currency;

  @override
  Widget build(BuildContext context) {
    final currencies = monthlyCurrencies(widget.funds);
    if (currencies.isEmpty) {
      return const ChartEmpty(testKey: 'funds');
    }
    final currency = currencies.contains(_currency) ? _currency! : currencies.first;
    final data = monthlyData(widget.funds, currency);
    final combo = monthlyCumulativeData(widget.funds, currency);
    final caption =
        'Lo recibido por mes en $currency, en la hora de Bogotá. Un mes sin donaciones se dibuja en cero.'
        '${widget.funds.truncated ? ' Hay más meses de los que se muestran.' : ''}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (currencies.length > 1)
          Wrap(
            spacing: 8,
            children: [
              for (final c in currencies)
                ChoiceChip(
                  key: Key('funds.currency.$c'),
                  label: Text(c),
                  selected: c == currency,
                  onSelected: (_) => setState(() => _currency = c),
                ),
            ],
          ),
        ChartPanel(
          // Una moneda distinta es otro gráfico: se reconstruye para no arrastrar lo anterior
          key: ValueKey('funds-panel-$currency'),
          panel: ChartPanelId.funds,
          canChoose: widget.principal.choosesOrganizationCharts,
          accountId: widget.principal.accountId,
          store: widget.store,
          simple: [
            ChartOption(
              'vbars',
              'Barras verticales',
              (_) => VerticalBarsChart(data: data, testKey: 'funds.vbars', caption: caption),
            ),
            ChartOption(
              'hbars',
              'Barras horizontales',
              (_) => HorizontalBarsChart(data: data, testKey: 'funds.hbars', caption: caption),
            ),
            ChartOption(
              'line',
              'Líneas',
              (_) => LineChartView(data: data, testKey: 'funds.line', caption: caption),
            ),
          ],
          advanced: [
            ChartOption(
              'combo',
              'Mes y acumulado',
              (_) => ComboBarsLineChart(
                data: combo,
                testKey: 'funds.combo',
                caption: 'Barras: lo recibido en cada mes. Línea: lo acumulado en los meses que se ven. $caption',
              ),
            ),
            ChartOption(
              'area',
              'Área',
              (_) => LineChartView(data: data, testKey: 'funds.area', caption: caption, area: true),
            ),
          ],
        ),
      ],
    );
  }
}

/// Los gráficos de actividad (hasta 100 eventos). El `REPRESENTATIVE` ve los predeterminados, sin selector.
class ActivityChartsPanel extends StatelessWidget {
  const ActivityChartsPanel({super.key, required this.activity, required this.principal, required this.store});
  final OrganizationActivity activity;
  final Principal principal;
  final ChartPreferenceStore store;

  @override
  Widget build(BuildContext context) {
    final events = activity.events;
    final byType = activityByType(events);
    final scope =
        'Los ${events.length} eventos más recientes${activity.more ? ' (hay más; solo se cuentan estos)' : ''}.';
    final over = activityOverTime(events);
    final overByType = activityOverTime(events, byType: true);
    final unit = over.weekly ? 'semana' : 'día';
    int count(String t) => events.where((e) => e.type == t).length;
    return ChartPanel(
      panel: ChartPanelId.activity,
      canChoose: principal.choosesOrganizationCharts,
      accountId: principal.accountId,
      store: store,
      simple: [
        ChartOption(
          'hbars',
          'Barras horizontales',
          (_) => HorizontalBarsChart(data: byType, testKey: 'activity.hbars', caption: scope),
        ),
        ChartOption(
          'vbars',
          'Barras verticales',
          (_) => VerticalBarsChart(data: byType, testKey: 'activity.vbars', caption: scope),
        ),
        ChartOption('donut', 'Dona', (_) => DonutChart(data: byType, testKey: 'activity.donut', caption: scope)),
        ChartOption(
          'kpi',
          'Cifras clave',
          (_) => KpiTilesChart(
            testKey: 'activity.kpi',
            caption: scope,
            tiles: events.isEmpty
                ? const []
                : [
                    ('Eventos', '${events.length}'),
                    ('Lotes registrados', '${count('ASSET_REGISTERED')}'),
                    ('Lotes entregados', '${count('ASSET_DELIVERED')}'),
                    ('Donaciones confirmadas', '${count('FUNDS_CLEARED')}'),
                  ],
          ),
        ),
      ],
      advanced: [
        ChartOption(
          'line',
          'Eventos por $unit',
          (_) => LineChartView(data: over.data, testKey: 'activity.line', caption: scope),
        ),
        ChartOption(
          'stacked',
          'Eventos por $unit y tipo',
          (_) => StackedBarsChart(data: overByType.data, testKey: 'activity.stacked', caption: scope),
        ),
      ],
    );
  }
}
