import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../app/app_services.dart';
import '../../../app/app_shell.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../shared/error_messages.dart';
import '../../../shared/widgets/error_message.dart';
import '../../../shared/widgets/pax_ui.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/domain/principal.dart';
import '../../auth/domain/session_controller.dart';
import '../data/prediction_api.dart';

/// Etiqueta obligatoria (encargo §4.7). Siempre visible encima de cualquier cifra de la predicción.
/// El único texto de la predicción (decisión de Adonis, 2026-11-11): si es probable o no alcanzar la meta.
String likelihoodText(double probability) =>
    probability >= 0.5 ? 'Es probable alcanzar la meta' : 'No es probable alcanzar la meta';

String percent(double fraction) => '${(fraction * 100).toStringAsFixed(1).replaceAll('.', ',')} %';

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

  /// `null` mientras se carga; vacío si no hay listado disponible (entonces se ofrece escribir la referencia).
  List<CampaignChoice>? _choices;
  String? _selected;
  bool _listRequested = false;

  /// ADMINISTRATOR o REPRESENTATIVE: listado de la organización. Si no lo hay (403 de un backend anterior o vacío):
  /// `GET /me/campaigns` (DDM-38). Nunca se pide escribir una referencia interna.
  Future<void> _loadChoices(Principal p) async {
    _listRequested = true;
    var list = <CampaignChoice>[];
    if (p.roles.contains(Principal.administrator) || p.roles.contains(Principal.representative)) {
      try {
        list = await _api.organizationCampaigns(p.organizationId!);
      } on AppException {
        list = [];
      }
    }
    if (list.isEmpty) {
      try {
        list = await _api.myCampaigns();
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
          if (!_listRequested) _loadChoices(p);
          final choices = _choices;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (choices == null) const LinearProgressIndicator(),
              if (choices != null && choices.isNotEmpty) ...[
                Text('Elige una convocatoria', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                for (final c in choices)
                  Card(
                    key: Key('prediction.choice.${c.campaignRef}'),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: _loading ? null : () => _query(p.organizationId!, c.campaignRef),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _selected == c.campaignRef ? Icons.radio_button_checked : Icons.radio_button_off,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(child: Text(c.title, style: Theme.of(context).textTheme.titleSmall)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            StatusChip(
                              c.status == 'OPEN' ? 'Abierta' : (c.status == 'CLOSED' ? 'Cerrada' : c.status),
                              icon: Icons.inventory_2_outlined,
                              tone: Tone.info,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
              if (choices != null && choices.isEmpty)
                const MessageView(
                  key: Key('prediction.noCampaigns'),
                  icon: Icons.campaign_outlined,
                  title: 'Tu organización todavía no tiene convocatorias.',
                  detail: 'Cuando se cree una desde la web, aparecerá aquí para consultar su predicción.',
                ),
              const SizedBox(height: 16),
              if (_loading) const LoadingView(label: 'Cargando predicción…'),
              if (_error != null) _errorView(_error!),
              if (_prediction != null) ...[_PredictionCard(prediction: _prediction!)],
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
    return ErrorMessage(text, textKey: const Key('prediction.error'));
  }
}

class _PredictionCard extends StatelessWidget {
  const _PredictionCard({required this.prediction});
  final Prediction prediction;

  @override
  Widget build(BuildContext context) {
    final p = prediction;
    final theme = Theme.of(context);
    final ink = theme.colorScheme.onSecondaryContainer;
    return Card(
      key: const Key('prediction.card'),
      color: theme.colorScheme.secondaryContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.secondary),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sin estimación (incluido OUTSIDE_TRAINED_RANGE): solo el motivo, nunca una cifra.
            if (!p.available || p.unavailableReason != null || p.probabilityReachTarget == null)
              Text(
                p.unavailableText ?? 'Sin estimación para esta convocatoria.',
                key: const Key('prediction.unavailable'),
                style: theme.textTheme.bodyLarge?.copyWith(color: ink),
              )
            else ...[
              // Decorativo: la probabilidad se lee en el texto de debajo (M-04).
              ExcludeSemantics(
                child: Center(
                  child: SizedBox(
                    width: 180,
                    height: 100,
                    child: CustomPaint(
                      painter: _ArcPainter(
                        fraction: p.probabilityReachTarget!.clamp(0, 1),
                        color: theme.colorScheme.primary,
                        track: theme.colorScheme.surfaceContainerHighest,
                      ),
                    ),
                  ),
                ),
              ),
              Center(
                child: Text(
                  percent(p.probabilityReachTarget!),
                  key: const Key('prediction.percent'),
                  style: theme.textTheme.displaySmall?.copyWith(color: ink, fontWeight: FontWeight.w700),
                ),
              ),
              Center(
                child: Text(
                  likelihoodText(p.probabilityReachTarget!),
                  key: const Key('prediction.likelihood'),
                  style: theme.textTheme.titleMedium?.copyWith(color: ink, fontWeight: FontWeight.w600),
                ),
              ),
            ],
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
