import 'package:flutter/material.dart';

import '../../../shared/charts/chart_data.dart';
import '../../../shared/charts/chart_panel.dart';
import '../../../shared/charts/chart_preference_store.dart';
import '../../../shared/charts/charts.dart';
import '../../auth/domain/principal.dart';
import '../data/prediction_api.dart';

/// Plan del paso 3: la evolución por cortes (`GET …/prediction/history`), que el móvil consume desde este paso
/// (decisión 9 de Manuel). La tarjeta de la estimación de hoy no cambia; estos gráficos van aparte. Eligen el tipo
/// `ADMINISTRATOR` y `REPRESENTATIVE` (los que ven la predicción, DD-43).
bool canChoosePredictionCharts(Iterable<String> roles) =>
    roles.contains(Principal.administrator) || roles.contains(Principal.representative);

String _pct(double v) => '${v.round()} %';
String _cut(PredictionCut c) => '${(c.t * 100).round()} % del tiempo';

/// Por corte: lo recaudado entonces (hecho) y el final que se estimaba (estimación). Sin cifra → `null`.
CategoryChartData cutsData(List<PredictionCut> cuts) => CategoryChartData(
  categories: [for (final c in cuts) _cut(c)],
  series: [
    ChartSeries(
      key: 'raised',
      label: 'Recaudado en el corte',
      nature: SeriesNature.fact,
      values: [for (final c in cuts) c.pctRaisedAtCut == null ? null : c.pctRaisedAtCut! * 100],
    ),
    ChartSeries(
      key: 'final',
      label: 'Final estimado en el corte',
      nature: SeriesNature.estimate,
      values: [for (final c in cuts) c.available ? c.estimatedFinalPctOfTarget! * 100 : null],
    ),
  ],
  format: _pct,
  unit: 'Corte',
);

CategoryChartData probabilityData(List<PredictionCut> cuts) => CategoryChartData(
  categories: [for (final c in cuts) _cut(c)],
  series: [
    ChartSeries(
      key: 'prob',
      label: 'Probabilidad de alcanzar la meta',
      nature: SeriesNature.estimate,
      values: [for (final c in cuts) c.available ? c.probabilityReachTarget! * 100 : null],
    ),
  ],
  format: _pct,
  unit: 'Corte',
);

CategoryChartData raisedData(List<PredictionCut> cuts) => CategoryChartData(
  categories: [for (final c in cuts) _cut(c)],
  series: [cutsData(cuts).series.first],
  format: _pct,
  unit: 'Corte',
);

class PredictionChartsPanel extends StatelessWidget {
  const PredictionChartsPanel({super.key, required this.cuts, required this.principal, required this.store});
  final List<PredictionCut> cuts;
  final Principal principal;
  final ChartPreferenceStore store;

  @override
  Widget build(BuildContext context) {
    const note = 'Un corte sin cifra queda vacío: no se rellena.';
    return ChartPanel(
      panel: ChartPanelId.prediction,
      canChoose: canChoosePredictionCharts(principal.roles),
      accountId: principal.accountId,
      store: store,
      simple: [
        ChartOption(
          'probBars',
          'Probabilidad por corte',
          (_) => VerticalBarsChart(data: probabilityData(cuts), testKey: 'prediction.probBars', caption: note),
        ),
        ChartOption(
          'probHBars',
          'Probabilidad por corte (horizontal)',
          (_) => HorizontalBarsChart(data: probabilityData(cuts), testKey: 'prediction.probHBars', caption: note),
        ),
        ChartOption(
          'raised',
          'Recaudado por corte',
          (_) => VerticalBarsChart(
            data: raisedData(cuts),
            testKey: 'prediction.raised',
            caption: 'Lo recaudado en cada corte, según el registro de eventos.',
          ),
        ),
      ],
      advanced: [
        ChartOption(
          'cuts',
          'Recaudado y final estimado por corte',
          (_) => ComboBarsLineChart(
            data: cutsData(cuts),
            testKey: 'prediction.cuts',
            caption:
                'Barras: lo recaudado en cada corte (hecho). Línea: el final que se estimaba entonces (estimación). $note',
          ),
        ),
        ChartOption(
          'probLine',
          'Probabilidad por corte (línea)',
          (_) => LineChartView(data: probabilityData(cuts), testKey: 'prediction.probLine', caption: note),
        ),
      ],
    );
  }
}
