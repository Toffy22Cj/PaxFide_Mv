import 'package:flutter/material.dart';

import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/physical_assets/presentation/asset_screen.dart';
import '../features/physical_assets/presentation/operator_screen.dart';
import '../features/physical_assets/presentation/pending_operations_screen.dart';
import '../shared/widgets/state_views.dart';
import 'app_routes.dart';
import 'app_shell.dart';
import 'home_screen.dart';

/// Ruta del árbol → pantalla. Las rutas que aún no tienen pantalla muestran un aviso neutro, sin datos.
Widget buildPage(BuildContext context, String location) {
  switch (location) {
    case AppRoutes.login:
      return const LoginScreen();
    case AppRoutes.register:
      return const RegisterScreen();
    case AppRoutes.home:
      return const HomeScreen();
    case AppRoutes.operator:
      return const OperatorScreen();
    case AppRoutes.operatorPending:
      return const PendingOperationsScreen();
  }
  final params = AppRoutes.paramsOf(location) ?? const {};
  final assetRef = params['assetRef'];
  if (assetRef != null) return AssetScreen(key: ValueKey(assetRef), assetRef: assetRef);
  final category = AppRoutes.categorize(location);
  const notYet = MessageView(icon: Icons.construction, title: 'Esta pantalla todavía no está disponible.');
  if (category == RouteCategory.authenticated) {
    return AppShell(location: location, title: 'PaxFide', body: notYet);
  }
  return Scaffold(
    appBar: AppBar(title: const Text('PaxFide')),
    body: notYet,
  );
}
