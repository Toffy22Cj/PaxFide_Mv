import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/offline/command_outcome.dart';
import '../../../shared/error_messages.dart';
import '../../../shared/labels.dart';
import '../../../shared/money.dart';
import '../../campaigns/data/campaign_api.dart';
import '../data/donation_intent_api.dart';
import '../domain/donation_flow.dart';

/// "Donar" solo si la convocatoria está abierta, acepta dinero, tiene una
/// moneda conocida y admite la pasarela (DDM-33). El backend sigue validando.
bool canDonate(PublicCampaign c) =>
    c.status == 'OPEN' &&
    c.acceptedDonationTypes.contains('MONETARY') &&
    isKnownCurrency(c.currency) &&
    c.acceptedPaymentMethods.contains('GATEWAY');

Future<void> showDonateSheet(BuildContext context, {required String publicCode, required String currency}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => DonateSheet(publicCode: publicCode, currency: currency),
    );

/// Donación con la pasarela simulada de la demo (CV-11). Transitoria (no es
/// una ruta). El `statusToken` y el código de seguimiento viven solo en el
/// estado de esta hoja: al cerrarla desaparecen (DDM-32).
class DonateSheet extends StatefulWidget {
  const DonateSheet({super.key, required this.publicCode, required this.currency});
  final String publicCode;
  final String currency;

  @override
  State<DonateSheet> createState() => _DonateSheetState();
}

class _DonateSheetState extends State<DonateSheet> {
  late final AppServices _services = AppScope.of(context);
  late final DonationFlow _flow = DonationFlow(_services.donationIntentApi);
  final _amount = TextEditingController();
  DonationAttempt? _attempt;
  CommandOutcome? _outcome;
  int? _status;
  String? _error;
  bool _busy = false;

  bool get _hasState => _attempt?.intent != null || _amount.text.isNotEmpty;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    if (!_hasState) {
      Navigator.of(context).pop();
      return;
    }
    final leave = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('¿Salir de la donación?'),
        content: const Text('Si sales, la app no podrá volver a consultar el estado de este pago.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Seguir aquí')),
          FilledButton(
            key: const Key('donate-leave-confirm'),
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) Navigator.of(context).pop();
  }

  Future<void> _create() async {
    // Se escriben pesos (p. ej. 1000 o 1000,50); al backend van unidades
    // mínimas (COP: ×100) (DDM-37).
    final amount = toMinorUnits(_amount.text, widget.currency);
    if (amount == null || !isValidAmount(amount)) {
      setState(() => _error = 'Escribe un importe válido en ${widget.currency} (hasta 2 decimales).');
      return;
    }
    // Un reintento tras un fallo ambiguo reutiliza el mismo Command-Id.
    final attempt = _attempt ?? _flow.start(widget.publicCode, amount, widget.currency);
    setState(() {
      _attempt = attempt;
      _busy = true;
      _error = null;
    });
    final withAccount = _services.session.value.isAuthenticated;
    final (outcome, status) = await _flow.create(attempt, withAccount: withAccount);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _outcome = outcome;
      _status = status;
      if (outcome == CommandOutcome.failed || outcome == CommandOutcome.notSent) {
        _attempt = null; // un rechazo se rehace con otro Command-Id; lo no enviado no tuvo efecto
      }
    });
  }

  /// Consulta manual del estado: sin polling (regla 3.5).
  Future<void> _refresh() async {
    final a = _attempt;
    if (a == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _flow.refresh(a);
    } on IntentNotFoundException {
      _error = 'El permiso de consulta caducó.';
    } on AppException catch (e) {
      _error = describeError(e);
    }
    if (mounted) setState(() => _busy = false);
  }

  /// La pasarela simulada devuelve una ruta de la web de demo (DDM-31).
  String _checkoutUrl(String redirect) {
    final uri = Uri.tryParse(redirect);
    if (uri != null && uri.hasScheme) return redirect;
    final origin = _services.config.publicOrigin;
    return origin == null ? redirect : origin.replace(path: redirect).toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = _attempt;
    final intent = a?.intent;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(child: Text('Donar', style: theme.textTheme.titleLarge)),
                IconButton(
                  key: const Key('donate-close'),
                  tooltip: 'Cerrar',
                  icon: const Icon(Icons.close),
                  onPressed: _close,
                ),
              ],
            ),
            Text(
              'Pasarela de pago SIMULADA (demo): no se mueve dinero real.',
              key: const Key('donate-simulated'),
              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (intent == null) ...[
              TextField(
                key: const Key('donate-amount'),
                controller: _amount,
                enabled: !_busy && _outcome != CommandOutcome.ambiguous,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Importe',
                  suffixText: widget.currency,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 6),
              if (_outcome == CommandOutcome.failed)
                Text(
                  switch (_status) {
                    409 => 'La convocatoria no acepta esta donación ahora.',
                    404 => 'La convocatoria ya no existe.',
                    _ => 'El servidor rechazó la donación. Revisa el importe.',
                  },
                  key: const Key('donate-rejected'),
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              if (_outcome == CommandOutcome.ambiguous)
                const Text(
                  'No pudimos confirmar si se creó la donación. Reintentar es seguro: se usa la misma operación.',
                  key: Key('donate-ambiguous'),
                ),
              if (_outcome == CommandOutcome.notSent) const Text('Sin conexión con el servidor. No se envió nada.'),
              if (toMinorUnits(_amount.text, widget.currency) case final minor?)
                Text('Se donarán ${formatMinorUnits(minor, widget.currency)}.', key: const Key('donate-preview')),
              const SizedBox(height: 12),
              FilledButton(
                key: const Key('donate-submit'),
                onPressed: _busy ? null : _create,
                child: Text(_outcome == CommandOutcome.ambiguous ? 'Reintentar' : 'Continuar al pago simulado'),
              ),
            ] else ...[
              if (intent.paymentRedirectUrl != null) ...[
                const Text('Completa el pago en el checkout simulado de la web de PaxFide:'),
                const SizedBox(height: 4),
                SelectableText(_checkoutUrl(intent.paymentRedirectUrl!), key: const Key('donate-checkout')),
              ] else
                const Text('El servidor no devolvió una dirección de pago para esta donación.'),
              const SizedBox(height: 12),
              _statusView(theme, a!.lastStatus),
              const SizedBox(height: 8),
              if (intent.statusToken == null)
                const Text(
                  'Esta donación no se puede consultar desde la app (el servidor no devolvió el permiso de consulta).',
                  key: Key('donate-no-token'),
                )
              else
                FilledButton.tonal(
                  key: const Key('donate-refresh'),
                  onPressed: _busy ? null : _refresh,
                  child: const Text('Consultar estado del pago'),
                ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, key: const Key('donate-error'), style: TextStyle(color: theme.colorScheme.error)),
            ],
            if (_busy) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
          ],
        ),
      ),
    );
  }

  Widget _statusView(ThemeData theme, IntentStatus? s) {
    if (s == null) return const Text('Estado: todavía sin consultar.');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Estado: ${intentStatusLabel(s.status)}', key: const Key('donate-status')),
        if (s.trackingCode != null) ...[
          const SizedBox(height: 8),
          const Text('Tu código de seguimiento (guárdalo: la app no lo guarda ni lo vuelve a mostrar):'),
          SelectableText(s.trackingCode!, key: const Key('donate-tracking-code'), style: theme.textTheme.titleSmall),
        ] else if (s.status == 'CONFIRMED')
          const Text('El código de seguimiento aparece cuando los fondos se apliquen. Vuelve a consultar.'),
      ],
    );
  }
}
