import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../app/app_services.dart';
import '../../../app/app_shell.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../shared/error_messages.dart';
import '../../../shared/dates.dart';
import '../../../shared/money.dart';
import '../../../shared/motion/pax_motion.dart';
import '../../../shared/widgets/pax_ui.dart';
import '../../../shared/widgets/loaders.dart';
import '../../../shared/widgets/state_views.dart';
import '../../tracking/presentation/tracking_screen.dart';
import '../data/account_donations_api.dart';
import '../domain/achievements.dart';
import '../domain/receipt.dart';
import 'impact_card.dart';
import 'receipt_view.dart';
import '../../../shared/motion/pax_route.dart';

/// Chip del estado del pago, con el tono del Figma (confirmado en verde, pendiente en amarillo, fallos en rojo).
Widget donationStatusChip(String status) => StatusChip(
  donationStatusLabel(status),
  key: Key('donation.status.$status'),
  icon: switch (status) {
    'CONFIRMED' => Icons.check_circle_outline,
    'PENDING' => Icons.credit_card,
    'EXPIRED_UNKNOWN' => Icons.help_outline,
    _ => Icons.error_outline,
  },
  tone: switch (status) {
    'CONFIRMED' => Tone.success,
    'PENDING' => Tone.pending,
    'EXPIRED_UNKNOWN' => Tone.neutral,
    _ => Tone.error,
  },
);

String donationStatusLabel(String s) => switch (s) {
  'PENDING' => 'Pago pendiente',
  'CONFIRMED' => 'Pago confirmado',
  'FAILED' => 'Pago fallido',
  'EXPIRED_UNKNOWN' => 'Estado del pago desconocido',
  'FUNDING_REJECTED' => 'Fondos no aplicados',
  _ => s,
};

/// `/donations` (§12): lista con título de la convocatoria, importe, moneda y estado. El detalle (M-16) es una hoja
/// transitoria, no una ruta (`/donations/:id` no existe). No muestra `intentId`; el código de seguimiento solo
/// aparece en el detalle, en memoria (decisión 3).
class MyDonationsScreen extends StatefulWidget {
  const MyDonationsScreen({super.key});

  @override
  State<MyDonationsScreen> createState() => _MyDonationsScreenState();
}

class _MyDonationsScreenState extends State<MyDonationsScreen> {
  late final AccountDonationsApi _api = AccountDonationsApi(AppScope.of(context).apiClient);
  List<AccountDonation>? _items;
  Object? _error;
  DonationFilter _filter = DonationFilter.all;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _items = null;
      _error = null;
    });
    try {
      final items = await _api.list();
      if (mounted) setState(() => _items = items);
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(location: AppRoutes.donations, title: 'Mis donaciones', body: _body());
  }

  Widget _body() {
    if (_error != null) return ErrorRetryView(message: describeError(_error!), onRetry: _load);
    final items = _items;
    // Carga con el esqueleto, como la web (A-5).
    if (items == null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [Skeleton.list(count: 4, label: 'Cargando tus donaciones')],
      );
    }
    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: const [
            SizedBox(height: 80),
            MessageView(
              icon: Icons.favorite_outline,
              title: 'Todavía no hay donaciones hechas con esta cuenta.',
              detail: 'Las donaciones hechas sin entrar en la cuenta no aparecen aquí.',
            ),
          ],
        ),
      );
    }
    final shown = items.where(_filter.matches).toList();
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${items.length} ${items.length == 1 ? 'donación' : 'donaciones'} · Desliza hacia abajo para '
                  'actualizar',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(color: muted),
                ),
              ),
              // D-F15: «Seguir con un código» arriba de las donaciones.
              TextButton(
                key: const Key('donations.trackCode'),
                onPressed: () => AppScope.of(context).router.push(AppRoutes.tracking),
                child: const Text('Seguir con un código'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SummaryCard(items),
          const SizedBox(height: 12),
          // M-15: filtros por estado del pago.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final f in DonationFilter.values) ...[
                  ChoiceChip(
                    key: Key('donations.filter.${f.name}'),
                    label: Text(f.label),
                    selected: _filter == f,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _filter = f),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (shown.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No hay donaciones con este filtro.', key: Key('donations.filter.empty')),
            ),
          for (final d in shown)
            Card(
              key: Key('donation.${items.indexOf(d)}'),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _showDetail(context, d),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_title(d), style: Theme.of(context).textTheme.titleSmall),
                      if (_meta(d) case final meta? when meta.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(meta, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted)),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        formatMinorUnits(d.amount, d.currency.isEmpty ? null : d.currency),
                        key: Key('donation.amount.${items.indexOf(d)}'),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      donationStatusChip(d.status),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          ImpactCard(source: AppScope.of(context).impactSource),
          _AchievementsCard(achievementsFor(items)),
          const SizedBox(height: 12),
          Text(
            'Toca una donación para ver su detalle y su recorrido. Las hechas sin cuenta se siguen con su código.',
            style: TextStyle(color: muted),
          ),
          TextButton(
            onPressed: () => AppScope.of(context).router.push(AppRoutes.tracking),
            child: const Text('Seguir una donación'),
          ),
        ],
      ),
    );
  }
}

/// Filtros de "Mis donaciones" (M-15).
enum DonationFilter {
  all('Todas'),
  confirmed('Confirmadas'),
  pending('Pendientes'),
  problem('Con problema');

  const DonationFilter(this.label);
  final String label;

  bool matches(AccountDonation d) => switch (this) {
    all => true,
    confirmed => d.status == 'CONFIRMED',
    pending => d.status == 'PENDING',
    problem => d.status != 'CONFIRMED' && d.status != 'PENDING',
  };
}

/// M-15: cuánto se ha donado con pago confirmado (por moneda) y cuántas donaciones hay.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard(this.items);
  final List<AccountDonation> items;

  @override
  Widget build(BuildContext context) {
    final totals = <String, BigInt>{};
    for (final d in items.where((d) => d.status == 'CONFIRMED')) {
      final v = BigInt.tryParse(d.amount);
      if (v != null) totals[d.currency] = (totals[d.currency] ?? BigInt.zero) + v;
    }
    final confirmed = items.where((d) => d.status == 'CONFIRMED').length;
    final text = Theme.of(context).textTheme;
    return HighlightCard(
      key: const Key('donations.summary'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Has donado', style: text.titleSmall),
          const SizedBox(height: 4),
          if (totals.isEmpty) Text('Aún sin pagos confirmados', style: text.titleLarge),
          for (final e in totals.entries)
            Text(
              formatMinorUnits(e.value, e.key.isEmpty ? null : e.key),
              style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          const SizedBox(height: 4),
          Text('${items.length} ${items.length == 1 ? 'donación' : 'donaciones'} · $confirmed con pago confirmado'),
        ],
      ),
    );
  }
}

String _title(AccountDonation d) => d.campaignTitle.isEmpty ? 'Convocatoria no disponible' : d.campaignTitle;

/// Fecha · organización · medio de pago, cada uno solo si llega (D-P11).
String? _meta(AccountDonation d) => [
  if (d.createdAt case final c?) shortDate(c),
  ?d.organizationName,
  if (d.paymentMethod case final m?) paymentMethodLabel(m),
].join(' · ');

/// M-16: detalle de una donación. "Ver el recorrido" abre el seguimiento con el código de la cuenta, sin escribirlo.
void _showDetail(BuildContext context, AccountDonation d) {
  final services = AppScope.of(context);
  showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    sheetAnimationStyle: AnimationStyle(
      duration: PaxMotion.of(context, const Duration(milliseconds: 350)),
      reverseDuration: PaxMotion.of(context, PaxMotion.normal),
      curve: Curves.easeOutCubic,
    ),
    builder: (sheet) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        key: const Key('donation.detail'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_title(d), style: Theme.of(sheet).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (d.organizationName case final o?) LabeledValue('Organización', o),
          if (d.createdAt case final c?) LabeledValue('Fecha', shortDateTime(c)),
          LabeledValue('Monto', formatMinorUnits(d.amount, d.currency.isEmpty ? null : d.currency)),
          if (d.paymentMethod case final m?) LabeledValue('Medio de pago', paymentMethodLabel(m)),
          LabeledValue('Estado', donationStatusLabel(d.status)),
          if (d.publicCode case final code?)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('donation.campaign'),
                onPressed: () {
                  Navigator.of(sheet).pop();
                  services.router.push(AppRoutes.campaignPath(code));
                },
                child: const Text('Ver convocatoria'),
              ),
            ),
          const SizedBox(height: 16),
          if (d.trackingCode case final code?) ...[
            FilledButton.icon(
              key: const Key('donation.route'),
              icon: const Icon(Icons.route_outlined),
              label: const Text('Ver el recorrido'),
              onPressed: () {
                Navigator.of(sheet).pop();
                Navigator.of(context).push(PaxPageRoute<void>(builder: (_) => TrackingScreen(initialCode: code)));
              },
            ),
          ] else
            const Text(
              'El recorrido estará disponible cuando el pago se confirme y los fondos se apliquen.',
              key: Key('donation.noRoute'),
            ),
          if (AppScope.of(context).receiptSource.isAvailable && d.status == 'CONFIRMED') ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const Key('donation.receipt'),
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('Ver comprobante'),
              onPressed: () {
                Navigator.of(sheet).pop();
                _showReceipt(context, d);
              },
            ),
          ],
        ],
      ),
    ),
  );
}

/// M-22: comprobante como imagen; "Compartir" solo si el teléfono puede compartirla.
Future<void> _showReceipt(BuildContext context, AccountDonation d) async {
  final services = AppScope.of(context);
  final messenger = ScaffoldMessenger.of(context);
  DonationReceipt? receipt;
  try {
    receipt = await services.receiptSource.receiptFor(d);
  } on Object {
    receipt = null;
  }
  if (!context.mounted) return;
  if (receipt == null) {
    messenger.showSnackBar(const SnackBar(content: Text('No pudimos obtener el comprobante. Inténtalo más tarde.')));
    return;
  }
  final view = ReceiptView(receipt: receipt);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheet) => SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          view,
          const SizedBox(height: 16),
          if (services.receiptSharer.isAvailable)
            FilledButton.icon(
              key: const Key('receipt.share'),
              icon: const Icon(Icons.share_outlined),
              label: const Text('Compartir'),
              onPressed: () async {
                final png = await view.capture();
                if (png != null) {
                  await services.receiptSharer.sharePng(
                    Uint8List.fromList(png),
                    fileName: 'comprobante-${receipt!.receiptNumber}.png',
                  );
                }
              },
            ),
          TextButton(onPressed: () => Navigator.of(sheet).pop(), child: const Text('Cerrar')),
        ],
      ),
    ),
  );
}

/// "Tus logros" (M-23): solo para el propio donante, sin compartir.
class _AchievementsCard extends StatelessWidget {
  const _AchievementsCard(this.achievements);
  final List<Achievement> achievements;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final done = achievements.where((a) => a.unlocked).length;
    return Card(
      key: const Key('achievements'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tus logros · $done de ${achievements.length}', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final a in achievements)
                  Tooltip(
                    message: a.unlocked ? a.title : a.howTo,
                    child: Chip(
                      key: Key('achievement.${a.id}.${a.unlocked ? 'on' : 'off'}'),
                      avatar: Icon(
                        a.unlocked ? Icons.emoji_events : Icons.lock_outline,
                        size: 18,
                        color: a.unlocked ? scheme.onTertiaryContainer : scheme.onSurfaceVariant,
                      ),
                      label: Text(a.unlocked ? a.title : a.howTo),
                      backgroundColor: a.unlocked ? scheme.tertiaryContainer : null,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
