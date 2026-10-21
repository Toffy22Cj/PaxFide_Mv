import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../app/app_services.dart';
import '../../../app/pending_intent.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/offline/command_outcome.dart';
import '../../../shared/error_messages.dart';
import '../../../shared/widgets/error_message.dart';
import '../../../shared/money.dart';
import '../../auth/domain/session_state.dart';
import '../../campaigns/data/campaign_api.dart';
import '../data/donation_intent_api.dart';
import '../domain/donation_flow.dart';
import 'my_donations_screen.dart';

/// "Donar" solo si la convocatoria está abierta, acepta dinero, tiene moneda y admite la pasarela.
bool canDonate(PublicCampaign c) =>
    c.status == 'OPEN' &&
    c.acceptedDonationTypes.contains('MONETARY') &&
    isKnownCurrency(c.currency) &&
    c.acceptedPaymentMethods.contains('GATEWAY');

Widget donateAction(BuildContext context, PublicCampaign campaign, String publicCode) {
  if (!canDonate(campaign)) return const SizedBox.shrink();
  return FilledButton.icon(
    key: const Key('donate.open'),
    icon: const Icon(Icons.volunteer_activism),
    label: const Text('Donar'),
    onPressed: () => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: false,
      builder: (_) => DonateSheet(publicCode: publicCode, currency: campaign.currency!),
    ),
  );
}

/// Donación con la **pasarela simulada** de la demo (CV-11). Transitoria (no es una ruta). El `statusToken` y el
/// código de seguimiento viven solo en el estado de esta hoja: al cerrarla desaparecen.
class DonateSheet extends StatefulWidget {
  const DonateSheet({super.key, required this.publicCode, required this.currency});
  final String publicCode;
  final String currency;

  @override
  State<DonateSheet> createState() => _DonateSheetState();
}

class _DonateSheetState extends State<DonateSheet> {
  late final AppServices _services = AppScope.of(context);
  late final DonationFlow _flow = DonationFlow(DonationIntentApi(_services.apiClient));
  final _amount = TextEditingController();
  DonationAttempt? _attempt;
  CommandOutcome? _outcome;
  int? _status;
  String? _error;
  bool _busy = false;
  bool _registered = false;

  bool get _hasState => _attempt?.intent != null || _amount.text.isNotEmpty;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_registered) {
      _registered = true;
      _services.router.setLeaveConfirmation(_confirmLeave);
    }
  }

  @override
  void dispose() {
    _services.router.setLeaveConfirmation(null);
    _amount.dispose();
    super.dispose();
  }

  Future<bool> _confirmLeave() async {
    if (!_hasState || !mounted) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('¿Salir de la donación?'),
        content: const Text('Si sales, la app no podrá volver a consultar el estado de este pago.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Seguir aquí')),
          FilledButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('Salir')),
        ],
      ),
    );
    if (leave == true && mounted) Navigator.of(context).pop();
    return leave == true;
  }

  Future<void> _create() async {
    // Lo escrito son pesos (p. ej. 1000 o 1000,50); al backend van unidades mínimas (COP: ×100).
    final amount = toMinorUnits(_amount.text, widget.currency);
    if (amount == null || !isValidAmount(amount)) {
      setState(() => _error = 'Escribe un importe válido en ${widget.currency} (hasta 2 decimales).');
      return;
    }
    final attempt = _attempt ?? _flow.start(widget.publicCode, amount, widget.currency);
    setState(() {
      _attempt = attempt;
      _busy = true;
      _error = null;
    });
    final withAccount = _services.session.state.status == SessionStatus.authenticated;
    final (outcome, status) = await _flow.create(attempt, withAccount: withAccount);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _outcome = outcome;
      _status = status;
      if (outcome == CommandOutcome.failed) _attempt = null; // un rechazo se rehace con otro Command-Id
    });
  }

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
      _error = 'El enlace de consulta caducó.';
    } on AppException catch (e) {
      _error = describeError(e);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _openPayment(String url) async {
    final uri = Uri.tryParse(url);
    final ok = uri != null && uri.hasScheme && await _services.linkOpener.open(uri);
    if (!ok && mounted) {
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(const SnackBar(content: Text('No pudimos abrir el navegador. Copia el enlace y ábrelo a mano.')));
    }
  }

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
                  key: const Key('donate.close'),
                  tooltip: 'Cerrar',
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    if (_hasState) {
                      _confirmLeave(); // cierra la hoja si se confirma
                    } else {
                      Navigator.of(context).pop();
                    }
                  },
                ),
              ],
            ),
            Text(
              'Pasarela de pago SIMULADA (demo): no se mueve dinero real.',
              key: const Key('donate.simulated'),
              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (intent == null && a == null) ...[_accountCard(theme), const SizedBox(height: 12)],
            if (intent == null) ...[
              // M-14: atajos de importe; tocar uno escribe la cifra en el campo (se puede cambiar después).
              if (suggestedAmounts[widget.currency] case final amounts?) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final v in amounts)
                      ChoiceChip(
                        key: Key('donate.suggested.$v'),
                        label: Text(
                          formatMinorUnits(
                            toMinorUnits('$v', widget.currency)!,
                            widget.currency,
                          ).replaceFirst(RegExp(r',0+ '), ' '),
                        ),
                        selected: _amount.text == '$v',
                        onSelected: _busy || a != null ? null : (_) => setState(() => _amount.text = '$v'),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                key: const Key('donate.amount'),
                controller: _amount,
                enabled: !_busy && a == null,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Importe',
                  suffixText: widget.currency,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              if (_outcome == CommandOutcome.failed)
                ErrorMessage(switch (_status) {
                  409 => 'La convocatoria no acepta esta donación ahora.',
                  404 => 'La convocatoria ya no existe.',
                  _ => 'El servidor rechazó la donación. Revisa el importe.',
                }, textKey: const Key('donate.rejected')),
              if (_outcome == CommandOutcome.ambiguous)
                const Text(
                  'No pudimos confirmar si se creó la donación. Reintentar es seguro: se usa la misma operación.',
                  key: Key('donate.ambiguous'),
                ),
              if (_outcome == CommandOutcome.notSent) const Text('Sin conexión con el servidor. No se envió nada.'),
              if (toMinorUnits(_amount.text, widget.currency) case final minor?)
                Text('Se donarán ${formatMinorUnits(minor, widget.currency)}.', key: const Key('donate.preview')),
              const SizedBox(height: 12),
              FilledButton(
                key: const Key('donate.submit'),
                onPressed: _busy ? null : _create,
                child: Text(_outcome == CommandOutcome.ambiguous ? 'Reintentar' : 'Continuar al pago simulado'),
              ),
            ] else ...[
              if (intent.paymentRedirectUrl != null) ...[
                const Text('Completa el pago en el checkout simulado de la web de PaxFide.'),
                const SizedBox(height: 8),
                // M-12: un botón abre el pago en el navegador; el enlace queda debajo por si hay que copiarlo.
                FilledButton.icon(
                  key: const Key('donate.openPayment'),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Abrir el pago'),
                  onPressed: () => _openPayment(_checkoutUrl(intent.paymentRedirectUrl!)),
                ),
                const SizedBox(height: 8),
                Text('O copia este enlace:', style: theme.textTheme.bodySmall),
                SelectableText(_checkoutUrl(intent.paymentRedirectUrl!), key: const Key('donate.checkout')),
              ] else
                const Text('El servidor no devolvió una dirección de pago para esta donación.'),
              const SizedBox(height: 12),
              _statusView(theme, a!.lastStatus),
              const SizedBox(height: 8),
              if (intent.statusToken == null)
                const Text(
                  'Esta donación no se puede consultar desde la app (el servidor no devolvió el permiso de consulta).',
                  key: Key('donate.noToken'),
                )
              else
                FilledButton.tonal(
                  key: const Key('donate.refresh'),
                  onPressed: _busy ? null : _refresh,
                  child: const Text('Consultar estado del pago'),
                ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              ErrorMessage(_error!, textKey: const Key('donate.error')),
            ],
            if (_busy) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
          ],
        ),
      ),
    );
  }

  /// M-11: se puede donar sin cuenta, o iniciar sesión antes de pagar para verla luego en "Mis donaciones".
  Widget _accountCard(ThemeData theme) {
    final withAccount = _services.session.state.status == SessionStatus.authenticated;
    if (withAccount) {
      return const Text('Donas con tu cuenta: la verás en "Mis donaciones".', key: Key('donate.withAccount'));
    }
    return Card(
      key: const Key('donate.guest'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Estás donando sin cuenta. Guarda el código de seguimiento que te daremos al final.'),
            TextButton.icon(
              key: const Key('donate.login'),
              icon: const Icon(Icons.login),
              label: const Text('Iniciar sesión antes de pagar'),
              onPressed: _busy ? null : _loginFirst,
            ),
          ],
        ),
      ),
    );
  }

  /// Cierra la hoja y abre el login; al entrar, la app vuelve a esta convocatoria (intención en memoria, R2).
  void _loginFirst() {
    final router = _services.router;
    _services.pendingIntents.retain(
      PendingIntent(route: AppRoutes.campaignPath(widget.publicCode), params: {'publicCode': widget.publicCode}),
    );
    Navigator.of(context).pop();
    router.push(AppRoutes.login);
  }

  Widget _statusView(ThemeData theme, IntentStatus? s) {
    if (s == null) return const Text('Estado: todavía sin consultar.');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Estado: ${donationStatusLabel(s.status)}', key: const Key('donate.status')),
        if (s.trackingCode != null) ...[
          const SizedBox(height: 8),
          const Text('Tu código de seguimiento (guárdalo: la app no lo guarda ni lo vuelve a mostrar):'),
          SelectableText(s.trackingCode!, key: const Key('donate.trackingCode'), style: theme.textTheme.titleMedium),
        ] else if (s.status == 'CONFIRMED')
          const Text('El código de seguimiento aparece cuando los fondos se apliquen. Vuelve a consultar.'),
      ],
    );
  }
}
