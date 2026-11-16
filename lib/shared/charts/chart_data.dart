// Plan del paso 3 (encargo del 2026-11-15, Tarea B; aprobado por Manuel el 2026-11-16). Modelo común de los gráficos
// del móvil, el mismo que la web: categorías en el eje y series con un valor por categoría. Lógica pura: ningún
// gráfico inventa, interpola ni rellena; un valor ausente es `null` y se dibuja vacío.
import 'dart:math' as math;

/// `fact` = hecho registrado; `estimate` = estimación del modelo. Se dice en la leyenda y en la tabla.
enum SeriesNature { fact, estimate }

class ChartSeries {
  const ChartSeries({required this.key, required this.label, required this.values, this.nature});
  final String key;
  final String label;
  final List<double?> values;
  final SeriesNature? nature;

  String get labelWithNature => switch (nature) {
    SeriesNature.estimate => '$label (estimación)',
    SeriesNature.fact => '$label (hecho)',
    null => label,
  };
}

class CategoryChartData {
  const CategoryChartData({required this.categories, required this.series, required this.format, required this.unit});
  final List<String> categories;
  final List<ChartSeries> series;
  final String Function(double value) format;
  final String unit;

  Iterable<double> get values => series.expand((s) => s.values).whereType<double>().where((v) => v.isFinite);
  bool get isEmpty => categories.isEmpty || values.isEmpty;

  /// Suma por categoría de todas las series (barras apiladas); `null` si ninguna serie tiene dato.
  List<double?> get stackTotals => [
    for (var i = 0; i < categories.length; i++)
      () {
        final vs = series.map((s) => s.values[i]).whereType<double>().toList();
        return vs.isEmpty ? null : vs.fold<double>(0, (a, b) => a + b);
      }(),
  ];

  /// Una frase con todas las cifras, para el lector de pantalla (equivale al `aria-label` de la web).
  String describe() {
    if (isEmpty) return 'Sin datos para dibujar';
    return series
        .map(
          (s) =>
              '${s.label}: ${[for (var i = 0; i < categories.length; i++) '${categories[i]} ${s.values[i] == null ? 'sin dato' : format(s.values[i]!)}'].join(', ')}',
        )
        .join('. ');
  }
}

/// Máximo «redondo» del eje (1, 2, 2,5, 5 × 10^n) que contiene a [max]; 1 si no hay valores positivos.
double niceMax(double max) {
  if (!max.isFinite || max <= 0) return 1;
  final exp = math.pow(10, (math.log(max) / math.ln10).floor()).toDouble();
  for (final step in const [1.0, 2.0, 2.5, 5.0, 10.0]) {
    if (step * exp >= max) return step * exp;
  }
  return 10 * exp;
}

List<double> ticks(double top, [int n = 4]) => [for (var i = 0; i <= n; i++) top * i / n];

/// Acumulado de una serie (línea del combinado): sigue `null` mientras no hay datos.
List<double?> cumulative(List<double?> series) {
  double? acc;
  return [
    for (final v in series)
      () {
        if (v != null) acc = (acc ?? 0) + v;
        return acc;
      }(),
  ];
}

String percent(double fraction) => '${(fraction * 100).round()} %';
