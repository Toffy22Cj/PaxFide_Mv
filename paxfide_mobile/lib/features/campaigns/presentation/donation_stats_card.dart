import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../shared/money.dart';
import '../../../shared/theme/pax_theme.dart';
import '../../../shared/widgets/state_views.dart';
import '../data/campaign_api.dart';

const _monthsShort = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
const _months = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];

/// Fecha sin hora (en UTC para que restar días no dependa del horario de verano).
DateTime _day(DateTime d) => DateTime.utc(d.year, d.month, d.day);

String shortDay(DateTime d) => '${d.day} ${_monthsShort[d.month - 1]}';
String longDay(DateTime d) => '${d.day} de ${_months[d.month - 1]}';

/// `7 %`, `menos de 1 %`.
String percentText(double fraction) {
  final pct = fraction * 100;
  if (pct > 0 && pct < 1) return 'menos de 1 %';
  return '${pct.round()} %';
}

String _donationsText(int n) => n == 1 ? '1 donación' : '$n donaciones';

/// Serie diaria completa de una causa: un valor por cada día desde que empezó hasta hoy (o hasta que terminó),
/// también los días sin donaciones.
class DailySeries {
  DailySeries._(this.days, this.amounts, this.counts, this.cumulative);

  factory DailySeries.of(DonationStats stats, {required String startDate, required String endDate, DateTime? today}) {
    final now = _day(today ?? DateTime.now());
    final start = DateTime.tryParse(startDate)?.toLocal();
    final end = DateTime.tryParse(endDate)?.toLocal();
    final byDate = <DateTime, DonationDay>{
      for (final d in stats.days)
        if (DateTime.tryParse(d.date) case final DateTime p) _day(p): d,
    };
    var first = start == null ? now : _day(start);
    var last = end == null ? now : _day(end);
    if (now.isBefore(last)) last = now;
    for (final d in byDate.keys) {
      if (d.isBefore(first)) first = d;
      if (d.isAfter(last)) last = d;
    }
    if (last.isBefore(first)) last = first;
    final days = <DateTime>[];
    final amounts = <int>[];
    final counts = <int>[];
    final cumulative = <int>[];
    var running = 0;
    for (var d = first; !d.isAfter(last); d = d.add(const Duration(days: 1))) {
      final x = byDate[d];
      days.add(d);
      amounts.add(x?.amount ?? 0);
      counts.add(x?.donations ?? 0);
      running += x?.amount ?? 0;
      cumulative.add(running);
    }
    return DailySeries._(days, amounts, counts, cumulative);
  }

  final List<DateTime> days;
  final List<int> amounts;
  final List<int> counts;
  final List<int> cumulative;

  int get length => days.length;

  /// El último día con donaciones, o el último día si no hay ninguna.
  int get lastWithDonations {
    for (var i = length - 1; i >= 0; i--) {
      if (counts[i] > 0) return i;
    }
    return length - 1;
  }

  /// El día con más dinero recibido (el primero si hay empate), o null sin donaciones.
  int? get bestDay {
    int? best;
    for (var i = 0; i < length; i++) {
      if (amounts[i] > 0 && (best == null || amounts[i] > amounts[best])) best = i;
    }
    return best;
  }
}

/// Tarjeta "Cómo han llegado las donaciones" de la sección Predicción, solo para la organización dueña de la causa
/// (`ADMINISTRATOR`/`REPRESENTATIVE`; un donante no la ve): cifras clave, el total reunido día a día frente
/// a la meta y lo donado cada día, con fechas y montos en los ejes. Tocar o deslizar sobre el gráfico elige un día.
///
/// Se actualiza sola cada [refreshEvery] mientras la pantalla está abierta y la app en primer plano; también a mano.
/// Enmienda propuesta al ADR-043 (§8.7), pendiente de aprobación: con [refreshEvery] nulo no hay actualización
/// automática.
class DonationStatsCard extends StatefulWidget {
  const DonationStatsCard({
    super.key,
    required this.organizationId,
    required this.campaignRef,
    required this.startDate,
    required this.endDate,
    this.onTotalChanged,
    this.refreshEvery = const Duration(seconds: 30),
  });

  final String organizationId;
  final String campaignRef;

  /// Inicio y fin de la causa (ISO-8601), para dibujar todos sus días.
  final String startDate;
  final String endDate;

  /// Se llama cuando el total recaudado cambia entre dos consultas, para que la pantalla refresque "Lo recaudado".
  final ValueChanged<int>? onTotalChanged;
  final Duration? refreshEvery;

  @override
  State<DonationStatsCard> createState() => _DonationStatsCardState();
}

class _DonationStatsCardState extends State<DonationStatsCard> with WidgetsBindingObserver {
  late final AppServices _services = AppScope.of(context);
  DonationStats? _stats;
  bool _failed = false;
  bool _loading = false;
  int? _selected;
  Timer? _timer;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _load();
      _startTimer();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _load();
      _startTimer();
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _startTimer() {
    final every = widget.refreshEvery;
    _timer?.cancel();
    _timer = every == null ? null : Timer.periodic(every, (_) => _load());
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final s = await _services.campaignApi.donationStats(widget.organizationId, widget.campaignRef);
      if (!mounted) return;
      final previous = _stats;
      setState(() {
        _stats = s;
        _failed = false;
        // Con datos nuevos se vuelve a mostrar el último día con donaciones.
        if (previous == null || previous.totalAmount != s.totalAmount) _selected = null;
      });
      if (previous != null && previous.totalAmount != s.totalAmount) widget.onTotalChanged?.call(s.totalAmount);
    } on AppException {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _stats;
    // Sin donaciones en dinero no hay nada que mostrar.
    if (s != null && s.currency == null) return const SizedBox.shrink();
    final p = PaxPalette.of(context);
    return SectionCard(
      key: const Key('donation-stats'),
      icon: Icons.insights_outlined,
      title: 'Cómo han llegado las donaciones',
      trailing: IconButton(
        key: const Key('donation-stats-refresh'),
        tooltip: 'Actualizar',
        visualDensity: VisualDensity.compact,
        icon: _loading
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : Icon(Icons.refresh, size: 20, color: p.textMuted),
        onPressed: _loading ? null : _load,
      ),
      child: s == null
          ? (_failed
              ? Text('No pudimos cargar el gráfico.', style: TextStyle(fontSize: 13, color: p.textMuted))
              : const SizedBox(height: 60, child: Center(child: CircularProgressIndicator(strokeWidth: 2))))
          : _content(context, s),
    );
  }

  Widget _content(BuildContext context, DonationStats s) {
    final p = PaxPalette.of(context);
    final muted = TextStyle(fontSize: 12.5, color: p.textMuted, height: 1.4);
    final series = DailySeries.of(s, startDate: widget.startDate, endDate: widget.endDate);
    final target = s.targetAmount;
    final best = series.bestDay;
    final end = DateTime.tryParse(widget.endDate)?.toLocal();
    final start = DateTime.tryParse(widget.startDate)?.toLocal();
    final totalDays = start == null || end == null ? null : _day(end).difference(_day(start)).inDays + 1;

    final figures = <_Figure>[
      _Figure(key: const Key('stat-total'), value: formatMinorUnits(s.totalAmount, s.currency), label: 'recaudado'),
      if (target != null && target > 0)
        _Figure(key: const Key('stat-percent'), value: percentText(s.totalAmount / target), label: 'de la meta'),
      _Figure(
        key: const Key('stat-donations'),
        value: '${s.donations}',
        label: s.donations == 1 ? 'donación' : 'donaciones',
      ),
      if (s.donations > 0)
        _Figure(
          key: const Key('stat-average'),
          value: formatMinorUnits(roundToWholeUnits(s.totalAmount / s.donations, s.currency), s.currency),
          label: 'promedio por donación',
        ),
      if (best != null)
        _Figure(
          key: const Key('stat-best'),
          value: shortDay(series.days[best]),
          label: 'mejor día: ${formatMinorUnits(series.amounts[best], s.currency)}',
        ),
      if (totalDays != null)
        _Figure(
          key: const Key('stat-day'),
          value: series.length >= totalDays ? 'Terminó' : 'Día ${series.length} de $totalDays',
          label: series.length >= totalDays ? 'duró $totalDays días' : 'quedan ${totalDays - series.length} días',
        ),
    ];

    final children = <Widget>[
      LayoutBuilder(builder: (context, box) {
        final columns = box.maxWidth >= 520 ? 3 : 2;
        final width = (box.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [for (final f in figures) SizedBox(width: width, child: f)],
        );
      }),
      const SizedBox(height: 18),
    ];

    if (s.donations == 0) {
      children.add(Text(
        'Todavía no hay donaciones. Cuando lleguen, aquí verás día a día cuánto se reúne.',
        key: const Key('donation-stats-empty'),
        style: TextStyle(fontSize: 13, color: p.text, height: 1.4),
      ));
    } else {
      final selected = (_selected ?? series.lastWithDonations).clamp(0, series.length - 1);
      final day = series.days[selected];
      final cumulative = series.cumulative[selected];
      final ofTarget = target != null && target > 0 ? ' (${percentText(cumulative / target)} de la meta)' : '';
      final received = series.counts[selected] == 0
          ? 'no llegaron donaciones'
          : 'llegaron ${formatMinorUnits(series.amounts[selected], s.currency)} en '
              '${_donationsText(series.counts[selected])}';
      children.addAll([
        DonationCharts(
          series: series,
          currency: s.currency,
          targetAmount: target,
          selected: selected,
          onSelect: (i) => setState(() => _selected = i),
        ),
        const SizedBox(height: 12),
        Container(
          key: const Key('donation-stats-detail'),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: p.surfaceAlt, borderRadius: BorderRadius.circular(12)),
          child: Text(
            'El ${longDay(day)} $received. Total reunido hasta ese día: '
            '${formatMinorUnits(cumulative, s.currency)}$ofTarget.',
            style: TextStyle(fontSize: 13, color: p.text, height: 1.4),
          ),
        ),
        const SizedBox(height: 4),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            key: const Key('donation-stats-table'),
            tilePadding: EdgeInsets.zero,
            title: Text('Ver los datos día por día', style: TextStyle(fontSize: 13, color: p.textMuted)),
            children: [
              for (var i = 0; i < series.length; i++)
                if (series.counts[i] > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(child: Text(longDay(series.days[i]), style: TextStyle(fontSize: 13, color: p.text))),
                        Text(
                          '${formatMinorUnits(series.amounts[i], s.currency)} · ${_donationsText(series.counts[i])}',
                          style: TextStyle(fontSize: 13, color: p.text, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ]);
    }
    children.addAll([
      if (_failed) ...[
        const SizedBox(height: 6),
        Text('No pudimos actualizar. Mostramos los últimos datos.', style: muted),
      ],
      if (widget.refreshEvery != null) ...[
        const SizedBox(height: 6),
        Text('Se actualiza solo mientras tienes esta pantalla abierta.', style: muted),
      ],
    ]);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }
}

class _Figure extends StatelessWidget {
  const _Figure({super.key, required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = PaxPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: p.surfaceAlt, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: p.text)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 12, color: p.textMuted)),
        ],
      ),
    );
  }
}

/// Escala "redonda" para un eje: máximo y paso (1, 2, 2,5 o 5 por potencia de 10).
({double max, double step}) niceScale(double value, {int ticks = 4}) {
  if (value <= 0) return (max: 1, step: 0.25);
  final raw = value / ticks;
  final mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
  final step = [1.0, 2.0, 2.5, 5.0, 10.0].map((m) => m * mag).firstWhere((s) => s >= raw);
  return (max: (value / step).ceil() * step, step: step);
}

/// Dos gráficos con el mismo eje de días (sin doble escala): arriba el total reunido frente a la meta, abajo lo donado
/// cada día. Cada uno con montos en su eje; abajo, las fechas.
class DonationCharts extends StatelessWidget {
  const DonationCharts({
    super.key,
    required this.series,
    required this.currency,
    required this.targetAmount,
    required this.selected,
    required this.onSelect,
  });

  final DailySeries series;
  final String? currency;
  final int? targetAmount;
  final int selected;
  final ValueChanged<int> onSelect;

  static const double gutter = 58;

  /// La meta entra en la escala solo si no aplasta la línea (hasta 2,5 veces lo reunido).
  bool get goalInScale {
    final t = targetAmount;
    return t != null && t > 0 && t <= series.cumulative.last * 2.5;
  }

  @override
  Widget build(BuildContext context) {
    final p = PaxPalette.of(context);
    final title = TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: p.text);
    final note = TextStyle(fontSize: 12, color: p.textMuted, height: 1.4);
    final t = targetAmount;
    final style = _ChartStyle(
      accent: paxAccent,
      text: p.text,
      muted: p.textMuted,
      grid: p.border,
      surface: p.surface,
      label: DefaultTextStyle.of(context).style,
    );

    Widget plot(Key key, double height, CustomPainter painter) => LayoutBuilder(
          builder: (context, box) {
            void pick(double dx) {
              final w = box.maxWidth - gutter;
              final i = ((dx - gutter) / w * series.length).floor().clamp(0, series.length - 1);
              if (i != selected) onSelect(i);
            }

            return GestureDetector(
              key: key,
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => pick(d.localPosition.dx),
              onHorizontalDragUpdate: (d) => pick(d.localPosition.dx),
              child: CustomPaint(size: Size(box.maxWidth, height), painter: painter),
            );
          },
        );

    return Semantics(
      label: 'Gráfico de donaciones por día. Usa "Ver los datos día por día" para leerlos como lista.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Total reunido día a día', style: title),
          if (t != null && t > 0 && !goalInScale)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'La meta es ${formatMinorUnits(t, currency)}; va en el ${percentText(series.cumulative.last / t)}.',
                key: const Key('donation-goal-note'),
                style: note,
              ),
            ),
          const SizedBox(height: 8),
          plot(
            const Key('donation-chart'),
            150,
            _CumulativePainter(
              series: series,
              currency: currency,
              targetAmount: targetAmount,
              goalInScale: goalInScale,
              selected: selected,
              style: style,
            ),
          ),
          const SizedBox(height: 18),
          Text('Donado cada día', style: title),
          const SizedBox(height: 8),
          plot(
            const Key('donation-daily-chart'),
            130,
            _DailyPainter(series: series, currency: currency, selected: selected, style: style),
          ),
        ],
      ),
    );
  }
}

class _ChartStyle {
  const _ChartStyle({
    required this.accent,
    required this.text,
    required this.muted,
    required this.grid,
    required this.surface,
    required this.label,
  });
  final Color accent;
  final Color text;
  final Color muted;
  final Color grid;
  final Color surface;
  final TextStyle label;

  @override
  bool operator ==(Object other) =>
      other is _ChartStyle &&
      other.accent == accent &&
      other.text == text &&
      other.muted == muted &&
      other.grid == grid &&
      other.surface == surface &&
      other.label == label;

  @override
  int get hashCode => Object.hash(accent, text, muted, grid, surface, label);
}

TextPainter _text(String s, TextStyle style) => TextPainter(
      text: TextSpan(text: s, style: style),
      textDirection: TextDirection.ltr,
    )..layout();

/// Eje de montos a la izquierda con líneas guía; devuelve la función valor → y.
double Function(num) _amountAxis(
  Canvas canvas,
  Size size,
  _ChartStyle style,
  String? currency, {
  required double maxValue,
  required double top,
  required double bottom,
}) {
  final scale = niceScale(maxValue);
  double y(num v) => bottom - (v / scale.max) * (bottom - top);
  final grid = Paint()
    ..color = style.grid
    ..strokeWidth = 1;
  final labelStyle = style.label.copyWith(fontSize: 10.5, color: style.muted);
  for (var v = 0.0; v <= scale.max + scale.step / 2; v += scale.step) {
    final yy = y(v);
    canvas.drawLine(Offset(DonationCharts.gutter, yy), Offset(size.width, yy), grid);
    final t = _text(formatCompact(v, currency), labelStyle);
    t.paint(canvas, Offset(DonationCharts.gutter - 8 - t.width, yy - t.height / 2));
  }
  return y;
}

class _CumulativePainter extends CustomPainter {
  _CumulativePainter({
    required this.series,
    required this.currency,
    required this.targetAmount,
    required this.goalInScale,
    required this.selected,
    required this.style,
  });

  final DailySeries series;
  final String? currency;
  final int? targetAmount;
  final bool goalInScale;
  final int selected;
  final _ChartStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final n = series.length;
    final left = DonationCharts.gutter;
    final slot = (size.width - left) / n;
    double cx(int i) => left + (i + 0.5) * slot;
    const top = 10.0;
    final bottom = size.height - 4;
    final total = series.cumulative.last;
    final t = targetAmount;
    final maxValue = goalInScale ? math.max(total, t!).toDouble() : total * 1.15;
    final y = _amountAxis(canvas, size, style, currency, maxValue: maxValue, top: top, bottom: bottom);

    if (goalInScale) {
      final ty = y(t!);
      final dash = Paint()
        ..color = style.text.withValues(alpha: 0.7)
        ..strokeWidth = 1.5;
      for (double x = left; x < size.width; x += 8) {
        canvas.drawLine(Offset(x, ty), Offset(math.min(x + 4, size.width), ty), dash);
      }
      final label = _text('Meta ${formatCompact(t, currency)}',
          style.label.copyWith(fontSize: 11, color: style.text, fontWeight: FontWeight.w700));
      label.paint(canvas, Offset(size.width - label.width, ty - label.height - 2));
    }

    final line = Path()..moveTo(cx(0), y(series.cumulative[0]));
    for (var i = 1; i < n; i++) {
      line.lineTo(cx(i), y(series.cumulative[i]));
    }
    final area = Path.from(line)
      ..lineTo(cx(n - 1), bottom)
      ..lineTo(cx(0), bottom)
      ..close();
    canvas.drawPath(area, Paint()..color = style.accent.withValues(alpha: 0.14));
    canvas.drawPath(
      line,
      Paint()
        ..color = style.accent
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );

    canvas.drawLine(
      Offset(cx(selected), top),
      Offset(cx(selected), bottom),
      Paint()
        ..color = style.muted.withValues(alpha: 0.6)
        ..strokeWidth = 1,
    );
    for (var i = 0; i < n; i++) {
      if (series.counts[i] == 0 && i != selected) continue;
      final c = Offset(cx(i), y(series.cumulative[i]));
      final r = i == selected ? 6.0 : 3.5;
      canvas.drawCircle(c, r + 2, Paint()..color = style.surface);
      canvas.drawCircle(c, r, Paint()..color = style.accent);
    }

    // Etiqueta del día elegido: total y, si hay meta, el porcentaje.
    final value = series.cumulative[selected];
    final text = t != null && t > 0
        ? '${formatCompact(value, currency)} · ${percentText(value / t)}'
        : formatCompact(value, currency);
    final tag = _text(text, style.label.copyWith(fontSize: 11.5, color: style.text, fontWeight: FontWeight.w800));
    final px = cx(selected);
    final py = y(value);
    final tx = (px - tag.width / 2).clamp(left + 6, size.width - tag.width - 6).toDouble();
    var ty = py - tag.height - 10;
    if (ty < 0) ty = py + 10;
    final box = RRect.fromRectAndRadius(
      Rect.fromLTWH(tx - 6, ty - 3, tag.width + 12, tag.height + 6),
      const Radius.circular(6),
    );
    canvas.drawRRect(box, Paint()..color = style.surface);
    canvas.drawRRect(
      box,
      Paint()
        ..color = style.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    tag.paint(canvas, Offset(tx, ty));
  }

  @override
  bool shouldRepaint(_CumulativePainter old) =>
      old.series != series ||
      old.selected != selected ||
      old.targetAmount != targetAmount ||
      old.goalInScale != goalInScale ||
      old.style != style;
}

class _DailyPainter extends CustomPainter {
  _DailyPainter({required this.series, required this.currency, required this.selected, required this.style});

  final DailySeries series;
  final String? currency;
  final int selected;
  final _ChartStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final n = series.length;
    final left = DonationCharts.gutter;
    final slot = (size.width - left) / n;
    double cx(int i) => left + (i + 0.5) * slot;
    const top = 16.0; // aire para el monto sobre la barra
    final bottom = size.height - 20; // las fechas van debajo
    final maxDay = series.amounts.fold<int>(0, math.max);
    final y = _amountAxis(canvas, size, style, currency, maxValue: maxDay.toDouble(), top: top, bottom: bottom);

    canvas.drawLine(
      Offset(cx(selected), top),
      Offset(cx(selected), bottom),
      Paint()
        ..color = style.muted.withValues(alpha: 0.6)
        ..strokeWidth = 1,
    );

    final barWidth = (slot * 0.7).clamp(2.0, 26.0).toDouble();
    for (var i = 0; i < n; i++) {
      final a = series.amounts[i];
      if (a <= 0) continue;
      final rect = Rect.fromLTRB(cx(i) - barWidth / 2, y(a), cx(i) + barWidth / 2, bottom);
      canvas.drawRRect(
        RRect.fromRectAndCorners(rect, topLeft: const Radius.circular(3), topRight: const Radius.circular(3)),
        Paint()..color = i == selected ? style.accent : style.accent.withValues(alpha: 0.5),
      );
    }

    // Monto sobre la barra elegida.
    final a = series.amounts[selected];
    if (a > 0) {
      final tag = _text(formatCompact(a, currency),
          style.label.copyWith(fontSize: 11, color: style.text, fontWeight: FontWeight.w800));
      final tx = (cx(selected) - tag.width / 2).clamp(left, size.width - tag.width).toDouble();
      tag.paint(canvas, Offset(tx, math.max(0, y(a) - tag.height - 2)));
    }

    // Fechas cada [step] días contando desde el último, sin que se pisen; la última es "hoy" si corresponde.
    final labelStyle = style.label.copyWith(fontSize: 10.5, color: style.muted);
    final maxLabels = math.max(2, ((size.width - left) / 64).floor());
    final step = n <= maxLabels ? 1 : ((n - 1) / (maxLabels - 1)).ceil();
    final today = _day(DateTime.now());
    final shown = <int>{for (var i = n - 1; i >= 0; i -= step) i};
    for (final i in shown) {
      final d = series.days[i];
      final t = _text(d == today ? 'hoy' : shortDay(d), labelStyle);
      final tx = (cx(i) - t.width / 2).clamp(left, size.width - t.width).toDouble();
      canvas.drawLine(Offset(cx(i), bottom), Offset(cx(i), bottom + 3), Paint()..color = style.grid);
      t.paint(canvas, Offset(tx, bottom + 5));
    }
  }

  @override
  bool shouldRepaint(_DailyPainter old) => old.series != series || old.selected != selected || old.style != style;
}
