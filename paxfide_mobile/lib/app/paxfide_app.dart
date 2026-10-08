import 'package:flutter/material.dart';

import '../shared/theme/pax_theme.dart';

import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/campaigns/presentation/campaign_public_screen.dart';
import '../features/donations/presentation/my_donations_view.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/physical_assets/presentation/asset_screen.dart';
import '../features/physical_assets/presentation/operator_screen.dart';
import '../features/physical_assets/presentation/pending_operations_screen.dart';
import '../features/prediction/presentation/prediction_screen.dart';
import '../features/tracking/presentation/tracking_screen.dart';
import 'app_router.dart';
import 'app_routes.dart';
import 'app_services.dart';

/// Raíz de la app. Recibe sus dependencias para poder probarla con dobles.
class PaxFideApp extends StatefulWidget {
  final AppServices services;

  /// Ruta de arranque. Sin deep link ni estado restaurado, `/home`: el guard
  /// la deja esperar durante RESTORING y la manda a `/login` si no hay sesión.
  final String initialRoute;

  const PaxFideApp({
    super.key,
    required this.services,
    this.initialRoute = AppRoutes.home,
  });

  @override
  State<PaxFideApp> createState() => _PaxFideAppState();
}

class _PaxFideAppState extends State<PaxFideApp> {
  late final AppRouter _router = AppRouter(
    session: widget.services.session,
    pendingIntents: widget.services.pendingIntents,
    screens: {
      AppRoutes.login: (context, match) => LoginScreen(
            loginGateway: widget.services.loginGateway,
            session: widget.services.session,
            pendingIntents: widget.services.pendingIntents,
          ),
      AppRoutes.register: (context, match) => const RegisterScreen(),
      AppRoutes.home: (context, match) => HomeScreen(session: widget.services.session),
      AppRoutes.donations: (context, match) => const MyDonationsScreen(),
      AppRoutes.tracking: (context, match) => const TrackingScreen(),
      AppRoutes.campaignPublic: (context, match) => CampaignPublicScreen(publicCode: match.params['publicCode']!),
      AppRoutes.operator: (context, match) => const OperatorScreen(),
      AppRoutes.operatorPending: (context, match) => const PendingOperationsScreen(),
      AppRoutes.asset: (context, match) => AssetScreen(assetRef: match.params['assetRef']!),
      AppRoutes.prediction: (context, match) => const PredictionScreen(),
    },
  );

  @override
  Widget build(BuildContext context) {
    return AppScope(
      services: widget.services,
      child: ValueListenableBuilder<bool>(
        valueListenable: widget.services.darkMode,
        builder: (context, dark, _) => MaterialApp(
          title: 'PaxFide',
          debugShowCheckedModeBanner: false,
          theme: paxTheme(dark: dark),
          initialRoute: widget.initialRoute,
          onGenerateInitialRoutes: _router.onGenerateInitialRoutes,
          onGenerateRoute: _router.onGenerateRoute,
        ),
      ),
    );
  }
}
