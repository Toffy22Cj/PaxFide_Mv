import 'package:flutter/material.dart';

import '../core/errors/app_exceptions.dart';
import '../core/offline/outbox_status.dart';
import '../features/auth/domain/session_controller.dart';
import '../features/donations/data/account_donations_api.dart';
import '../features/donations/presentation/my_donations_screen.dart';
import '../shared/widgets/pax_ui.dart';
import 'app_routes.dart';
import 'app_services.dart';
import 'app_shell.dart';
import 'qr_scanner_sheet.dart';

/// `/home` (Figma 01 · Inicio): saludo, resumen de "Tus donaciones" (de `GET /account/donations`), atajos a escanear y
/// seguir una donación y, según `/me`, las tarjetas de Operaciones y Predicción.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final AppServices _services = AppScope.of(context);
  List<AccountDonation>? _donations;
  bool _donationsFailed = false;
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
    setState(() => _donationsFailed = false);
    try {
      final d = await AccountDonationsApi(_services.apiClient).list();
      if (mounted) setState(() => _donations = d);
    } on AppException {
      if (mounted) setState(() => _donationsFailed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return AppShell(
      location: AppRoutes.home,
      title: 'Inicio',
      body: ListenableBuilder(
        listenable: _services.session,
        builder: (context, _) {
          final p = _services.session.principal;
          final loading = _services.session.profileStatus == ProfileStatus.loading;
          return RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (loading) const LinearProgressIndicator(),
                Text('Hola', style: text.headlineSmall),
                const SizedBox(height: 4),
                Text(
                  'Cada aporte tiene una historia. Consulta los hechos que la respaldan.',
                  style: text.bodyMedium?.copyWith(color: muted),
                ),
                const SizedBox(height: 16),
                _donationsCard(context),
                const SizedBox(height: 12),
                _Shortcut(
                  key: const Key('home.scan'),
                  icon: Icons.qr_code_scanner,
                  label: 'Escanear un código QR',
                  onTap: () => scanQr(context),
                ),
                const SizedBox(height: 10),
                _Shortcut(
                  key: const Key('home.tracking'),
                  icon: Icons.route_outlined,
                  label: 'Seguir una donación',
                  onTap: () => _services.router.push(AppRoutes.tracking),
                ),
                if (p?.showsOperatorActions ?? false) ...[const SizedBox(height: 12), _OperationsCard()],
                if (p?.showsPrediction ?? false) ...[
                  const SizedBox(height: 12),
                  SectionCard(
                    key: const Key('home.prediction'),
                    title: 'Predicción',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Estimación de una convocatoria · modelo con datos sintéticos',
                          style: TextStyle(color: muted),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () => _services.router.go(AppRoutes.prediction),
                          child: const Text('Ver predicción'),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _donationsCard(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final d = _donations;
    return HighlightCard(
      key: const Key('home.donations'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Tus donaciones', style: text.titleSmall),
          const SizedBox(height: 6),
          if (d == null && !_donationsFailed)
            const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: LinearProgressIndicator())
          else if (d == null)
            Row(
              children: [
                const Expanded(child: Text('No pudimos cargar tus donaciones.')),
                TextButton(onPressed: _load, child: const Text('Reintentar')),
              ],
            )
          else if (d.isEmpty)
            const Text('Todavía no hay donaciones hechas con esta cuenta.')
          else ...[
            Text(
              '${d.length} ${d.length == 1 ? 'donación' : 'donaciones'}',
              style: text.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text('La última: ${d.first.campaignTitle.isEmpty ? 'Convocatoria no disponible' : d.first.campaignTitle}'),
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerLeft, child: donationStatusChip(d.first.status)),
          ],
          const SizedBox(height: 12),
          OutlinedButton(
            key: const Key('home.allDonations'),
            onPressed: () => _services.router.go(AppRoutes.donations),
            child: const Text('Ver todas'),
          ),
        ],
      ),
    );
  }
}

/// Atajo a lo ancho: botón con borde, ícono a la izquierda y texto centrado.
class _Shortcut extends StatelessWidget {
  const _Shortcut({super.key, required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onTap,
    child: Row(
      children: [
        Icon(icon, size: 20),
        Expanded(child: Text(label, textAlign: TextAlign.center)),
        const SizedBox(width: 20),
      ],
    ),
  );
}

/// Empleado: cuántas operaciones tiene guardadas en el teléfono y el atajo para escanear un activo.
class _OperationsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final account = services.session.principal?.accountId;
    return HighlightCard(
      key: const Key('home.operations'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Operaciones', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          ListenableBuilder(
            listenable: services.syncEngine,
            builder: (context, _) => FutureBuilder<int>(
              future: account == null
                  ? Future.value(0)
                  : services.syncEngine
                        .entriesFor(account)
                        .then((all) => all.where((i) => i.status != OutboxStatus.acknowledged).length)
                        .catchError((_) => 0),
              builder: (context, snap) {
                final n = snap.data ?? 0;
                return Text(
                  n == 0
                      ? 'No hay operaciones pendientes en este dispositivo'
                      : '$n ${n == 1 ? 'operación pendiente' : 'operaciones pendientes'} en este dispositivo',
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => scanQr(context),
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Escanear activo'),
          ),
          TextButton(onPressed: () => services.router.go(AppRoutes.operator), child: const Text('Ir a Mi día')),
        ],
      ),
    );
  }
}
