import 'package:flutter/material.dart';

import '../core/offline/outbox_status.dart';
import '../features/auth/domain/principal.dart';
import '../features/auth/domain/session_controller.dart';
import 'app_routes.dart';
import 'app_services.dart';
import 'qr_scanner_sheet.dart';
import 'theme_mode_button.dart';

class _Destination {
  const _Destination(this.route, this.label, this.icon);
  final String route;
  final String label;
  final IconData icon;
}

/// Pestaña "Escanear" del empleado: abre el escáner, no es una ruta.
const _scan = '#scan';

/// Destinos según `/me`. Es **representación**: el guard no lee roles y el backend autoriza cada petición.
List<_Destination> _destinationsFor(Principal? p) => (p?.showsOperatorActions ?? false)
    // Empleado (M-03): Mi día · Escanear (centro) · Pendientes. Cuenta (E-12) llega con la enmienda de ADR-043.
    ? [
        const _Destination(AppRoutes.operator, 'Mi día', Icons.today_outlined),
        const _Destination(_scan, 'Escanear', Icons.qr_code_scanner),
        const _Destination(AppRoutes.operatorPending, 'Pendientes', Icons.pending_actions),
        if (p?.showsPrediction ?? false)
          const _Destination(AppRoutes.prediction, 'Predicción', Icons.insights_outlined),
      ]
    : [
        const _Destination(AppRoutes.home, 'Inicio', Icons.home_outlined),
        const _Destination(AppRoutes.donations, 'Mis donaciones', Icons.favorite_outline),
        if (p?.showsOperatorActions ?? false)
          const _Destination(AppRoutes.operator, 'Operaciones', Icons.qr_code_scanner),
        if (p?.showsPrediction ?? false)
          const _Destination(AppRoutes.prediction, 'Predicción', Icons.insights_outlined),
      ];

/// Navegación adaptable de las rutas autenticadas: barra inferior en el móvil, carril lateral en anchos grandes.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.location, required this.title, required this.body, this.actions});

  final String location;
  final String title;
  final Widget body;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    return ListenableBuilder(
      listenable: services.session,
      builder: (context, _) {
        final destinations = _destinationsFor(services.session.principal);
        // Pendientes tiene su propia pestaña para el empleado; para el resto cuelga de Operaciones.
        final ownPending = destinations.any((d) => d.route == AppRoutes.operatorPending);
        final top = location.startsWith('/assets/') || (location == AppRoutes.operatorPending && !ownPending)
            ? AppRoutes.operator
            : location;
        final index = destinations.indexWhere((d) => d.route == top);
        void select(int i) =>
            destinations[i].route == _scan ? scanQr(context) : services.router.go(destinations[i].route);
        Widget icon(_Destination d) =>
            d.route == AppRoutes.operatorPending ? _PendingBadge(icon: d.icon) : Icon(d.icon);
        final appBar = AppBar(
          title: Text(title),
          actions: [
            ...?actions,
            const ThemeModeButton(),
            IconButton(tooltip: 'Salir', icon: const Icon(Icons.logout), onPressed: () => services.session.logout()),
          ],
        );
        final banner = services.session.profileStatus == ProfileStatus.unavailable
            ? MaterialBanner(
                content: const Text('No pudimos cargar tu perfil. Algunas opciones no se muestran.'),
                actions: [TextButton(onPressed: services.session.reloadProfile, child: const Text('Reintentar'))],
              )
            : null;
        final content = Column(
          children: [
            ?banner,
            Expanded(child: body),
          ],
        );

        return LayoutBuilder(
          builder: (context, c) {
            if (c.maxWidth >= 840 && destinations.length >= 2) {
              return Scaffold(
                appBar: appBar,
                body: Row(
                  children: [
                    NavigationRail(
                      selectedIndex: index < 0 ? null : index,
                      onDestinationSelected: select,
                      labelType: NavigationRailLabelType.all,
                      destinations: [
                        for (final d in destinations) NavigationRailDestination(icon: icon(d), label: Text(d.label)),
                      ],
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: content),
                  ],
                ),
              );
            }
            return Scaffold(
              appBar: appBar,
              body: content,
              bottomNavigationBar: destinations.length >= 2
                  ? NavigationBar(
                      selectedIndex: index < 0 ? 0 : index,
                      onDestinationSelected: select,
                      destinations: [
                        for (final d in destinations)
                          NavigationDestination(key: Key('nav.${d.label}'), icon: icon(d), label: d.label),
                      ],
                    )
                  : null,
            );
          },
        );
      },
    );
  }
}

/// Ícono de Pendientes con el número de operaciones guardadas en el teléfono por esta cuenta (sin las confirmadas).
class _PendingBadge extends StatelessWidget {
  const _PendingBadge({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final account = services.session.principal?.accountId;
    return ListenableBuilder(
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
          return Semantics(
            label: n == 1 ? '1 operación pendiente' : '$n operaciones pendientes',
            child: Badge(
              key: const Key('nav.pending.count'),
              isLabelVisible: n > 0,
              label: Text('$n'),
              child: Icon(icon),
            ),
          );
        },
      ),
    );
  }
}
