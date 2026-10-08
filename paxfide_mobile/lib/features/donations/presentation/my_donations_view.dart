import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../shared/error_messages.dart';
import '../../../shared/labels.dart';
import '../../../shared/money.dart';
import '../../../shared/theme/pax_theme.dart';
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
        title: 'Aún no has donado con esta cuenta.',
        detail: 'Elige una causa en "Causas" para hacer tu primera donación.',
      );
    }
    final p = PaxPalette.of(context);
    return Column(
      key: const Key('my-donations'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final d in items)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: p.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.campaignTitle.isEmpty ? 'Causa no disponible' : d.campaignTitle,
                          style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: p.text)),
                      const SizedBox(height: 4),
                      StatusChip(intentStatusLabel(d.status),
                          color: d.status == 'CONFIRMED' ? paxAccent : const Color(0xFFF59E0B)),
                    ],
                  ),
                ),
                Text(formatMinorUnits(d.amount, d.currency),
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: p.text)),
              ],
            ),
          ),
        const SizedBox(height: 4),
        Text(
          'Para ver a dónde llegó una donación, usa su código en "Seguimiento".',
          style: TextStyle(fontSize: 12.5, color: p.textMuted),
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
