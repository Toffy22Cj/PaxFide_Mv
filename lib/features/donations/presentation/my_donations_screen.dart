import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../app/app_services.dart';
import '../../../app/app_shell.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../shared/error_messages.dart';
import '../../../shared/money.dart';
import '../../../shared/widgets/state_views.dart';
import '../data/account_donations_api.dart';

String donationStatusLabel(String s) => switch (s) {
  'PENDING' => 'Pago pendiente',
  'CONFIRMED' => 'Pago confirmado',
  'FAILED' => 'Pago fallido',
  'EXPIRED_UNKNOWN' => 'Estado del pago desconocido',
  'FUNDING_REJECTED' => 'Fondos no aplicados',
  _ => s,
};

/// `/donations` (§12): solo lista, sin detalle (`/donations/:id` no existe). Muestra título de la convocatoria,
/// importe, moneda y estado. No muestra `intentId` ni el código de seguimiento (DDM-25).
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
          for (final d in items)
            Card(
              child: ListTile(
                title: Text(d.campaignTitle),
                subtitle: Text(donationStatusLabel(d.status)),
                trailing: Text(formatMinorUnits(d.amount, d.currency.isEmpty ? null : d.currency)),
              ),
            ),
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text(
              'Para ver el recorrido de una donación, usa su código de seguimiento en "Seguir una donación".',
            ),
          ),
        ],
      ),
    );
  }
}
