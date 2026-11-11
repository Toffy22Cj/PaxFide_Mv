import 'package:flutter/material.dart';

import '../features/auth/domain/principal.dart';
import '../features/auth/domain/session_controller.dart';
import 'app_routes.dart';
import 'app_services.dart';
import 'pending_count.dart';
import 'qr_scanner_sheet.dart';
import 'text_size_button.dart';
import 'theme_mode_button.dart';
import '../shared/widgets/pax_app_bar.dart';

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
    // Empleado (M-03, E-07): Mi día · Escanear (centro) · Pendientes · Cuenta. Mi día es su pantalla principal: la
    // raíz de la app (`/home`) le muestra Mi día, así que la pestaña vuelve a la raíz y nunca apila otra pantalla.
    ? [
        const _Destination(AppRoutes.home, 'Mi día', Icons.today_outlined),
        const _Destination(_scan, 'Escanear', Icons.qr_code_scanner),
        const _Destination(AppRoutes.operatorPending, 'Pendientes', Icons.pending_actions),
        if (p?.showsPrediction ?? false)
          const _Destination(AppRoutes.prediction, 'Predicción', Icons.insights_outlined),
        const _Destination(AppRoutes.account, 'Cuenta', Icons.person_outline),
      ]
    // Donante y demás perfiles: Inicio · Mis donaciones · Cuenta.
    : [
        const _Destination(AppRoutes.home, 'Inicio', Icons.home_outlined),
        const _Destination(AppRoutes.donations, 'Mis donaciones', Icons.favorite_outline),
        if (p?.showsPrediction ?? false)
          const _Destination(AppRoutes.prediction, 'Predicción', Icons.insights_outlined),
        const _Destination(AppRoutes.account, 'Cuenta', Icons.person_outline),
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
      listenable: Listenable.merge([services.session, services.offline]),
      builder: (context, _) {
        final destinations = _destinationsFor(services.session.principal);
        // Pendientes tiene su propia pestaña para el empleado; para el resto cuelga de Operaciones.
        final ownPending = destinations.any((d) => d.route == AppRoutes.operatorPending);
        final employee = services.session.principal?.showsOperatorActions ?? false;
        // La pestaña que se marca: la de la pantalla actual. Una pantalla que no es pestaña (la ficha de un activo,
        // el seguimiento) no marca ninguna: marcar otra hace creer que se está en ella.
        final top = employee && location == AppRoutes.operator
            ? AppRoutes.home
            : (location == AppRoutes.operatorPending && !ownPending)
            ? AppRoutes.operator
            : location;
        final index = destinations.indexWhere((d) => d.route == top);
        void select(int i) =>
            destinations[i].route == _scan ? scanQr(context) : services.router.go(destinations[i].route);
        Widget icon(_Destination d) =>
            d.route == AppRoutes.operatorPending ? _PendingBadge(icon: d.icon) : Icon(d.icon);
        final appBar = PaxAppBar(
          title: Text(title),
          actions: [...?actions, const TextSizeButton(), const ThemeModeButton()],
        );
        final banner = switch (services.session.profileStatus) {
          ProfileStatus.unavailable => MaterialBanner(
            content: const Text('No pudimos cargar tu perfil. Algunas opciones no se muestran.'),
            actions: [TextButton(onPressed: services.session.reloadProfile, child: const Text('Reintentar'))],
          ),
          // Enmienda 4, S1 y S2: sin red, con el perfil o las lecturas guardadas
          _ when services.session.profileStatus == ProfileStatus.offline || services.offline.value => MaterialBanner(
            key: const Key('shell.offline'),
            content: const Text('Sin conexión: trabajas con los datos guardados. Lo que hagas se enviará solo.'),
            actions: [TextButton(onPressed: services.session.reloadProfile, child: const Text('Reintentar'))],
          ),
          _ => null,
        };
        // M-03: deslizar a los lados cambia de pestaña (Escanear no, porque abre la cámara); en una pantalla que no
        // es pestaña (la ficha de un activo), deslizar hacia la derecha vuelve atrás.
        final swipeable = [
          for (final d in destinations)
            if (d.route != _scan) d.route,
        ];
        void swipe(DragEndDetails d) {
          final v = d.primaryVelocity ?? 0;
          if (v.abs() < 300) return;
          final i = swipeable.indexOf(top);
          if (i < 0) {
            if (v > 0 && services.router.stack.length > 1) services.router.back();
            return;
          }
          final next = i + (v < 0 ? 1 : -1);
          if (next >= 0 && next < swipeable.length) services.router.go(swipeable[next]);
        }

        final content = GestureDetector(
          key: const Key('shell.swipe'),
          behavior: HitTestBehavior.translucent,
          onHorizontalDragEnd: swipe,
          child: Column(
            children: [
              ?banner,
              Expanded(child: body),
            ],
          ),
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
                      // Sin pestaña actual: ninguna se ve marcada.
                      indicatorColor: index < 0 ? Colors.transparent : null,
                      labelTextStyle: index < 0 ? _unselected(Theme.of(context).textTheme.labelMedium) : null,
                      onDestinationSelected: select,
                      destinations: [
                        for (final (i, d) in destinations.indexed)
                          NavigationDestination(
                            key: Key('nav.${d.label}'),
                            icon: icon(d),
                            // Sin pestaña actual, la primera se dibuja igual que las demás.
                            selectedIcon: index < 0 && i == 0
                                ? IconTheme.merge(
                                    data: IconThemeData(color: Theme.of(context).colorScheme.onSurfaceVariant),
                                    child: icon(d),
                                  )
                                : null,
                            label: d.label,
                          ),
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

WidgetStateProperty<TextStyle?> _unselected(TextStyle? base) => WidgetStatePropertyAll(base);

/// Ícono de Pendientes con el número de operaciones guardadas en el teléfono por esta cuenta (sin las confirmadas).
class _PendingBadge extends StatelessWidget {
  const _PendingBadge({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) => PendingCountBuilder(
    builder: (context, n) => Semantics(
      label: n == 1 ? '1 operación pendiente' : '$n operaciones pendientes',
      child: Badge(key: const Key('nav.pending.count'), isLabelVisible: n > 0, label: Text('$n'), child: Icon(icon)),
    ),
  );
}
