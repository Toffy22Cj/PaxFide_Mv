import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../app/app_services.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../shared/error_messages.dart';
import '../../../shared/labels.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/domain/principal.dart';
import '../../auth/domain/session_state.dart';
import '../data/prediction_api.dart';

/// Etiqueta obligatoria, siempre encima de cualquier cifra (DDM-30).
const predictionLabel = 'ESTIMACIÓN — modelo entrenado con datos sintéticos';

String percent(double fraction) => '${(fraction * 100).toStringAsFixed(1)} %';

/// `/prediction`: excepción de alcance (ADR-043 §0 A3), solo representada para
/// `ADMINISTRATOR`/`REPRESENTATIVE` según `/me`. Muestra únicamente lo que
/// devuelve el backend; sin bandas ni cifras propias.
class PredictionScreen extends StatefulWidget {
  const PredictionScreen({super.key});

  @override
  State<PredictionScreen> createState() => _PredictionScreenState();
}

class _PredictionScreenState extends State<PredictionScreen> {
  late final AppServices _services = AppScope.of(context);
  final _campaignRef = TextEditingController();
  Prediction? _prediction;
  PredictionHistory? _history;
  Object? _error;
  bool _loading = false;

  /// null mientras se carga; vacío si no hay listado (se ofrece escribir la referencia).
  List<CampaignChoice>? _choices;
  String? _selected;
  bool _listRequested = false;

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
    if (mounted) setState(() => _choices = list);
  }

  @override
  void dispose() {
    _campaignRef.dispose();
    super.dispose();
  }

  Future<void> _query(String organizationId, [String? chosen]) async {
    final ref = chosen ?? _campaignRef.text.trim();
    _selected = chosen;
    if (!AppRoutes.isValidParam(ref)) {
      setState(() => _error = const BadRequestException());
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _prediction = null;
      _history = null;
    });
    try {
      final p = await _services.predictionApi.get(organizationId, ref);
      if (mounted) setState(() => _prediction = p);
      try {
        final h = await _services.predictionApi.history(organizationId, ref);
        if (mounted) setState(() => _history = h);
      } on AppException {
        // Sección opcional: sin historial no se dibuja nada.
      }
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Predicción',
      body: ValueListenableBuilder<SessionState>(
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
              title: 'Tu cuenta no tiene acceso a la predicción.',
            );
          }
          if (!_listRequested) _loadChoices(p);
          final choices = _choices;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (choices == null) const LinearProgressIndicator(),
              if (choices != null && choices.isNotEmpty) ...[
                Text('Elige una convocatoria', style: Theme.of(context).textTheme.titleMedium),
                for (final c in choices)
                  ListTile(
                    key: Key('prediction-choice-${c.campaignRef}'),
                    leading: Icon(_selected == c.campaignRef ? Icons.radio_button_checked : Icons.radio_button_off),
                    title: Text(c.title),
                    subtitle: Text(campaignStatusLabel(c.status)),
                    enabled: !_loading,
                    onTap: () => _query(p.organizationId!, c.campaignRef),
                  ),
              ],
              if (choices != null && choices.isEmpty) ...[
                const Text('No hay un listado de convocatorias disponible para tu cuenta.'),
                const SizedBox(height: 8),
                TextField(
                  key: const Key('prediction-campaign-ref'),
                  controller: _campaignRef,
                  enabled: !_loading,
                  decoration: const InputDecoration(
                    labelText: 'Referencia de la convocatoria (campaignRef)',
                    helperText: 'La muestra el panel de la organización en la web.',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _query(p.organizationId!),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  key: const Key('prediction-submit'),
                  onPressed: _loading ? null : () => _query(p.organizationId!),
                  child: const Text('Consultar'),
                ),
              ],
              const SizedBox(height: 16),
              if (_loading) const LinearProgressIndicator(),
              if (_error != null) _errorView(_error!),
              if (_prediction != null) _PredictionCard(prediction: _prediction!),
              if (_history != null) _HistoryCard(history: _history!),
            ],
          );
        },
      ),
    );
  }

  Widget _errorView(Object e) {
    final text = switch (e) {
      ForbiddenException() => 'No puedes ver la predicción de esa convocatoria (o no existe).',
      BadRequestException() => 'Escribe una referencia válida.',
      _ => describeError(e),
    };
    return Text(text, key: const Key('prediction-error'), style: TextStyle(color: Theme.of(context).colorScheme.error));
  }
}

class _PredictionCard extends StatelessWidget {
  const _PredictionCard({required this.prediction});
  final Prediction prediction;

  @override
  Widget build(BuildContext context) {
    final p = prediction;
    final theme = Theme.of(context);
    return Card(
      key: const Key('prediction-card'),
      color: theme.colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(predictionLabel,
                key: const Key('prediction-label'),
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('No es un hecho registrado. Modelo ${p.modelVersion} · calculado el ${p.asOf}'),
            const Divider(),
            // Sin estimación (incluido OUTSIDE_TRAINED_RANGE): solo el motivo.
            if (!p.available || p.unavailableReason != null)
              Text(p.unavailableText ?? 'Sin estimación para esta convocatoria.', key: const Key('prediction-unavailable'))
            else ...[
              if (p.probabilityReachTarget != null) ...[
                Center(
                  child: SizedBox(
                    width: 180,
                    height: 100,
                    child: CustomPaint(
                      painter: _ArcPainter(
                        fraction: p.probabilityReachTarget!.clamp(0, 1).toDouble(),
                        color: theme.colorScheme.tertiary,
                        track: theme.colorScheme.surfaceContainerHighest,
                      ),
                    ),
                  ),
                ),
                Center(child: Text('Probabilidad estimada de alcanzar la meta: ${percent(p.probabilityReachTarget!)}')),
              ],
              if (p.estimatedFinalPctOfTarget != null)
                Text('Porcentaje final estimado de la meta: ${percent(p.estimatedFinalPctOfTarget!)}'),
              if (p.pctTimeElapsed != null) Text('Tiempo transcurrido de la convocatoria: ${percent(p.pctTimeElapsed!)}'),
            ],
            const SizedBox(height: 8),
            for (final w in {p.warning, ...p.warnings}.where((w) => w.isNotEmpty))
              Text('⚠ $w', style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// Estimaciones históricas en t = 0,15, 0,25 y 0,50. Un corte sin cifra
/// muestra su motivo; nada se interpola ni se dibuja por cuenta propia.
class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.history});
  final PredictionHistory history;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SectionCard(
      key: const Key('prediction-history'),
      title: 'Evolución de las estimaciones',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(predictionLabel, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
          if (!history.available || history.cuts.isEmpty)
            Text(history.unavailableText ?? 'Sin estimaciones históricas para esta convocatoria.')
          else
            for (final c in history.cuts)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('Al ${percent(c.t)} de la duración (${shortDate(c.cutAt)})'),
                subtitle: Text(
                  c.available
                      ? [
                          if (c.probabilityReachTarget != null)
                            'probabilidad de meta ${percent(c.probabilityReachTarget!)}',
                          if (c.estimatedFinalPctOfTarget != null)
                            'final estimado ${percent(c.estimatedFinalPctOfTarget!)}',
                          if (c.pctRaisedAtCut != null) 'recaudado entonces ${percent(c.pctRaisedAtCut!)}',
                        ].join(' · ')
                      : [
                          c.unavailableText ?? 'Sin cifra',
                          if (c.pctRaisedAtCut != null) 'recaudado entonces ${percent(c.pctRaisedAtCut!)}',
                        ].join(' · '),
                ),
              ),
          for (final w in history.warnings) Text('⚠ $w', style: theme.textTheme.bodySmall),
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
    final stroke = size.height * 0.18;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, (size.height - stroke / 2) * 2 - stroke / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, math.pi, math.pi, false, base..color = track);
    if (fraction > 0) canvas.drawArc(rect, math.pi, math.pi * fraction, false, base..color = color);
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.fraction != fraction || old.color != color;
}
