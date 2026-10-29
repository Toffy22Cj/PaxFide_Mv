import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/app_routes.dart';
import '../../../app/app_services.dart';
import '../../../app/pending_intent.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/offline/command_outcome.dart';
import '../../../shared/error_messages.dart';
import '../../../shared/widgets/error_message.dart';
import '../../../shared/widgets/pax_ui.dart';
import '../../../shared/money.dart';
import '../../auth/domain/session_state.dart';
import '../../campaigns/data/campaign_api.dart';
import '../data/donation_intent_api.dart';
import '../domain/donation_flow.dart';
import '../domain/payment_link.dart';
import 'my_donations_screen.dart';
import '../../../shared/widgets/pax_app_bar.dart';
import '../../../shared/motion/circular_reveal.dart';
import '../../../shared/motion/pax_route.dart';

/// "Donar" solo si la convocatoria está abierta, acepta dinero, tiene moneda y admite la pasarela.
bool canDonate(PublicCampaign c) =>
    c.status == 'OPEN' &&
    c.acceptedDonationTypes.contains('MONETARY') &&
    isKnownCurrency(c.currency) &&
    c.acceptedPaymentMethods.contains('GATEWAY');

/// Botón "Donar" de la convocatoria. Abre el asistente a pantalla completa (no es una ruta).
Widget donateAction(BuildContext context, PublicCampaign campaign, String publicCode) {
  if (!canDonate(campaign)) return const SizedBox.shrink();
  return FilledButton(
    key: const Key('donate.open'),
    onPressed: () => Navigator.of(context).push(
      PaxPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => DonateSheet(publicCode: publicCode, currency: campaign.currency!, campaign: campaign),
      ),
    ),
    child: const Text('Donar'),
  );
}

/// Donación con la **pasarela simulada** de la demo (CV-11), en cuatro pasos (Figma 02): elige tu aporte, completa
/// el pago, estado del pago y tu código de seguimiento. Transitoria (no es una ruta). El `statusToken` y el código
/// de seguimiento viven solo en el estado de esta pantalla: al cerrarla desaparecen.
class DonateSheet extends StatefulWidget {
  const DonateSheet({super.key, required this.publicCode, required this.currency, this.campaign});
  final String publicCode;
  final String currency;
  final PublicCampaign? campaign;

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

  /// El botón «Consultar estado del pago»: de ahí sale el círculo del agradecimiento.
  final _refreshKey = GlobalKey();
  final _bodyKey = GlobalKey();
  Offset? _revealFrom;
  bool _revealing = false;

  Future<void> _refresh() async {
    final a = _attempt;
    if (a == null) return;
    final before = _step;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _flow.refresh(a);
      // La donación se confirmó y ya tiene código: «revelado circular» con el agradecimiento (movimiento.html).
      if (before < 4 && _step == 4 && mounted) _startReveal();
    } on IntentNotFoundException {
      _error = 'El enlace de consulta caducó.';
    } on AppException catch (e) {
      _error = describeError(e);
    }
    if (mounted) setState(() => _busy = false);
  }

  void _startReveal() {
    final button = _refreshKey.currentContext?.findRenderObject() as RenderBox?;
    final body = _bodyKey.currentContext?.findRenderObject() as RenderBox?;
    _revealFrom = button != null && body != null && button.attached && body.attached
        ? body.globalToLocal(button.localToGlobal(button.size.center(Offset.zero)))
        : null;
    _revealing = true;
  }

  bool _canOpen(String url) {
    final uri = Uri.tryParse(url);
    return uri != null &&
        isOpenablePaymentUrl(uri, publicOrigin: _services.config.publicOrigin, apiBaseUrl: _services.config.apiBaseUrl);
  }

  Future<void> _openPayment(String url) async {
    final uri = Uri.tryParse(url);
    final ok = uri != null && _canOpen(url) && await _services.linkOpener.open(uri);
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

  /// Paso actual según lo que ya se sabe de la donación.
  int get _step {
    final a = _attempt;
    if (a?.intent == null) return 1;
    final st = a!.lastStatus;
    if (st == null) return 2;
    return st.trackingCode == null ? 3 : 4;
  }

  static const _titles = {
    1: 'Elige tu aporte',
    2: 'Completa el pago',
    3: 'Estado del pago',
    4: 'Tu código de seguimiento',
  };

  void _close() {
    if (_hasState) {
      _confirmLeave(); // cierra si se confirma
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _copy(String text, String message) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final step = _step;
    return PopScope(
      canPop: !_hasState && !_busy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_busy) _confirmLeave();
      },
      child: Scaffold(
        appBar: PaxAppBar(
          automaticallyImplyLeading: false,
          leading: IconButton(
            key: const Key('donate.close'),
            tooltip: 'Cerrar',
            icon: const Icon(Icons.close),
            onPressed: _close,
          ),
          title: const Text('Donar'),
        ),
        body: Stack(
          key: _bodyKey,
          children: [
            SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const NoticeBanner(
                    'Pago simulado (demo): no se mueve dinero real.',
                    textKey: Key('donate.simulated'),
                  ),
                  const SizedBox(height: 16),
                  StepHeader(step: step, total: 4),
                  const SizedBox(height: 8),
                  Text(_titles[step]!, style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  ...switch (step) {
                    1 => _amountStep(theme),
                    2 => _payStep(theme),
                    3 => _statusStep(theme),
                    _ => _codeStep(theme),
                  },
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    ErrorMessage(_error!, textKey: const Key('donate.error')),
                  ],
                  if (_busy) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
                ],
              ),
            ),
            if (_revealing)
              Positioned.fill(
                child: CircularReveal(
                  key: const Key('donate.thanks'),
                  origin: _revealFrom,
                  color: theme.colorScheme.primary,
                  onEnd: () => setState(() => _revealing = false),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.favorite, size: 48, color: theme.colorScheme.onPrimary),
                      const SizedBox(height: 12),
                      Text(
                        '¡Gracias!',
                        style: theme.textTheme.headlineMedium?.copyWith(color: theme.colorScheme.onPrimary),
                      ),
                      const SizedBox(height: 6),
                      Text('Tu donación quedó confirmada.', style: TextStyle(color: theme.colorScheme.onPrimary)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _amountStep(ThemeData theme) {
    final c = widget.campaign;
    final a = _attempt;
    return [
      if (c != null)
        Text(
          [c.title, c.organizationName].where((x) => x.isNotEmpty).join(' · '),
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      const SizedBox(height: 12),
      if (a == null) ...[_accountCard(theme), const SizedBox(height: 12)],
      // M-14: atajos de importe; tocar uno escribe la cifra en el campo (se puede cambiar después).
      if (suggestedAmounts[widget.currency] case final amounts?) ...[
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final v in amounts)
              ChoiceChip(
                key: Key('donate.suggested.$v'),
                showCheckmark: false,
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
        const SizedBox(height: 14),
      ],
      LabeledField(
        label: 'Importe',
        child: TextField(
          key: const Key('donate.amount'),
          controller: _amount,
          enabled: !_busy && a == null,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(suffixText: widget.currency),
          onChanged: (_) => setState(() {}),
        ),
      ),
      if (_outcome == CommandOutcome.failed) ...[
        const SizedBox(height: 10),
        ErrorMessage(switch (_status) {
          409 => 'La convocatoria no acepta esta donación ahora.',
          404 => 'La convocatoria ya no existe.',
          _ => 'El servidor rechazó la donación. Revisa el importe.',
        }, textKey: const Key('donate.rejected')),
      ],
      if (_outcome == CommandOutcome.ambiguous) ...[
        const SizedBox(height: 10),
        const NoticeBanner(
          'No pudimos confirmar si se creó la donación. Reintentar es seguro: se usa la misma operación.',
          textKey: Key('donate.ambiguous'),
        ),
      ],
      if (_outcome == CommandOutcome.notSent) ...[
        const SizedBox(height: 10),
        const NoticeBanner('Sin conexión con el servidor. No se envió nada.', tone: Tone.info),
      ],
      if (toMinorUnits(_amount.text, widget.currency) case final minor?) ...[
        const SizedBox(height: 12),
        Text(
          'Se donarán ${formatMinorUnits(minor, widget.currency)}.',
          key: const Key('donate.preview'),
          style: theme.textTheme.titleSmall,
        ),
      ],
      const SizedBox(height: 14),
      FilledButton(
        key: const Key('donate.submit'),
        onPressed: _busy ? null : _create,
        child: Text(_outcome == CommandOutcome.ambiguous ? 'Reintentar' : 'Continuar al pago simulado'),
      ),
    ];
  }

  List<Widget> _payStep(ThemeData theme) {
    final intent = _attempt!.intent!;
    final redirect = intent.paymentRedirectUrl;
    return [
      if (redirect != null) ...[
        const Text('Completa el pago en el checkout simulado de la web de PaxFide.'),
        const SizedBox(height: 12),
        SectionCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SelectableText(
                _checkoutUrl(redirect),
                key: const Key('donate.checkout'),
                style: theme.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                key: const Key('donate.copyLink'),
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('Copiar enlace'),
                onPressed: () => _copy(_checkoutUrl(redirect), 'Enlace copiado.'),
              ),
              // M-12: abrir el pago en el navegador, solo si el enlace es de PaxFide (S-02); si no, se copia.
              if (_canOpen(_checkoutUrl(redirect))) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  key: const Key('donate.openPayment'),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Abrir el pago'),
                  onPressed: () => _openPayment(_checkoutUrl(redirect)),
                ),
              ],
            ],
          ),
        ),
      ] else
        const Text('El servidor no devolvió una dirección de pago para esta donación.'),
      const SizedBox(height: 14),
      ..._refreshButton(),
    ];
  }

  List<Widget> _statusStep(ThemeData theme) {
    final a = _attempt!;
    final st = a.lastStatus!;
    return [
      Text(formatMinorUnits(a.amount, a.currency), style: theme.textTheme.headlineMedium),
      const SizedBox(height: 10),
      Align(
        alignment: Alignment.centerLeft,
        child: KeyedSubtree(key: const Key('donate.status'), child: donationStatusChip(st.status)),
      ),
      const SizedBox(height: 12),
      Text(switch (st.status) {
        'CONFIRMED' => 'El código de seguimiento aparece cuando los fondos se apliquen. Vuelve a consultar.',
        'PENDING' => 'El pago todavía no se ha completado. Vuelve a consultar cuando lo termines.',
        _ => 'Consulta de nuevo para ver si cambió el estado.',
      }),
      const SizedBox(height: 14),
      ..._refreshButton(),
    ];
  }

  List<Widget> _refreshButton() => [
    if (_attempt!.intent!.statusToken == null)
      const Text(
        'Esta donación no se puede consultar desde la app (el servidor no devolvió el permiso de consulta).',
        key: Key('donate.noToken'),
      )
    else
      KeyedSubtree(
        key: _refreshKey,
        child: FilledButton(
          key: const Key('donate.refresh'),
          onPressed: _busy ? null : _refresh,
          child: Text(_busy ? 'Consultar estado del pago…' : 'Consultar estado del pago'),
        ),
      ),
  ];

  List<Widget> _codeStep(ThemeData theme) {
    final code = _attempt!.lastStatus!.trackingCode!;
    return [
      HighlightCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SelectableText(
              code,
              key: const Key('donate.trackingCode'),
              style: theme.textTheme.titleSmall?.copyWith(fontFamily: 'monospace'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const Key('donate.copyCode'),
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('Copiar'),
              onPressed: () => _copy(code, 'Código copiado. Guárdalo en un lugar seguro.'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      const NoticeBanner('Guárdalo: la app no lo guarda ni lo vuelve a mostrar.'),
      const SizedBox(height: 12),
      Text(
        'Para consultar el recorrido, escribe o pega este código en Seguir una donación.',
        style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
      ),
    ];
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
}
