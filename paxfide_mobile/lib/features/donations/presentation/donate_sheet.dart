import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/offline/command_outcome.dart';
import '../../../shared/error_messages.dart';
import '../../../shared/labels.dart';
import '../../../shared/money.dart';
import '../../../shared/theme/pax_theme.dart';
import '../../../shared/widgets/state_views.dart';
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
        title: const Text('¿Salir?'),
        content: const Text('Si sales ahora, no podrás volver a ver el estado de este pago desde aquí.'),
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
      setState(() => _error = 'Escribe un monto válido, por ejemplo 50.000.');
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
      _error = 'Ya no podemos consultar este pago desde aquí.';
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
    final p = PaxPalette.of(context);
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
                Expanded(child: Text('Donar', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: p.text))),
                IconButton(
                  key: const Key('donate-close'),
                  tooltip: 'Cerrar',
                  icon: const Icon(Icons.close),
                  onPressed: _close,
                ),
              ],
            ),
            const Notice(
              key: Key('donate-simulated'),
              text: 'Esto es una demostración: no se cobra dinero real.',
            ),
            if (intent == null) ...[
              TextField(
                key: const Key('donate-amount'),
                controller: _amount,
                enabled: !_busy && _outcome != CommandOutcome.ambiguous,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: '¿Cuánto quieres donar?',
                  hintText: 'Ej: 50.000',
                  prefixText: '\$ ',
                  suffixText: widget.currency,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              if (toMinorUnits(_amount.text, widget.currency) case final minor?)
                Text('Vas a donar ${formatMinorUnits(minor, widget.currency)}.',
                    key: const Key('donate-preview'), style: TextStyle(fontSize: 13.5, color: p.text)),
              if (_outcome == CommandOutcome.failed)
                Notice(
                  key: const Key('donate-rejected'),
                  kind: NoticeKind.error,
                  text: switch (_status) {
                    409 => 'Esta causa no puede recibir esta donación ahora.',
                    404 => 'Esta causa ya no existe.',
                    _ => 'No se pudo registrar la donación. Revisa el monto.',
                  },
                ),
              if (_outcome == CommandOutcome.ambiguous)
                const Notice(
                  key: Key('donate-ambiguous'),
                  kind: NoticeKind.warning,
                  text: 'Se cortó la conexión y no sabemos si se registró. Toca "Intentar de nuevo": no se duplicará.',
                ),
              if (_outcome == CommandOutcome.notSent)
                const Notice(kind: NoticeKind.error, text: 'Sin conexión. No se envió nada; inténtalo de nuevo.'),
              const SizedBox(height: 12),
              FilledButton(
                key: const Key('donate-submit'),
                onPressed: _busy ? null : _create,
                child: Text(_outcome == CommandOutcome.ambiguous ? 'Intentar de nuevo' : 'Continuar'),
              ),
            ] else ...[
              const Notice(
                kind: NoticeKind.success,
                title: '¡Gracias! Tu donación quedó registrada',
                text: 'Solo falta completar el pago.',
              ),
              if (intent.paymentRedirectUrl != null) ...[
                Text('Completa el pago en este enlace:', style: TextStyle(fontSize: 13.5, color: p.text)),
                const SizedBox(height: 4),
                SelectableText(_checkoutUrl(intent.paymentRedirectUrl!),
                    key: const Key('donate-checkout'), style: const TextStyle(fontSize: 13, color: paxAccent)),
                const SizedBox(height: 12),
              ],
              _statusView(p, a!.lastStatus),
              const SizedBox(height: 8),
              if (intent.statusToken == null)
                Text('No podemos consultar el pago de esta donación desde la app.',
                    key: const Key('donate-no-token'), style: TextStyle(fontSize: 13, color: p.textMuted))
              else
                OutlinedButton(
                  key: const Key('donate-refresh'),
                  onPressed: _busy ? null : _refresh,
                  child: const Text('Ver si ya se pagó'),
                ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Notice(key: const Key('donate-error'), kind: NoticeKind.error, text: _error!),
            ],
            if (_busy) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
          ],
        ),
      ),
    );
  }

  Widget _statusView(PaxPalette p, IntentStatus? s) {
    if (s == null) {
      return Text('Cuando hayas pagado, toca "Ver si ya se pagó".', style: TextStyle(fontSize: 13, color: p.textMuted));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Estado: ${intentStatusLabel(s.status)}',
            key: const Key('donate-status'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: p.text)),
        if (s.trackingCode != null) ...[
          const SizedBox(height: 10),
          Notice(
            kind: NoticeKind.success,
            title: 'Tu código de seguimiento',
            text: 'Guárdalo: con él puedes ver a dónde llega tu ayuda en "Seguimiento". La app no lo guarda.',
          ),
          SelectableText(s.trackingCode!,
              key: const Key('donate-tracking-code'),
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: p.text)),
        ] else if (s.status == 'CONFIRMED')
          Text('Tu código de seguimiento aparecerá en unos momentos. Vuelve a tocar el botón.',
              style: TextStyle(fontSize: 13, color: p.textMuted)),
      ],
    );
  }
}
