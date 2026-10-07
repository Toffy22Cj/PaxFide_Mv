import 'package:flutter/widgets.dart';

import '../core/network/api_client.dart';
import '../features/auth/data/auth_api.dart';
import '../features/auth/domain/session_controller.dart';
import 'app_config.dart';
import 'deep_link_parser.dart';
import 'pending_intent.dart';
import 'router/app_router_delegate.dart';

/// Dependencias de la app, construidas en `main.dart` (o en los tests con un `ApiClient` falso).
class AppServices {
  AppServices({
    required this.config,
    required this.apiClient,
    required this.session,
    required this.authApi,
    required this.pendingIntents,
  }) : deepLinkParser = DeepLinkParser(canonicalOrigin: config.publicOrigin);

  final AppConfig config;
  final ApiClient apiClient;
  final SessionController session;
  final AuthApi authApi;
  final PendingIntentHolder pendingIntents;
  final DeepLinkParser deepLinkParser;
  late final AppRouterDelegate router;
}

/// Acceso a [AppServices] desde la presentación.
class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.services, required super.child});

  final AppServices services;

  static AppServices of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope no encontrado');
    return scope!.services;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) => oldWidget.services != services;
}
