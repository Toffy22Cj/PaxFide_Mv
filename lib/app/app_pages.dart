import 'package:flutter/material.dart';

import '../features/account/presentation/account_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/campaigns/presentation/campaign_public_screen.dart';
import '../features/campaigns/presentation/my_campaigns_screen.dart';
import '../features/donations/presentation/donate_sheet.dart';
import '../features/donations/presentation/my_donations_screen.dart';
import '../features/prediction/presentation/prediction_screen.dart';
import '../features/tracking/presentation/tracking_screen.dart';
import '../features/welcome/presentation/welcome_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/physical_assets/presentation/asset_qr_screen.dart';
import '../features/physical_assets/presentation/asset_screen.dart';
import '../features/physical_assets/presentation/operator_screen.dart';
import '../features/physical_assets/presentation/pending_operations_screen.dart';
import '../shared/widgets/state_views.dart';
import 'app_routes.dart';
import 'app_services.dart';
import 'app_shell.dart';
import 'home_screen.dart';
import 'text_size_button.dart';
import 'theme_mode_button.dart';
import '../shared/widgets/pax_app_bar.dart';

/// Ruta del árbol → pantalla. Las rutas que aún no tienen pantalla muestran un aviso neutro, sin datos.
Widget buildPage(BuildContext context, String location) {
  switch (location) {
    case AppRoutes.welcome:
      return const WelcomeScreen();
    case AppRoutes.login:
      return const LoginScreen();
    case AppRoutes.register:
      return const RegisterScreen();
    case AppRoutes.home:
      // El empleado empieza en Mi día (M-03): su raíz es esa pantalla, no un Inicio aparte.
      return const _HomeForProfile();
    case AppRoutes.operator:
      return const OperatorScreen();
    case AppRoutes.operatorPending:
      return const PendingOperationsScreen();
    case AppRoutes.tracking:
      return const TrackingScreen();
    case AppRoutes.donations:
      return const MyDonationsScreen();
    case AppRoutes.prediction:
      return const PredictionScreen();
    case AppRoutes.account:
      return const AccountScreen();
    case AppRoutes.myCampaigns:
      return const MyCampaignsScreen();
  }
  final params = AppRoutes.paramsOf(location) ?? const {};
  final assetRef = params['assetRef'];
  if (assetRef != null && AppRoutes.isAssetQr(location)) {
    return AssetQrScreen(key: ValueKey('qr-$assetRef'), assetRef: assetRef);
  }
  if (assetRef != null) return AssetScreen(key: ValueKey(assetRef), assetRef: assetRef);
  final publicCode = params['publicCode'];
  if (publicCode != null) {
    return CampaignPublicScreen(
      key: ValueKey(publicCode),
      publicCode: publicCode,
      actionsBuilder: (context, campaign) => donateAction(context, campaign, publicCode),
    );
  }
  final category = AppRoutes.categorize(location);
  const notYet = MessageView(icon: Icons.construction, title: 'Esta pantalla todavía no está disponible.');
  if (category == RouteCategory.authenticated) {
    return AppShell(location: location, title: 'PaxFide', body: notYet);
  }
  return Scaffold(
    appBar: PaxAppBar(title: const Text('PaxFide'), actions: const [TextSizeButton(), ThemeModeButton()]),
    body: notYet,
  );
}

/// La raíz según `/me`: Mi día para el empleado, Inicio para el resto. Mientras carga el perfil, Inicio.
class _HomeForProfile extends StatelessWidget {
  const _HomeForProfile();

  @override
  Widget build(BuildContext context) {
    final session = AppScope.of(context).session;
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) => (session.principal?.showsOperatorActions ?? false)
          ? const OperatorScreen(location: AppRoutes.home)
          : const HomeScreen(),
    );
  }
}
