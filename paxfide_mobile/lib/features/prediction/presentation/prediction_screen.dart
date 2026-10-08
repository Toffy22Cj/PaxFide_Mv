import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../app/app_services.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../shared/error_messages.dart';
import '../../../shared/labels.dart';
import '../../../shared/money.dart';
import '../../../shared/theme/pax_theme.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/domain/principal.dart';
import '../../auth/domain/session_state.dart';
import '../../campaigns/data/campaign_api.dart';
import '../data/prediction_api.dart';

/// Porcentaje entero para el usuario: 0.4234 → "42 %".
String percent(double fraction) => '${(fraction * 100).round()} %';

/// `/prediction`: pantalla completa con [PredictionView].
class PredictionScreen extends StatelessWidget {
  const PredictionScreen({super.key});

  @override
  Widget build(BuildContext context) => const AppPage(title: 'Predicción', body: PredictionView());
}

/// "¿Llegará esta causa a su meta?" para `ADMINISTRATOR`/`REPRESENTATIVE`
/// (ADR-043 §0 A3). Muestra lo recaudado, el tiempo que queda y la
/// estimación del backend explicada con palabras sencillas. No calcula
/// ninguna estimación propia.
class PredictionView extends StatefulWidget {
  const PredictionView({super.key});

  @override
  State<PredictionView> createState() => _PredictionViewState();
}

class _PredictionViewState extends State<PredictionView> {
  late final AppServices _services = AppScope.of(context);
  final _campaignRef = TextEditingController();

  /// null mientras se carga; vacío si no hay listado (se ofrece escribir la referencia).
  List<CampaignChoice>? _choices;
  bool _listRequested = false;
  CampaignChoice? _selected;

  Prediction? _prediction;
  PredictionHistory? _history;
  PublicCampaign? _campaign;
  Object? _error;
  bool _loading = false;

  /// `ADMINISTRATOR`: listado de la organización. Si no lo hay (otro rol, 403
  /// o vacío): `GET /me/campaigns` (DDM-38).
  Future<void> _loadChoices(Principal p) async {
    _listRequested = true;
    var list = <CampaignChoice>[];
    if (p.roles.contains(OrgRole.administrator) && p.organizationId != null) {
      try {
        list = await _services.predictionApi.organizationCampaigns(p.organizationId!);
      } on AppException {
        list = [];
      }
    }
    if (list.isEmpty) {
      try {
        list = await _services.predictionApi.myCampaigns();
      } on AppException {
        list = [];
      }
    }
    // Las abiertas primero.
    list.sort((a, b) => (a.status == 'OPEN' ? 0 : 1).compareTo(b.status == 'OPEN' ? 0 : 1));
    if (mounted) setState(() => _choices = list);
  }

  @override
  void dispose() {
    _campaignRef.dispose();
    super.dispose();
  }

  Future<void> _query(String organizationId, CampaignChoice choice) async {
    if (!AppRoutes.isValidParam(choice.campaignRef)) {
      setState(() => _error = const BadRequestException());
      return;
    }
    setState(() {
      _selected = choice;
      _loading = true;
      _error = null;
      _prediction = null;
      _history = null;
      _campaign = null;
    });
    try {
      final p = await _services.predictionApi.get(organizationId, choice.campaignRef);
      PredictionHistory? h;
      PublicCampaign? c;
      try {
        h = await _services.predictionApi.history(organizationId, choice.campaignRef);
      } on AppException {
        h = null;
      }
      if (choice.publicCode != null) {
        try {
          c = await _services.campaignApi.get(choice.publicCode!);
        } on AppException {
          c = null;
        }
      }
      if (mounted) {
        setState(() {
          _prediction = p;
          _history = h;
          _campaign = c;
        });
      }
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SessionState>(
      valueListenable: _services.session,
      builder: (context, session, _) {
        final p = session.principal;
        if (p == null) {
          return ErrorRetryView(
            message: 'No pudimos cargar tu perfil.',
            onRetry: () => _services.session.reloadPrincipal(),
          );
        }
        if (!p.canSeePrediction || p.organizationId == null) {
          return const MessageView(
            key: Key('prediction-forbidden'),
            icon: Icons.lock_outline,
            title: 'Esta sección es para administradores y representantes de la organización.',
          );
        }
        if (!_listRequested) _loadChoices(p);
        final choices = _choices;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (choices == null) const LoadingView(label: 'Cargando tus causas…'),
            if (choices != null && choices.isNotEmpty) _choiceList(p.organizationId!, choices),
            if (choices != null && choices.isEmpty) _manualRef(p.organizationId!),
            if (_loading) const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator()),
            if (_error != null) _errorView(_error!),
            if (_prediction != null)
              _PredictionResult(
                title: _selected?.title ?? '',
                prediction: _prediction!,
                history: _history,
                campaign: _campaign,
              ),
          ],
        );
      },
    );
  }

  Widget _choiceList(String organizationId, List<CampaignChoice> choices) {
    final c = PaxPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final choice in choices)
            ChoiceChip(
              key: Key('prediction-choice-${choice.campaignRef}'),
              label: Text(
                choice.status == 'OPEN' ? choice.title : '${choice.title} (${campaignStatusLabel(choice.status).toLowerCase()})',
              ),
              selected: _selected?.campaignRef == choice.campaignRef,
              onSelected: _loading ? null : (_) => _query(organizationId, choice),
              selectedColor: paxAccent.withValues(alpha: 0.18),
              backgroundColor: c.surface,
              side: BorderSide(color: c.border),
              labelStyle: TextStyle(color: c.text, fontWeight: FontWeight.w600),
              showCheckmark: false,
            ),
        ],
      ),
    );
  }

  Widget _manualRef(String organizationId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Notice(text: 'No encontramos causas asignadas a tu cuenta. Escribe el código de la causa que aparece en el panel web.'),
        TextField(
          key: const Key('prediction-campaign-ref'),
          controller: _campaignRef,
          enabled: !_loading,
          decoration: const InputDecoration(labelText: 'Código de la causa'),
          onSubmitted: (_) => _query(organizationId, CampaignChoice(campaignRef: _campaignRef.text.trim(), title: '', status: '')),
        ),
        const SizedBox(height: 12),
        FilledButton(
          key: const Key('prediction-submit'),
          onPressed: _loading
              ? null
              : () => _query(organizationId, CampaignChoice(campaignRef: _campaignRef.text.trim(), title: '', status: '')),
          child: const Text('Ver predicción'),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _errorView(Object e) {
    final text = switch (e) {
      ForbiddenException() => 'No tienes acceso a esa causa.',
      BadRequestException() => 'Escribe un código válido.',
      _ => describeError(e),
    };
    return Notice(key: const Key('prediction-error'), kind: NoticeKind.error, text: text);
  }
}

/// Resultado para una causa: lo que se lleva, el tiempo y la estimación.
class _PredictionResult extends StatelessWidget {
  const _PredictionResult({required this.title, required this.prediction, this.history, this.campaign});

  final String title;
  final Prediction prediction;
  final PredictionHistory? history;
  final PublicCampaign? campaign;

  static DateTime? _date(String? iso) => iso == null ? null : DateTime.tryParse(iso);

  @override
  Widget build(BuildContext context) {
    final c = campaign;
    final target = int.tryParse(c?.targetAmount ?? '');
    final cleared = int.tryParse(c?.clearedAmount ?? '') ?? 0;
    final start = _date(c?.startDate);
    final end = _date(c?.endDate);
    final now = DateTime.now().toUtc();
    double? elapsed = prediction.pctTimeElapsed;
    if (start != null && end != null && end.isAfter(start)) {
      elapsed = (now.difference(start).inSeconds / end.difference(start).inSeconds).clamp(0.0, 1.0);
    }
    final daysLeft = end?.difference(now).inDays;

    return Column(
      key: const Key('prediction-card'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _verdict(context, elapsed, start, end),
        if (target != null && target > 0)
          SectionCard(
            icon: Icons.savings_outlined,
            title: 'Lo recaudado hasta hoy',
            child: ProgressLine(
              value: cleared / target,
              label: '${formatMinorUnits(cleared, c!.currency)} de ${formatMinorUnits(target, c.currency)} '
                  '(${percent(cleared / target)} de la meta)',
            ),
          ),
        if (elapsed != null)
          SectionCard(
            icon: Icons.calendar_month_outlined,
            title: 'Tiempo de la causa',
            child: ProgressLine(
              value: elapsed,
              color: const Color(0xFF38BDF8),
              label: [
                'Ha pasado el ${percent(elapsed)} del tiempo',
                if (daysLeft != null && daysLeft >= 0) 'quedan $daysLeft días (termina el ${longDate(end!)})',
              ].join(' · '),
            ),
          ),
        if (history != null) _historyCard(context, history!),
      ],
    );
  }

  /// Respuesta principal: ¿llegará a la meta?
  Widget _verdict(BuildContext context, double? elapsed, DateTime? start, DateTime? end) {
    final p = prediction;
    final pal = PaxPalette.of(context);
    final prob = p.probabilityReachTarget;
    if (p.available && p.unavailableReason == null && prob != null) {
      final (Color color, String headline) = prob >= 0.7
          ? (paxAccent, 'Es muy probable que alcance la meta')
          : prob >= 0.4
              ? (const Color(0xFFF59E0B), 'Podría alcanzar la meta')
              : (const Color(0xFFEF4444), 'Es poco probable que alcance la meta a este ritmo');
      final finalPct = p.estimatedFinalPctOfTarget;
      return Container(
        key: const Key('prediction-verdict'),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: pal.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Column(
          children: [
            if (title.isNotEmpty)
              Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: pal.textMuted)),
            const SizedBox(height: 10),
            SizedBox(
              width: 200,
              height: 110,
              child: CustomPaint(
                painter: _ArcPainter(fraction: prob.clamp(0, 1).toDouble(), color: color, track: pal.surfaceAlt),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Text(percent(prob),
                      key: const Key('prediction-probability'),
                      style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: pal.text)),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text('probabilidad de llegar a la meta', style: TextStyle(fontSize: 12.5, color: pal.textMuted)),
            const SizedBox(height: 14),
            Text(headline,
                textAlign: TextAlign.center, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: color)),
            if (finalPct != null) ...[
              const SizedBox(height: 6),
              Text(
                'Si las donaciones siguen como hasta ahora, se reuniría cerca del ${percent(finalPct)} de la meta.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, color: pal.text, height: 1.4),
              ),
            ],
            const SizedBox(height: 10),
            Text('Es un cálculo aproximado y cambia con cada nueva donación.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: pal.textMuted)),
          ],
        ),
      );
    }

    // Sin estimación: decirlo en palabras sencillas y, si se puede, cuándo habrá.
    final (NoticeKind kind, String headline, String text) = switch (p.unavailableReason) {
      'OUTSIDE_TRAINED_RANGE' when (elapsed ?? 0) < 0.15 => (
          NoticeKind.warning,
          'Todavía es pronto para estimar',
          _whenAvailable(start, end),
        ),
      'OUTSIDE_TRAINED_RANGE' => (
          NoticeKind.info,
          'La causa ya está muy avanzada para estimar',
          'Pasada la mitad de su tiempo ya no hacemos estimaciones. Mira abajo cuánto se ha recaudado.',
        ),
      'NOT_STARTED' => (NoticeKind.info, 'La causa aún no ha empezado', 'Podremos estimar cuando lleve unos días recibiendo donaciones.'),
      'CAMPAIGN_ENDED' => (NoticeKind.info, 'La causa ya terminó', 'Mira abajo cuánto se recaudó en total.'),
      'TARGET_ALREADY_REACHED' => (NoticeKind.success, '¡Ya alcanzó su meta!', 'No hace falta estimar: la meta ya está cumplida.'),
      'NO_MONETARY_TARGET' => (NoticeKind.info, 'Esta causa no tiene una meta en dinero', 'Solo se puede estimar para causas con una meta en pesos.'),
      'UNSUPPORTED_CURRENCY' => (NoticeKind.info, 'No podemos estimar esta causa', 'Solo se puede estimar para causas en pesos colombianos.'),
      'STRICT_POLICY_EXCLUDED' => (NoticeKind.info, 'No podemos estimar esta causa', 'Esta causa no acepta donaciones por encima de su meta, y para ese tipo no hacemos estimaciones.'),
      _ => (NoticeKind.info, 'No hay estimación para esta causa', 'Por ahora no tenemos suficiente información para estimar.'),
    };
    return Notice(key: const Key('prediction-unavailable'), kind: kind, title: headline, text: text);
  }

  /// La estimación empieza cuando ha pasado el 15 % del tiempo de la causa.
  static String _whenAvailable(DateTime? start, DateTime? end) {
    if (start == null || end == null) {
      return 'Podremos estimar cuando la causa lleve unos días recibiendo donaciones.';
    }
    final from = start.add(Duration(seconds: (end.difference(start).inSeconds * 0.15).round()));
    return 'Podremos estimar a partir del ${longDate(from)}, cuando la causa lleve unos días recibiendo donaciones.';
  }

  /// Estimaciones pasadas: solo si hay alguna con cifra.
  Widget _historyCard(BuildContext context, PredictionHistory h) {
    final cuts = h.cuts.where((c) => c.available && c.probabilityReachTarget != null).toList();
    if (cuts.isEmpty) return const SizedBox.shrink();
    final pal = PaxPalette.of(context);
    return SectionCard(
      key: const Key('prediction-history'),
      icon: Icons.show_chart,
      title: 'Cómo ha cambiado la estimación',
      child: Column(
        children: [
          for (final c in cuts)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(width: 92, child: Text(shortDate(c.cutAt), style: TextStyle(fontSize: 12.5, color: pal.textMuted))),
                  Expanded(child: ProgressLine(value: c.probabilityReachTarget!)),
                  const SizedBox(width: 10),
                  Text(percent(c.probabilityReachTarget!),
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: pal.text)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Semicírculo proporcional a la probabilidad devuelta por el backend.
class _ArcPainter extends CustomPainter {
  _ArcPainter({required this.fraction, required this.color, required this.track});
  final double fraction;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.height * 0.16;
    final radius = math.min(size.width / 2, size.height) - stroke / 2;
    final rect = Rect.fromCircle(center: Offset(size.width / 2, size.height - stroke / 2), radius: radius);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, math.pi, math.pi, false, base..color = track);
    if (fraction > 0) canvas.drawArc(rect, math.pi, math.pi * fraction, false, base..color = color);
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.fraction != fraction || old.color != color || old.track != track;
}
