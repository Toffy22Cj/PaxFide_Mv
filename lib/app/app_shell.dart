import 'package:flutter/material.dart';

import '../features/auth/domain/principal.dart';
import '../features/auth/domain/session_controller.dart';
import 'app_routes.dart';
import 'app_services.dart';

class _Destination {
  const _Destination(this.route, this.label, this.icon);
  final String route;
  final String label;
  final IconData icon;
}

/// Destinos según `/me`. Es **representación**: el guard no lee roles y el backend autoriza cada petición.
List<_Destination> _destinationsFor(Principal? p) => [
  const _Destination(AppRoutes.home, 'Inicio', Icons.home_outlined),
  const _Destination(AppRoutes.donations, 'Mis donaciones', Icons.favorite_outline),
  if (p?.showsOperatorActions ?? false) const _Destination(AppRoutes.operator, 'Operaciones', Icons.qr_code_scanner),
  if (p?.showsPrediction ?? false) const _Destination(AppRoutes.prediction, 'Predicción', Icons.insights_outlined),
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
        final top = location.startsWith('/assets/') || location == AppRoutes.operatorPending
            ? AppRoutes.operator
            : location;
        final index = destinations.indexWhere((d) => d.route == top);
        void select(int i) => services.router.go(destinations[i].route);
        final appBar = AppBar(
          title: Text(title),
          actions: [
            ...?actions,
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
                        for (final d in destinations)
                          NavigationRailDestination(icon: Icon(d.icon), label: Text(d.label)),
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
                        for (final d in destinations) NavigationDestination(icon: Icon(d.icon), label: d.label),
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
