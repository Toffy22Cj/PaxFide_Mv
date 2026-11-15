import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/app_services.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../shared/error_messages.dart';
import '../../../shared/money.dart';
import '../../../shared/widgets/pax_ui.dart';
import '../../tracking/presentation/tracking_screen.dart';
import '../../../shared/motion/pax_route.dart';
import '../data/donation_intent_api.dart';
import '../domain/donation_queue.dart';
import '../domain/payment_link.dart';

/// «Donaciones guardadas en este teléfono» (Enmienda 4 de ADR-043, S5): las hechas sin conexión y las que faltan por
/// pagar. Se envían solas; aquí se pagan y se consulta su estado. No aparece si no hay ninguna.
class SavedDonationsSection extends StatefulWidget {
  const SavedDonationsSection({super.key});

  @override
  State<SavedDonationsSection> createState() => _SavedDonationsSectionState();
}

class _SavedDonationsSectionState extends State<SavedDonationsSection> {
  late final AppServices _services = AppScope.of(context);
  List<SavedDonation> _items = const [];
  bool _started = false;
  final Map<String, String> _notes = {};

  /// El código de seguimiento de una ya confirmada: solo en memoria (ADR-043 §0).
  final Map<String, String> _codes = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _services.donationQueue.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    _services.donationQueue.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final items = await _services.donationQueue.visible();
    if (mounted) setState(() => _items = items);
  }

  Uri? _paymentUri(String raw) {
    final config = _services.config;
    final parsed = Uri.tryParse(raw);
    if (parsed == null) return null;
    final full = parsed.hasScheme || config.publicOrigin == null ? parsed : config.publicOrigin!.replace(path: raw);
    return isOpenablePaymentUrl(full, publicOrigin: config.publicOrigin, apiBaseUrl: config.apiBaseUrl) ? full : null;
  }

  Future<void> _pay(SavedDonation d) async {
    final uri = d.paymentUrl == null ? null : _paymentUri(d.paymentUrl!);
    final ok = uri != null && await _services.linkOpener.open(uri);
    if (!ok && mounted) {
      setState(() => _notes[d.commandId] = 'No pudimos abrir el pago. Inténtalo de nuevo con conexión.');
    }
  }

  Future<void> _status(SavedDonation d) async {
    setState(() => _notes.remove(d.commandId));
    try {
      final st = await _services.donationQueue.status(d);
      if (!mounted) return;
      setState(() {
        if (st.trackingCode case final code?) {
          _codes[d.commandId] = code;
        } else {
          _notes[d.commandId] = st.status == 'CONFIRMED'
              ? 'Pago confirmado. El código de seguimiento llega cuando se apliquen los fondos.'
              : 'El pago todavía no está confirmado.';
        }
      });
    } on IntentNotFoundException {
      if (mounted) {
        setState(() => _notes[d.commandId] = 'El enlace de consulta caducó (dura 24 horas). Puedes quitarla de aquí.');
      }
    } on AppException catch (e) {
      if (mounted) setState(() => _notes[d.commandId] = describeError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SectionCard(
        key: const Key('saved.donations'),
        title: 'Donaciones guardadas en este teléfono',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final d in _items) ...[
              Text(
                [if (d.campaignTitle.isNotEmpty) d.campaignTitle, formatMinorUnits(d.amount, d.currency)].join(' · '),
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(switch (d.status) {
                SavedDonationStatus.pending => 'Sin enviar: se enviará sola cuando haya conexión.',
                SavedDonationStatus.sent => 'Registrada. Completa el pago y consulta su estado.',
                SavedDonationStatus.failed => 'El servidor no la aceptó (la convocatoria puede estar cerrada).',
              }, style: TextStyle(color: muted)),
              if (_notes[d.commandId] case final note?) ...[const SizedBox(height: 4), Text(note)],
              if (_codes[d.commandId] case final code?) ...[
                const SizedBox(height: 8),
                SelectableText(code, style: const TextStyle(fontFamily: 'monospace')),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => Clipboard.setData(ClipboardData(text: code)),
                      child: const Text('Copiar código'),
                    ),
                    TextButton(
                      onPressed: () =>
                          Navigator.of(context)
                              .push(PaxPageRoute<void>(builder: (_) => TrackingScreen(initialCode: code))),
                      child: const Text('Ver el recorrido'),
                    ),
                  ],
                ),
              ],
              Wrap(
                spacing: 8,
                children: [
                  if (d.status == SavedDonationStatus.sent && d.paymentUrl != null)
                    FilledButton(
                      key: Key('saved.pay.${d.commandId}'),
                      onPressed: () => _pay(d),
                      child: const Text('Pagar'),
                    ),
                  if (d.status == SavedDonationStatus.sent)
                    TextButton(
                      key: Key('saved.status.${d.commandId}'),
                      onPressed: () => _status(d),
                      child: const Text('Consultar estado'),
                    ),
                  if (d.status != SavedDonationStatus.pending)
                    TextButton(
                      key: Key('saved.remove.${d.commandId}'),
                      onPressed: () => _services.donationQueue.remove(d.commandId),
                      child: const Text('Quitar'),
                    ),
                ],
              ),
              const Divider(),
            ],
          ],
        ),
      ),
    );
  }
}
