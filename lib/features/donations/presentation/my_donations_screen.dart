import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../app/app_services.dart';
import '../../../app/app_shell.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../shared/error_messages.dart';
import '../../../shared/money.dart';
import '../../../shared/widgets/state_views.dart';
import '../../tracking/presentation/tracking_screen.dart';
import '../data/account_donations_api.dart';
import '../domain/achievements.dart';

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
    if (items == null) return const LoadingView();
    if (items.isEmpty) {
      return const MessageView(
        icon: Icons.favorite_outline,
        title: 'Todavía no hay donaciones hechas con esta cuenta.',
        detail: 'Las donaciones hechas sin entrar en la cuenta no aparecen aquí.',
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _AchievementsCard(achievementsFor(items)),
          const SizedBox(height: 12),
          for (final (i, d) in items.indexed)
            Card(
              child: ListTile(
                key: Key('donation.$i'),
                title: Text(_title(d)),
                subtitle: Text(donationStatusLabel(d.status)),
                trailing: Text(formatMinorUnits(d.amount, d.currency.isEmpty ? null : d.currency)),
                onTap: () => _showDetail(context, d),
              ),
            ),
          const Padding(padding: EdgeInsets.all(8), child: Text('Toca una donación para ver su detalle.')),
        ],
      ),
    );
  }
}

String _title(AccountDonation d) => d.campaignTitle.isEmpty ? 'Convocatoria no disponible' : d.campaignTitle;

/// M-16: detalle de una donación. "Ver el recorrido" abre el seguimiento con el código de la cuenta, sin escribirlo.
void _showDetail(BuildContext context, AccountDonation d) {
  showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    builder: (sheet) => Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        key: const Key('donation.detail'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_title(d), style: Theme.of(sheet).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(formatMinorUnits(d.amount, d.currency.isEmpty ? null : d.currency)),
          Text(donationStatusLabel(d.status)),
          const SizedBox(height: 16),
          if (d.trackingCode case final code?) ...[
            FilledButton.icon(
              key: const Key('donation.route'),
              icon: const Icon(Icons.route_outlined),
              label: const Text('Ver el recorrido'),
              onPressed: () {
                Navigator.of(sheet).pop();
                Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => TrackingScreen(initialCode: code)));
              },
            ),
          ] else
            const Text(
              'El recorrido estará disponible cuando el pago se confirme y los fondos se apliquen.',
              key: Key('donation.noRoute'),
            ),
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
