import 'package:flutter/widgets.dart';

import '../core/network/api_client.dart';
import '../core/offline/sync_engine.dart';
import '../core/storage/device_credential_store.dart';
import '../core/storage/outbox_store.dart';
import '../features/auth/biometrics/biometric_authenticator.dart';
import '../features/auth/biometrics/biometric_login.dart';
import '../features/auth/data/auth_api.dart';
import '../features/auth/domain/session_controller.dart';
import '../features/campaigns/domain/organization_verification.dart';
import '../features/donations/domain/impact.dart';
import '../features/donations/domain/receipt.dart';
import '../shared/theme/theme_controller.dart';
import 'app_config.dart';
import 'deep_link_parser.dart';
import 'pending_intent.dart';
import 'qr_scanner_sheet.dart';
import 'router/app_router_delegate.dart';

/// Dependencias de la app, construidas en `main.dart` (o en los tests con un `ApiClient` falso).
class AppServices {
  AppServices({
    required this.config,
    required this.apiClient,
    required this.session,
    required this.authApi,
    required this.pendingIntents,
    required this.outboxStore,
    required this.syncEngine,
    this.qrScannerBuilder = defaultQrScanner,
    this.organizationVerification = const PublicFieldVerification(),
    this.impactSource = const UnavailableImpactSource(),
    this.receiptSource = const UnavailableReceiptSource(),
    this.receiptSharer = const UnavailableReceiptSharer(),
    ThemeController? theme,
    DeviceCredentialStore? deviceCredentialStore,
    BiometricAuthenticator biometricAuthenticator = const UnavailableBiometricAuthenticator(),
  }) : deepLinkParser = DeepLinkParser(canonicalOrigin: config.publicOrigin),
       theme = theme ?? ThemeController(),
       biometricLogin = BiometricLogin(
         api: authApi,
         store: deviceCredentialStore ?? MemoryDeviceCredentialStore(),
         authenticator: biometricAuthenticator,
       );

  final AppConfig config;
  final ApiClient apiClient;
  final SessionController session;
  final AuthApi authApi;
  final PendingIntentHolder pendingIntents;
  final DeepLinkParser deepLinkParser;
  final QrScannerBuilder qrScannerBuilder;
  final OutboxStore outboxStore;
  final SyncEngine syncEngine;

  /// Insignia de organización verificada (M-07).
  final OrganizationVerification organizationVerification;

  /// Panel "Mi impacto" (M-21).
  final ImpactSource impactSource;

  /// Comprobante de donación y cómo compartirlo (M-22).
  final ReceiptSource receiptSource;
  final ReceiptSharer receiptSharer;

  /// Modo claro, oscuro o "como el teléfono", recordado entre aperturas.
  final ThemeController theme;
  late final AppRouterDelegate router;

  /// Entrar con huella o rostro, solo desde el login (M-28).
  final BiometricLogin biometricLogin;
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
