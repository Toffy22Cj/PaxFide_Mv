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

/// `2026-10-01` → `1 oct`.
String _short(String day) {
  final d = DateTime.tryParse(day);
  return d == null ? day : '${d.day} ${_monthsShort[d.month - 1]}';
}

/// `2026-10-01` → `1 de octubre`.
String _long(String day) {
  final d = DateTime.tryParse(day);
  return d == null ? day : '${d.day} de ${_months[d.month - 1]}';
}

/// "El 1 de octubre" o "Del 1 al 3 de octubre".
String periodLabel(DonationPeriod p) {
  if (p.from == p.to) return 'El ${_long(p.from)}';
  final a = DateTime.tryParse(p.from);
  final b = DateTime.tryParse(p.to);
  if (a != null && b != null && a.month == b.month && a.year == b.year) return 'Del ${a.day} al ${_long(p.to)}';
  return 'Del ${_long(p.from)} al ${_long(p.to)}';
}

String _donationsText(int n) => n == 1 ? '1 donación' : '$n donaciones';

/// Tarjeta "Cómo han llegado las donaciones" del detalle de la causa: lo recaudado acumulado hacia la meta y lo que
/// llegó en cada periodo, con los totales que da el backend (nunca donaciones sueltas).
///
/// Se actualiza sola cada [refreshEvery] mientras la pantalla está abierta y la app en primer plano; también a mano.
/// Enmienda propuesta al ADR-043 (§8.7), pendiente de aprobación: con [refreshEvery] nulo no hay actualización
/// automática.
class DonationStatsCard extends StatefulWidget {
  const DonationStatsCard({
    super.key,
    required this.publicCode,
    this.onTotalChanged,
    this.refreshEvery = const Duration(seconds: 30),
  });

  final String publicCode;

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
      final s = await _services.campaignApi.donationStats(widget.publicCode);
      if (!mounted) return;
      final previous = _stats;
      setState(() {
        _stats = s;
        _failed = false;
        if (_selected != null && _selected! >= s.periods.length) _selected = null;
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
    final children = <Widget>[
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _Figure(value: formatMinorUnits(s.totalAmount, s.currency), label: 'recaudado')),
          Expanded(child: _Figure(value: '${s.donations}', label: s.donations == 1 ? 'donación' : 'donaciones')),
        ],
      ),
      const SizedBox(height: 14),
    ];
    if (s.periods.isEmpty) {
      children.add(Text(
        s.donations == 0
            ? 'Todavía no hay donaciones. Cuando lleguen, aquí verás cómo crece lo recaudado.'
            : 'El gráfico aparece cuando haya al menos ${s.minDonationsPerPeriod} donaciones. Así nadie puede '
                'ver cuánto dio una sola persona.',
        key: const Key('donation-stats-empty'),
        style: TextStyle(fontSize: 13, color: p.text, height: 1.4),
      ));
    } else {
      final selected = _selected ?? s.periods.length - 1;
      final period = s.periods[selected];
      final cumulative = s.periods.take(selected + 1).fold<int>(0, (a, x) => a + x.amount);
      children.addAll([
        Text('Lo recaudado hasta cada momento', style: muted),
        const SizedBox(height: 6),
        DonationChart(
          stats: s,
          selected: selected,
          onSelect: (i) => setState(() => _selected = i),
        ),
        const SizedBox(height: 10),
        Container(
          key: const Key('donation-stats-detail'),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: p.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${periodLabel(period)} llegaron ${formatMinorUnits(period.amount, s.currency)} en '
            '${_donationsText(period.donations)}. Hasta ese día se habían reunido '
            '${formatMinorUnits(cumulative, s.currency)}.',
            style: TextStyle(fontSize: 13, color: p.text, height: 1.4),
          ),
        ),
        const SizedBox(height: 4),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            key: const Key('donation-stats-table'),
            tilePadding: EdgeInsets.zero,
            title: Text('Ver los datos', style: TextStyle(fontSize: 13, color: p.textMuted)),
            children: [
              for (final x in s.periods)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(child: Text(periodLabel(x), style: TextStyle(fontSize: 13, color: p.text))),
                      Text('${formatMinorUnits(x.amount, s.currency)} · ${_donationsText(x.donations)}',
                          style: TextStyle(fontSize: 13, color: p.text, fontWeight: FontWeight.w600)),
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
  const _Figure({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = PaxPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: p.text)),
        Text(label, style: TextStyle(fontSize: 12, color: p.textMuted)),
      ],
    );
  }
}

/// Dos paneles con el mismo eje de tiempo (sin doble escala): arriba lo recaudado acumulado frente a la meta, abajo
/// lo que llegó en cada periodo. Tocar o deslizar elige un periodo.
class DonationChart extends StatelessWidget {
  const DonationChart({super.key, required this.stats, required this.selected, required this.onSelect});

  final DonationStats stats;
  final int selected;
  final ValueChanged<int> onSelect;

  static const double lineHeight = 130;
  static const double barsHeight = 56;
  static const double gap = 14;

  @override
  Widget build(BuildContext context) {
    final p = PaxPalette.of(context);
    final periods = stats.periods;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, box) {
            void pick(double dx) {
              final i = (dx / box.maxWidth * periods.length).floor().clamp(0, periods.length - 1);
              if (i != selected) onSelect(i);
            }

            return GestureDetector(
              key: const Key('donation-chart'),
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => pick(d.localPosition.dx),
              onHorizontalDragUpdate: (d) => pick(d.localPosition.dx),
              child: Semantics(
                label: 'Gráfico de lo recaudado: ${formatMinorUnits(stats.totalAmount, stats.currency)} en '
                    '${periods.length} periodos',
                child: CustomPaint(
                  size: Size(box.maxWidth, lineHeight + gap + barsHeight),
                  painter: _DonationChartPainter(
                    stats: stats,
                    selected: selected,
                    accent: paxAccent,
                    ink: p.text,
                    muted: p.textMuted,
                    grid: p.border,
                    surface: p.surface,
                    labelStyle: DefaultTextStyle.of(context).style,
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(_short(periods.first.from), style: TextStyle(fontSize: 11.5, color: p.textMuted)),
            const Spacer(),
            if (periods.length > 1)
              Text(_short(periods.last.to), style: TextStyle(fontSize: 11.5, color: p.textMuted)),
          ],
        ),
        const SizedBox(height: 2),
        Text('Barras: lo que llegó en cada periodo', style: TextStyle(fontSize: 11.5, color: p.textMuted)),
      ],
    );
  }
}

class _DonationChartPainter extends CustomPainter {
  _DonationChartPainter({
    required this.stats,
    required this.selected,
    required this.accent,
    required this.ink,
    required this.muted,
    required this.grid,
    required this.surface,
    required this.labelStyle,
  });

  final DonationStats stats;
  final int selected;
  final Color accent;
  final Color ink;
  final Color muted;
  final Color grid;
  final Color surface;

  /// Estilo de texto de la app (misma fuente que el resto de la pantalla).
  final TextStyle labelStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final periods = stats.periods;
    final n = periods.length;
    final slot = size.width / n;
    double cx(int i) => (i + 0.5) * slot;
    const top = 14.0; // aire para la etiqueta de la meta
    final lineBottom = DonationChart.lineHeight;
    final barsTop = DonationChart.lineHeight + DonationChart.gap;
    final barsBottom = size.height;

    // Panel de arriba: acumulado y meta, en la misma escala.
    final cumulative = <int>[];
    var running = 0;
    for (final x in periods) {
      running += x.amount;
      cumulative.add(running);
    }
    final target = stats.targetAmount;
    final maxY = math.max(running, target ?? 0).toDouble() * 1.05;
    double y(num v) => maxY <= 0 ? lineBottom : lineBottom - (v / maxY) * (lineBottom - top);

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, lineBottom), Offset(size.width, lineBottom), gridPaint);

    if (target != null && target > 0) {
      final ty = y(target);
      final dash = Paint()
        ..color = muted
        ..strokeWidth = 1.5;
      for (double x = 0; x < size.width; x += 8) {
        canvas.drawLine(Offset(x, ty), Offset(math.min(x + 4, size.width), ty), dash);
      }
      final label = TextPainter(
        text: TextSpan(text: 'Meta', style: labelStyle.copyWith(fontSize: 11, color: muted, fontWeight: FontWeight.w700)),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, Offset(size.width - label.width, ty - label.height - 2));
    }

    final line = Path()..moveTo(0, lineBottom);
    for (var i = 0; i < n; i++) {
      line.lineTo(cx(i), y(cumulative[i]));
    }
    final area = Path.from(line)
      ..lineTo(cx(n - 1), lineBottom)
      ..close();
    canvas.drawPath(area, Paint()..color = accent.withValues(alpha: 0.14));
    canvas.drawPath(
      line,
      Paint()
        ..color = accent
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );

    // Guía vertical del periodo elegido, a lo alto de los dos paneles.
    // Empieza en la línea de la meta para no tapar su etiqueta.
    canvas.drawLine(
      Offset(cx(selected), target != null && target > 0 ? y(target) : top),
      Offset(cx(selected), barsBottom),
      Paint()
        ..color = muted.withValues(alpha: 0.5)
        ..strokeWidth = 1,
    );

    for (var i = 0; i < n; i++) {
      final c = Offset(cx(i), y(cumulative[i]));
      final r = i == selected ? 6.0 : 4.0;
      canvas.drawCircle(c, r + 2, Paint()..color = surface);
      canvas.drawCircle(c, r, Paint()..color = accent);
    }

    // Panel de abajo: lo que llegó en cada periodo, con su propia escala.
    canvas.drawLine(Offset(0, barsBottom), Offset(size.width, barsBottom), gridPaint);
    final maxBar = periods.map((x) => x.amount).fold<int>(0, math.max);
    final barWidth = math.max(4.0, math.min(28.0, slot - 2));
    for (var i = 0; i < n; i++) {
      final h = maxBar <= 0 ? 0.0 : periods[i].amount / maxBar * (barsBottom - barsTop);
      if (h <= 0) continue;
      final rect = Rect.fromLTWH(cx(i) - barWidth / 2, barsBottom - h, barWidth, h);
      canvas.drawRRect(
        RRect.fromRectAndCorners(rect, topLeft: const Radius.circular(4), topRight: const Radius.circular(4)),
        Paint()..color = i == selected ? accent : accent.withValues(alpha: 0.45),
      );
    }
  }

  @override
  bool shouldRepaint(_DonationChartPainter old) =>
      old.stats != stats ||
      old.selected != selected ||
      old.accent != accent ||
      old.ink != ink ||
      old.muted != muted ||
      old.grid != grid ||
      old.surface != surface ||
      old.labelStyle != labelStyle;
}
