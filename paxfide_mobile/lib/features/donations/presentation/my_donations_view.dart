import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../shared/error_messages.dart';
import '../../../shared/labels.dart';
import '../../../shared/money.dart';
import '../../../shared/widgets/state_views.dart';
import '../data/account_donations_api.dart';

/// `GET /account/donations`: una página de hasta 100. No muestra ni guarda
/// `intentId` ni `trackingCode` (DDM-25).
class MyDonationsView extends StatefulWidget {
  const MyDonationsView({super.key});

  @override
  State<MyDonationsView> createState() => _MyDonationsViewState();
}

class _MyDonationsViewState extends State<MyDonationsView> {
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
      _error = null;
      _items = null;
    });
    try {
      final items = await AppScope.of(context).accountDonationsApi.list();
      if (mounted) setState(() => _items = items);
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = _error;
    if (e != null) return ErrorRetryView(message: describeError(e), onRetry: _load);
    final items = _items;
    if (items == null) return const LoadingView();
    if (items.isEmpty) {
      return const MessageView(
        icon: Icons.volunteer_activism_outlined,
        title: 'Aún no tienes donaciones con esta cuenta.',
        detail: 'Las donaciones hechas sin iniciar sesión no aparecen aquí.',
      );
    }
    final theme = Theme.of(context);
    return Column(
      key: const Key('my-donations'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final d in items)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: Text(d.campaignTitle.isEmpty ? 'Convocatoria no disponible' : d.campaignTitle),
              subtitle: Text(intentStatusLabel(d.status)),
              trailing: Text(formatMinorUnits(d.amount, d.currency), style: theme.textTheme.titleSmall),
            ),
          ),
        Text(
          'Para ver el seguimiento de una donación, escribe su código en "Seguimiento".',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// `/donations`.
class MyDonationsScreen extends StatelessWidget {
  const MyDonationsScreen({super.key});

  @override
  Widget build(BuildContext context) => const AppPage(title: 'Mis donaciones', body: MyDonationsView());
}
