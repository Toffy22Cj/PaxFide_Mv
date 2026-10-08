import 'package:flutter/material.dart';

import '../features/auth/domain/session_controller.dart';
import 'app_routes.dart';
import 'app_services.dart';
import 'app_shell.dart';
import 'qr_scanner_sheet.dart';

/// `/home`. Con `/me` disponible, las entradas se representan según la cuenta (sustituye la regla provisional (i)
/// de §12, ver DDM-09). Sin cifras ni listas: no hay datos que mostrar aquí.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    return AppShell(
      location: AppRoutes.home,
      title: 'PaxFide',
      body: ListenableBuilder(
        listenable: services.session,
        builder: (context, _) {
          final p = services.session.principal;
          final loading = services.session.profileStatus == ProfileStatus.loading;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (loading) const LinearProgressIndicator(),
              _Entry(
                icon: Icons.favorite_outline,
                title: 'Mis donaciones',
                subtitle: 'Las donaciones hechas con esta cuenta',
                onTap: () => services.router.go(AppRoutes.donations),
              ),
              _Entry(
                icon: Icons.qr_code_scanner,
                title: 'Escanear un código QR',
                subtitle: 'Convocatoria, seguimiento o activo',
                onTap: () => scanQr(context),
              ),
              _Entry(
                icon: Icons.search,
                title: 'Seguir una donación',
                subtitle: 'Con el código de seguimiento que recibiste',
                onTap: () => services.router.push(AppRoutes.tracking),
              ),
              if (p?.showsOperatorActions ?? false)
                _Entry(
                  icon: Icons.qr_code_scanner,
                  title: 'Operaciones',
                  subtitle: 'Escanear activos y operaciones pendientes',
                  onTap: () => services.router.go(AppRoutes.operator),
                ),
              if (p?.showsPrediction ?? false)
                _Entry(
                  icon: Icons.insights_outlined,
                  title: 'Predicción',
                  subtitle: 'Estimación de una convocatoria (modelo con datos sintéticos)',
                  onTap: () => services.router.go(AppRoutes.prediction),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Entry extends StatelessWidget {
  const _Entry({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}
