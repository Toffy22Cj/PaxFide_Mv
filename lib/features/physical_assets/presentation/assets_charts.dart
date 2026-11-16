import 'package:flutter/material.dart';

import '../../../shared/charts/chart_data.dart';
import '../../../shared/charts/chart_panel.dart';
import '../../../shared/charts/chart_preference_store.dart';
import '../../../shared/charts/charts.dart';
import '../../auth/domain/principal.dart';
import '../data/physical_asset_api.dart';
import '../domain/asset_labels.dart';
import 'asset_screen.dart';

/// Plan del paso 3: el estado de los lotes en gráficos, con los mismos datos que la lista de «Mi día»
/// (`GET /organizations/{id}/physical-assets`). Se **cuentan lotes**: sus cantidades tienen unidades distintas y no
/// se suman. Eligen el tipo `ADMINISTRATOR` y `EMPLOYEE` (decisión de Manuel del 2026-11-15).
bool canChooseAssetCharts(Iterable<String> roles) =>
    roles.contains(Principal.administrator) || roles.contains(Principal.employee);

const lifecycleOrder = ['REGISTERED', 'DISPATCHED', 'RECEIVED', 'DELIVERED'];

String _lots(double v) => '${v.round()} ${v.round() == 1 ? 'lote' : 'lotes'}';

List<String> _states(List<PhysicalAssetDto> items) => [
  ...lifecycleOrder,
  ...({for (final a in items) a.lifecycleStatus}.where((s) => !lifecycleOrder.contains(s)).toList()..sort()),
];

CategoryChartData assetsByState(List<PhysicalAssetDto> items) {
  final states = _states(items);
  return CategoryChartData(
    categories: [for (final s in states) lifecycleLabel(s)],
    series: [
      ChartSeries(
        key: 'lots',
        label: 'Lotes',
        nature: SeriesNature.fact,
        values: [for (final s in states) items.where((a) => a.lifecycleStatus == s).length.toDouble()],
      ),
    ],
    format: _lots,
    unit: 'Estado',
  );
}

/// Apiladas: en cada estado, cuántos lotes de cada tipo; o al revés ([byType]).
CategoryChartData assetsStateByType(List<PhysicalAssetDto> items, {bool byType = false}) {
  final states = _states(items);
  final types = ({for (final a in items) assetTypeLabel(a.assetType)}.toList()..sort());
  double count(String s, String t) =>
      items.where((a) => a.lifecycleStatus == s && assetTypeLabel(a.assetType) == t).length.toDouble();
  return byType
      ? CategoryChartData(
          categories: types,
          series: [
            for (final s in states)
              ChartSeries(
                key: s,
                label: lifecycleLabel(s),
                nature: SeriesNature.fact,
                values: [for (final t in types) count(s, t)],
              ),
          ],
          format: _lots,
          unit: 'Tipo de lote',
        )
      : CategoryChartData(
          categories: [for (final s in states) lifecycleLabel(s)],
          series: [
            for (final t in types)
              ChartSeries(key: t, label: t, nature: SeriesNature.fact, values: [for (final s in states) count(s, t)]),
          ],
          format: _lots,
          unit: 'Estado',
        );
}

class AssetsChartsPanel extends StatelessWidget {
  const AssetsChartsPanel({super.key, required this.items, required this.principal, required this.store});
  final List<PhysicalAssetDto> items;
  final Principal principal;
  final ChartPreferenceStore store;

  @override
  Widget build(BuildContext context) {
    final byState = assetsByState(items);
    int count(String s) => items.where((a) => a.lifecycleStatus == s).length;
    final delivered = count('DELIVERED');
    final caption =
        '${items.length} ${items.length == 1 ? 'lote' : 'lotes'} de tu organización. Se cuentan lotes: sus cantidades tienen unidades distintas.';
    return ChartPanel(
      panel: ChartPanelId.assets,
      canChoose: canChooseAssetCharts(principal.roles),
      accountId: principal.accountId,
      store: store,
      simple: [
        ChartOption(
          'vbars',
          'Barras verticales',
          (_) => VerticalBarsChart(data: byState, testKey: 'assets.vbars', caption: caption),
        ),
        ChartOption(
          'hbars',
          'Barras horizontales',
          (_) => HorizontalBarsChart(data: byState, testKey: 'assets.hbars', caption: caption),
        ),
        ChartOption('donut', 'Dona', (_) => DonutChart(data: byState, testKey: 'assets.donut', caption: caption)),
        ChartOption(
          'progress',
          'Progreso de entrega',
          (_) => ProgressChart(
            label: 'Lotes entregados',
            part: delivered.toDouble(),
            total: items.length.toDouble(),
            format: _lots,
            testKey: 'assets.progress',
          ),
        ),
        ChartOption(
          'kpi',
          'Cifras clave',
          (_) => KpiTilesChart(
            testKey: 'assets.kpi',
            caption: caption,
            tiles: [
              ('Lotes', '${items.length}'),
              ('En bodega', '${count('REGISTERED') + count('RECEIVED')}'),
              ('En camino', '${count('DISPATCHED')}'),
              ('Entregados', '$delivered'),
            ],
          ),
        ),
      ],
      advanced: [
        ChartOption(
          'stateByType',
          'Estados por tipo de lote',
          (_) => StackedBarsChart(data: assetsStateByType(items), testKey: 'assets.stateByType', caption: caption),
        ),
        ChartOption(
          'typeByState',
          'Tipos de lote por estado',
          (_) => StackedBarsChart(
            data: assetsStateByType(items, byType: true),
            testKey: 'assets.typeByState',
            caption: caption,
          ),
        ),
      ],
    );
  }
}
