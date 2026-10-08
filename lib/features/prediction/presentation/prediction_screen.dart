import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../app/app_services.dart';
import '../../../app/app_shell.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../shared/error_messages.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/domain/session_controller.dart';
import '../data/prediction_api.dart';

/// Etiqueta obligatoria (encargo §4.7). Siempre visible encima de cualquier cifra de la predicción.
const predictionLabel = 'ESTIMACIÓN — modelo entrenado con datos sintéticos';

String percent(double fraction) => '${(fraction * 100).toStringAsFixed(1)} %';

/// `/prediction`: excepción de alcance (ADR-043 §0 A3), solo representada para `ADMINISTRATOR`/`REPRESENTATIVE`
/// según `/me`. Muestra únicamente lo que devuelve el backend; sin bandas ni cifras propias.
class PredictionScreen extends StatefulWidget {
  const PredictionScreen({super.key});

  @override
  State<PredictionScreen> createState() => _PredictionScreenState();
}

class _PredictionScreenState extends State<PredictionScreen> {
  late final AppServices _services = AppScope.of(context);
  late final PredictionApi _api = PredictionApi(_services.apiClient);
  final _campaignRef = TextEditingController();
  Prediction? _prediction;
  Object? _error;
  bool _loading = false;

  @override
  void dispose() {
    _campaignRef.dispose();
    super.dispose();
  }

  Future<void> _query(String organizationId) async {
    final ref = _campaignRef.text.trim();
    if (!AppRoutes.isValidParam(ref)) {
      setState(() => _error = const BadRequestException());
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _prediction = null;
    });
    try {
      final p = await _api.get(organizationId, ref);
      if (mounted) setState(() => _prediction = p);
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      location: AppRoutes.prediction,
      title: 'Predicción',
      body: ListenableBuilder(
        listenable: _services.session,
        builder: (context, _) {
          final p = _services.session.principal;
          if (p == null) {
            return _services.session.profileStatus == ProfileStatus.unavailable
                ? ErrorRetryView(message: 'No pudimos cargar tu perfil.', onRetry: _services.session.reloadProfile)
                : const LoadingView();
          }
          if (!p.showsPrediction) {
            return const MessageView(icon: Icons.lock_outline, title: 'Tu cuenta no tiene acceso a la predicción.');
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                key: const Key('prediction.campaignRef'),
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
                key: const Key('prediction.submit'),
                onPressed: _loading ? null : () => _query(p.organizationId!),
                child: const Text('Consultar'),
              ),
              const SizedBox(height: 16),
              if (_loading) const LinearProgressIndicator(),
              if (_error != null) _errorView(_error!),
              if (_prediction != null) _PredictionCard(prediction: _prediction!),
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
    return Text(
      text,
      key: const Key('prediction.error'),
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    );
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
      key: const Key('prediction.card'),
      color: theme.colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              predictionLabel,
              key: const Key('prediction.label'),
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text('No es un hecho registrado. Modelo ${p.modelVersion} · calculado el ${p.asOf}'),
            const Divider(),
            if (!p.available)
              Text(
                p.unavailableText ?? 'Sin estimación para esta convocatoria.',
                key: const Key('prediction.unavailable'),
              )
            else ...[
              if (p.probabilityReachTarget != null) ...[
                Center(
                  child: SizedBox(
                    width: 180,
                    height: 100,
                    child: CustomPaint(
                      painter: _ArcPainter(
                        fraction: p.probabilityReachTarget!.clamp(0, 1),
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
              if (p.pctTimeElapsed != null)
                Text('Tiempo transcurrido de la convocatoria: ${percent(p.pctTimeElapsed!)}'),
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

/// Semicírculo proporcional a la probabilidad devuelta por el backend (`CustomPainter`, sin librerías).
class _ArcPainter extends CustomPainter {
  _ArcPainter({required this.fraction, required this.color, required this.track});
  final double fraction;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.height * 0.18;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      (size.height - stroke / 2) * 2 - stroke / 2,
    );
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
