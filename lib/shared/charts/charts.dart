import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'chart_data.dart';

// Plan del paso 3 (encargo del 2026-11-15, Tarea B; aprobado por Manuel el 2026-11-16). Componente base de gráficos
// del móvil con `CustomPaint`, sin librerías (ADR-043 A2/D12). Todos los tipos comparten el marco: leyenda, una
// etiqueta para el lector de pantalla con todas las cifras, la tabla equivalente («Ver los datos») y el estado vacío.
// Colores del `ColorScheme` (claro y oscuro); con más series que colores, rayado; las líneas cambian la forma del
// marcador: nunca solo el color distingue dos series. Un valor `null` se deja vacío; una línea se corta en el hueco.

const _paletteSize = 5;

Color seriesColor(ColorScheme s, int i) => [s.primary, s.tertiary, s.secondary, s.error, s.outline][i % _paletteSize];

/// Rayado a partir de la sexta serie.
bool seriesHatched(int i) => i >= _paletteSize;

void _fillRect(Canvas canvas, Rect r, Color color, bool hatched) {
  if (!hatched) {
    canvas.drawRect(r, Paint()..color = color);
    return;
  }
  canvas.save();
  canvas.clipRect(r);
  canvas.drawRect(r, Paint()..color = color.withValues(alpha: 0.18));
  final p = Paint()
    ..color = color
    ..strokeWidth = 1.6;
  for (var x = r.left - r.height; x < r.right; x += 6) {
    canvas.drawLine(Offset(x, r.bottom), Offset(x + r.height, r.top), p);
  }
  canvas.restore();
  canvas.drawRect(
    r,
    Paint()
      ..color = color
      ..style = PaintingStyle.stroke,
  );
}

void _marker(Canvas canvas, Offset c, int i, Color color, Color border) {
  final fill = Paint()..color = color;
  final stroke = Paint()
    ..color = border
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;
  final path = switch (i % 4) {
    0 => Path()..addOval(Rect.fromCircle(center: c, radius: 4.5)),
    1 => Path()..addRect(Rect.fromCenter(center: c, width: 8, height: 8)),
    2 =>
      Path()
        ..moveTo(c.dx, c.dy - 5)
        ..lineTo(c.dx + 5, c.dy + 4)
        ..lineTo(c.dx - 5, c.dy + 4)
        ..close(),
    _ =>
      Path()
        ..moveTo(c.dx, c.dy - 5)
        ..lineTo(c.dx + 5, c.dy)
        ..lineTo(c.dx, c.dy + 5)
        ..lineTo(c.dx - 5, c.dy)
        ..close(),
  };
  canvas
    ..drawPath(path, fill)
    ..drawPath(path, stroke);
}

TextPainter _text(String s, TextStyle style, {double maxWidth = double.infinity}) => TextPainter(
  text: TextSpan(text: s, style: style),
  textDirection: TextDirection.ltr,
  maxLines: 1,
  ellipsis: '…',
)..layout(maxWidth: maxWidth);

// ---------------------------------------------------------------------------------------------------------------
// Marco común

class LegendItem {
  const LegendItem(this.label, this.index, {this.line = false});
  final String label;
  final int index;
  final bool line;
}

class _Legend extends StatelessWidget {
  const _Legend(this.items);
  final List<LegendItem> items;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 14,
      runSpacing: 4,
      children: [
        for (final it in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 16, height: 16, child: CustomPaint(painter: _SwatchPainter(it.index, it.line, scheme))),
              const SizedBox(width: 6),
              Flexible(child: Text(it.label, style: Theme.of(context).textTheme.bodySmall)),
            ],
          ),
      ],
    );
  }
}

class _SwatchPainter extends CustomPainter {
  _SwatchPainter(this.index, this.line, this.scheme);
  final int index;
  final bool line;
  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    final c = seriesColor(scheme, index);
    if (line) {
      canvas.drawLine(
        Offset(1, size.height / 2),
        Offset(size.width - 1, size.height / 2),
        Paint()
          ..color = c
          ..strokeWidth = 2,
      );
      _marker(canvas, size.center(Offset.zero), index, c, scheme.surface);
    } else {
      _fillRect(canvas, const Rect.fromLTWH(2, 2, 12, 12), c, seriesHatched(index));
    }
  }

  @override
  bool shouldRepaint(_SwatchPainter old) => old.index != index || old.scheme != scheme;
}

/// Tabla con los mismos datos que el gráfico (equivalente accesible y para comprobar las cifras).
class ChartDataTable extends StatelessWidget {
  const ChartDataTable({super.key, required this.data, required this.testKey});
  final CategoryChartData data;
  final String testKey;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    return ExpansionTile(
      key: Key('$testKey.table'),
      tilePadding: EdgeInsets.zero,
      title: Text('Ver los datos', style: Theme.of(context).textTheme.bodyMedium),
      children: [
        Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          children: [
            TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.all(4),
                  child: Text(data.unit, style: style?.copyWith(fontWeight: FontWeight.w700)),
                ),
                for (final s in data.series)
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: Text(s.labelWithNature, style: style?.copyWith(fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
            for (var i = 0; i < data.categories.length; i++)
              TableRow(
                key: ValueKey('$testKey.row.$i'),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: Text(data.categories[i], style: style),
                  ),
                  for (final s in data.series)
                    Padding(
                      padding: const EdgeInsets.all(4),
                      child: Text(s.values[i] == null ? 'Sin dato' : data.format(s.values[i]!), style: style),
                    ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class ChartEmpty extends StatelessWidget {
  const ChartEmpty({super.key, required this.testKey});
  final String testKey;

  @override
  Widget build(BuildContext context) => Padding(
    key: Key('$testKey.empty'),
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Text(
      'No hay datos para dibujar este gráfico.',
      textAlign: TextAlign.center,
      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
    ),
  );
}

class _Frame extends StatelessWidget {
  const _Frame({
    required this.data,
    required this.testKey,
    required this.label,
    required this.legend,
    required this.painter,
    this.height = 220,
    this.caption,
  });
  final CategoryChartData data;
  final String testKey;
  final String label;
  final List<LegendItem> legend;
  final CustomPainter painter;
  final double height;
  final String? caption;

  @override
  Widget build(BuildContext context) => Column(
    key: Key(testKey),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (legend.isNotEmpty) ...[_Legend(legend), const SizedBox(height: 8)],
      Semantics(
        key: Key('$testKey.chart'),
        container: true,
        image: true,
        label: label,
        child: ExcludeSemantics(
          child: SizedBox(
            height: height,
            child: CustomPaint(painter: painter),
          ),
        ),
      ),
      if (caption != null) ...[const SizedBox(height: 6), Text(caption!, style: Theme.of(context).textTheme.bodySmall)],
      ChartDataTable(data: data, testKey: testKey),
    ],
  );
}

// ---------------------------------------------------------------------------------------------------------------
// Ejes

class _Axes {
  _Axes(this.size, this.top, this.format, TextStyle style)
    : labels = [for (final t in ticks(top)) _text(format(t), style)] {
    left = math.min(size.width * 0.4, labels.map((l) => l.width).fold<double>(0, math.max) + 8);
  }
  final Size size;
  final double top;
  final String Function(double) format;
  final List<TextPainter> labels;
  late final double left;
  static const right = 6.0, topPad = 8.0, bottom = 22.0;

  double get plotW => size.width - left - right;
  double get plotH => size.height - topPad - bottom;
  double y(double v) => topPad + (1 - v / top) * plotH;

  void paint(Canvas canvas, Color grid) {
    final ts = ticks(top);
    for (var i = 0; i < ts.length; i++) {
      final yy = y(ts[i]);
      canvas.drawLine(Offset(left, yy), Offset(size.width - right, yy), Paint()..color = grid);
      labels[i].paint(canvas, Offset(left - 4 - labels[i].width, yy - labels[i].height / 2));
    }
  }

  void categories(Canvas canvas, List<String> cats, double Function(int) x, TextStyle style) {
    final every = math.max(1, (cats.length / 6).ceil());
    for (var i = 0; i < cats.length; i += every) {
      final t = _text(cats[i], style, maxWidth: plotW / math.min(cats.length, 6));
      t.paint(canvas, Offset(x(i) - t.width / 2, size.height - bottom + 4));
    }
  }
}

/// El texto de los ejes hereda la fuente del tema (y su escala); solo cambian el tamaño y el color.
TextStyle _axisStyle(ColorScheme s, TextStyle base) => base.copyWith(fontSize: 10, color: s.onSurfaceVariant);

TextStyle _baseText(BuildContext context) => Theme.of(context).textTheme.bodySmall ?? const TextStyle();

// ---------------------------------------------------------------------------------------------------------------
// Tipos

class _BarsPainter extends CustomPainter {
  _BarsPainter(this.data, this.scheme, this.base, {this.stacked = false});
  final CategoryChartData data;
  final ColorScheme scheme;
  final TextStyle base;
  final bool stacked;

  @override
  void paint(Canvas canvas, Size size) {
    final style = _axisStyle(scheme, base);
    final top = axisTop(stacked ? data.stackTotals.whereType<double>() : data.values);
    final ax = _Axes(size, top, data.format, style)..paint(canvas, scheme.outlineVariant);
    final band = ax.plotW / data.categories.length;
    double cx(int i) => ax.left + band * (i + 0.5);
    final n = data.series.length;
    for (var i = 0; i < data.categories.length; i++) {
      if (stacked) {
        final bw = math.max(4.0, math.min(36.0, band * 0.6));
        var acc = 0.0;
        for (var si = 0; si < n; si++) {
          final v = data.series[si].values[i];
          if (v == null || v <= 0) continue;
          _fillRect(
            canvas,
            Rect.fromLTRB(cx(i) - bw / 2, ax.y(acc + v), cx(i) + bw / 2, ax.y(acc)),
            seriesColor(scheme, si),
            seriesHatched(si),
          );
          acc += v;
        }
      } else {
        final bw = math.max(2.0, math.min(26.0, band * 0.7 / n));
        for (var si = 0; si < n; si++) {
          final v = data.series[si].values[i];
          if (v == null) continue;
          final x0 = cx(i) - n * bw / 2 + si * bw;
          _fillRect(canvas, Rect.fromLTRB(x0, ax.y(v), x0 + bw, ax.y(0)), seriesColor(scheme, si), seriesHatched(si));
        }
      }
    }
    canvas.drawLine(
      Offset(ax.left, ax.y(0)),
      Offset(size.width - _Axes.right, ax.y(0)),
      Paint()..color = scheme.onSurfaceVariant,
    );
    ax.categories(canvas, data.categories, cx, style);
  }

  @override
  bool shouldRepaint(_BarsPainter old) => old.data != data || old.scheme != scheme;
}

class _HBarsPainter extends CustomPainter {
  _HBarsPainter(this.data, this.scheme, this.base);
  final CategoryChartData data;
  final ColorScheme scheme;
  final TextStyle base;

  @override
  void paint(Canvas canvas, Size size) {
    final style = _axisStyle(scheme, base);
    final strong = style.copyWith(color: scheme.onSurface, fontWeight: FontWeight.w600);
    final n = data.series.length;
    final row = 14.0 * n + 14;
    final left = math.min(
      size.width * 0.35,
      data.categories.map((c) => _text(c, strong).width).fold<double>(0, math.max) + 8,
    );
    const right = 90.0;
    final top = axisTop(data.values);
    double x(double v) => left + v / top * (size.width - left - right);
    for (var i = 0; i < data.categories.length; i++) {
      final t = _text(data.categories[i], strong, maxWidth: left - 8);
      t.paint(canvas, Offset(left - 8 - t.width, i * row + row / 2 - t.height / 2));
      for (var si = 0; si < n; si++) {
        final v = data.series[si].values[i];
        final yy = i * row + 7 + si * 14.0;
        if (v == null) {
          _text('Sin dato', style).paint(canvas, Offset(left + 4, yy));
          continue;
        }
        _fillRect(
          canvas,
          Rect.fromLTRB(left, yy, math.max(left + 1, x(v)), yy + 11),
          seriesColor(scheme, si),
          seriesHatched(si),
        );
        _text(data.format(v), style).paint(canvas, Offset(x(v) + 4, yy - 1));
      }
    }
    canvas.drawLine(
      Offset(left, 0),
      Offset(left, data.categories.length * row),
      Paint()..color = scheme.onSurfaceVariant,
    );
  }

  @override
  bool shouldRepaint(_HBarsPainter old) => old.data != data || old.scheme != scheme;
}

class _LinePainter extends CustomPainter {
  _LinePainter(this.data, this.scheme, this.base, {this.area = false});
  final CategoryChartData data;
  final ColorScheme scheme;
  final TextStyle base;
  final bool area;

  @override
  void paint(Canvas canvas, Size size) {
    final style = _axisStyle(scheme, base);
    final ax = _Axes(size, axisTop(data.values), data.format, style)..paint(canvas, scheme.outlineVariant);
    final n = data.categories.length;
    double cx(int i) => n == 1 ? ax.left + ax.plotW / 2 : ax.left + i / (n - 1) * ax.plotW;
    for (var si = 0; si < data.series.length; si++) {
      final color = seriesColor(scheme, si);
      // Tramos sin huecos: un `null` corta la línea
      final segments = <List<int>>[[]];
      for (var i = 0; i < n; i++) {
        if (data.series[si].values[i] == null) {
          if (segments.last.isNotEmpty) segments.add([]);
        } else {
          segments.last.add(i);
        }
      }
      for (final seg in segments.where((s) => s.isNotEmpty)) {
        Offset pt(int i) => Offset(cx(i), ax.y(data.series[si].values[i]!));
        if (seg.length > 1) {
          final path = Path()..moveTo(pt(seg.first).dx, pt(seg.first).dy);
          for (final i in seg.skip(1)) {
            path.lineTo(pt(i).dx, pt(i).dy);
          }
          if (area) {
            final fill = Path.from(path)
              ..lineTo(cx(seg.last), ax.y(0))
              ..lineTo(cx(seg.first), ax.y(0))
              ..close();
            canvas.drawPath(fill, Paint()..color = color.withValues(alpha: 0.25));
          }
          canvas.drawPath(
            path,
            Paint()
              ..color = color
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
          );
        }
        for (final i in seg) {
          _marker(canvas, pt(i), si, color, scheme.surface);
        }
      }
    }
    canvas.drawLine(
      Offset(ax.left, ax.y(0)),
      Offset(size.width - _Axes.right, ax.y(0)),
      Paint()..color = scheme.onSurfaceVariant,
    );
    ax.categories(canvas, data.categories, cx, style);
  }

  @override
  bool shouldRepaint(_LinePainter old) => old.data != data || old.scheme != scheme;
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.values, this.total, this.centerText, this.scheme, this.base);
  final TextStyle base;
  final List<double> values;
  final double total;
  final String centerText;
  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = math.min(size.width, size.height) / 2 - 4;
    final stroke = r * 0.38;
    var a = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] / total * 2 * math.pi;
      if (sweep <= 0) continue;
      final paint = Paint()
        ..color = seriesColor(scheme, i).withValues(alpha: seriesHatched(i) ? 0.45 : 1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke;
      canvas.drawArc(Rect.fromCircle(center: c, radius: r - stroke / 2), a, sweep, false, paint);
      a += sweep;
    }
    final t = _text(centerText, base.copyWith(fontSize: 13, fontWeight: FontWeight.w700, color: scheme.onSurface));
    t.paint(canvas, c - Offset(t.width / 2, t.height / 2));
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.values != values || old.scheme != scheme;
}

class _ComboPainter extends CustomPainter {
  _ComboPainter(this.data, this.scheme, this.base);
  final CategoryChartData data;
  final ColorScheme scheme;
  final TextStyle base;

  @override
  void paint(Canvas canvas, Size size) {
    final style = _axisStyle(scheme, base);
    final ax = _Axes(size, axisTop(data.values), data.format, style)..paint(canvas, scheme.outlineVariant);
    final band = ax.plotW / data.categories.length;
    double cx(int i) => ax.left + band * (i + 0.5);
    final bw = math.max(3.0, math.min(30.0, band * 0.6));
    final bars = data.series[0];
    for (var i = 0; i < bars.values.length; i++) {
      final v = bars.values[i];
      if (v != null) {
        _fillRect(
          canvas,
          Rect.fromLTRB(cx(i) - bw / 2, ax.y(v), cx(i) + bw / 2, ax.y(0)),
          seriesColor(scheme, 0),
          false,
        );
      }
    }
    if (data.series.length > 1) {
      final line = data.series[1];
      final color = seriesColor(scheme, 1);
      for (var i = 0; i < line.values.length; i++) {
        final v = line.values[i];
        if (v == null) continue;
        // Solo une valores consecutivos: un hueco corta la línea
        final prev = i > 0 ? line.values[i - 1] : null;
        if (prev != null) {
          canvas.drawLine(
            Offset(cx(i - 1), ax.y(prev)),
            Offset(cx(i), ax.y(v)),
            Paint()
              ..color = color
              ..strokeWidth = 2,
          );
        }
      }
      for (var i = 0; i < line.values.length; i++) {
        final v = line.values[i];
        if (v != null) _marker(canvas, Offset(cx(i), ax.y(v)), 1, color, scheme.surface);
      }
    }
    canvas.drawLine(
      Offset(ax.left, ax.y(0)),
      Offset(size.width - _Axes.right, ax.y(0)),
      Paint()..color = scheme.onSurfaceVariant,
    );
    ax.categories(canvas, data.categories, cx, style);
  }

  @override
  bool shouldRepaint(_ComboPainter old) => old.data != data || old.scheme != scheme;
}

// ---------------------------------------------------------------------------------------------------------------
// Widgets públicos

List<LegendItem> _seriesLegend(CategoryChartData d, {bool line = false}) => d.series.length > 1 || line
    ? [for (var i = 0; i < d.series.length; i++) LegendItem(d.series[i].labelWithNature, i, line: line)]
    : const [];

class VerticalBarsChart extends StatelessWidget {
  const VerticalBarsChart({super.key, required this.data, required this.testKey, this.caption});
  final CategoryChartData data;
  final String testKey;
  final String? caption;

  @override
  Widget build(BuildContext context) => data.isEmpty
      ? ChartEmpty(testKey: testKey)
      : _Frame(
          data: data,
          testKey: testKey,
          label: data.describe(),
          legend: _seriesLegend(data),
          caption: caption,
          painter: _BarsPainter(data, Theme.of(context).colorScheme, _baseText(context)),
        );
}

class StackedBarsChart extends StatelessWidget {
  const StackedBarsChart({super.key, required this.data, required this.testKey, this.caption});
  final CategoryChartData data;
  final String testKey;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return ChartEmpty(testKey: testKey);
    final totals = data.stackTotals;
    final label =
        '${data.describe()}. Totales: ${[for (var i = 0; i < data.categories.length; i++) '${data.categories[i]} ${totals[i] == null ? 'sin dato' : data.format(totals[i]!)}'].join(', ')}';
    return _Frame(
      data: data,
      testKey: testKey,
      label: label,
      legend: [for (var i = 0; i < data.series.length; i++) LegendItem(data.series[i].labelWithNature, i)],
      caption: caption,
      painter: _BarsPainter(data, Theme.of(context).colorScheme, _baseText(context), stacked: true),
    );
  }
}

class HorizontalBarsChart extends StatelessWidget {
  const HorizontalBarsChart({super.key, required this.data, required this.testKey, this.caption});
  final CategoryChartData data;
  final String testKey;
  final String? caption;

  @override
  Widget build(BuildContext context) => data.isEmpty
      ? ChartEmpty(testKey: testKey)
      : _Frame(
          data: data,
          testKey: testKey,
          label: data.describe(),
          legend: _seriesLegend(data),
          caption: caption,
          height: data.categories.length * (14.0 * data.series.length + 14) + 4,
          painter: _HBarsPainter(data, Theme.of(context).colorScheme, _baseText(context)),
        );
}

class LineChartView extends StatelessWidget {
  const LineChartView({super.key, required this.data, required this.testKey, this.caption, this.area = false});
  final CategoryChartData data;
  final String testKey;
  final String? caption;
  final bool area;

  @override
  Widget build(BuildContext context) => data.isEmpty
      ? ChartEmpty(testKey: testKey)
      : _Frame(
          data: data,
          testKey: testKey,
          label: data.describe(),
          legend: _seriesLegend(data, line: true),
          caption: caption,
          painter: _LinePainter(data, Theme.of(context).colorScheme, _baseText(context), area: area),
        );
}

/// Dona: las categorías son las porciones (de la primera serie); en el centro, el total.
class DonutChart extends StatelessWidget {
  const DonutChart({super.key, required this.data, required this.testKey, this.caption});
  final CategoryChartData data;
  final String testKey;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return ChartEmpty(testKey: testKey);
    final vals = [for (final v in data.series.first.values) v ?? 0];
    final total = vals.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return ChartEmpty(testKey: testKey);
    final parts = [
      for (var i = 0; i < vals.length; i++)
        '${data.categories[i]}: ${data.format(vals[i])} (${percent(vals[i] / total)})',
    ];
    return _Frame(
      data: data,
      testKey: testKey,
      label: '${data.series.first.label}. Total ${data.format(total)}. ${parts.join('; ')}',
      legend: [for (var i = 0; i < parts.length; i++) LegendItem(parts[i], i)],
      caption: caption,
      height: 180,
      painter: _DonutPainter(vals, total, data.format(total), Theme.of(context).colorScheme, _baseText(context)),
    );
  }
}

/// Barras por categoría (primera serie) y línea (segunda), sobre el mismo eje y la misma unidad.
class ComboBarsLineChart extends StatelessWidget {
  const ComboBarsLineChart({super.key, required this.data, required this.testKey, this.caption});
  final CategoryChartData data;
  final String testKey;
  final String? caption;

  @override
  Widget build(BuildContext context) => data.isEmpty
      ? ChartEmpty(testKey: testKey)
      : _Frame(
          data: data,
          testKey: testKey,
          label: data.describe(),
          legend: [
            LegendItem(data.series[0].labelWithNature, 0),
            if (data.series.length > 1) LegendItem(data.series[1].labelWithNature, 1, line: true),
          ],
          caption: caption,
          painter: _ComboPainter(data, Theme.of(context).colorScheme, _baseText(context)),
        );
}

class KpiTilesChart extends StatelessWidget {
  const KpiTilesChart({super.key, required this.tiles, required this.testKey, this.caption});
  final List<(String, String)> tiles;
  final String testKey;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty) return ChartEmpty(testKey: testKey);
    final theme = Theme.of(context);
    return Column(
      key: Key(testKey),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (label, value) in tiles)
              Container(
                key: Key('$testKey.tile'),
                constraints: const BoxConstraints(minWidth: 120),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: theme.textTheme.bodySmall),
                    Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
          ],
        ),
        if (caption != null) ...[const SizedBox(height: 6), Text(caption!, style: theme.textTheme.bodySmall)],
      ],
    );
  }
}

class ProgressChart extends StatelessWidget {
  const ProgressChart({
    super.key,
    required this.label,
    required this.part,
    required this.total,
    required this.format,
    required this.testKey,
  });
  final String label;
  final double part;
  final double total;
  final String Function(double) format;
  final String testKey;

  @override
  Widget build(BuildContext context) {
    if (!(total > 0)) return ChartEmpty(testKey: testKey);
    final f = (part / total).clamp(0.0, 1.0);
    final theme = Theme.of(context);
    return Column(
      key: Key(testKey),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodySmall),
        Text(percent(f), style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Semantics(
          key: Key('$testKey.chart'),
          container: true,
          image: true,
          label: '$label: ${format(part)} de ${format(total)} (${percent(f)})',
          child: ExcludeSemantics(child: LinearProgressIndicator(value: f, minHeight: 10)),
        ),
        const SizedBox(height: 4),
        Text('${format(part)} de ${format(total)}', style: theme.textTheme.bodySmall),
      ],
    );
  }
}
