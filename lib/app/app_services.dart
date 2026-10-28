import 'package:flutter/widgets.dart';

import '../core/links/link_opener.dart';
import '../core/network/api_client.dart';
import '../core/offline/sync_engine.dart';
import '../core/storage/device_credential_store.dart';
import '../core/storage/outbox_store.dart';
import '../features/auth/biometrics/biometric_authenticator.dart';
import '../features/auth/biometrics/biometric_login.dart';
import '../features/auth/data/auth_api.dart';
import '../features/auth/domain/session_controller.dart';
import '../features/campaigns/data/campaign_api.dart';
import '../features/campaigns/domain/campaign_search.dart';
import '../features/campaigns/domain/public_campaign_search.dart';
import '../features/campaigns/domain/organization_verification.dart';
import '../features/donations/data/account_impact_api.dart';
import '../features/donations/domain/impact.dart';
import '../features/donations/domain/receipt.dart';
import '../shared/theme/text_size_controller.dart';
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
    CampaignSearch? campaignSearch,
    ImpactSource? impactSource,
    this.receiptSource = const UnavailableReceiptSource(),
    this.receiptSharer = const UnavailableReceiptSharer(),
    this.linkOpener = const UrlLauncherLinkOpener(),
    ThemeController? theme,
    TextSizeController? textSize,
    DeviceCredentialStore? deviceCredentialStore,
    BiometricAuthenticator biometricAuthenticator = const UnavailableBiometricAuthenticator(),
  }) : deepLinkParser = DeepLinkParser(canonicalOrigin: config.publicOrigin),
       theme = theme ?? ThemeController(),
       campaignSearch = campaignSearch ?? PublicCampaignSearch(CampaignApi(apiClient)),
       impactSource = impactSource ?? ApiImpactSource(AccountImpactApi(apiClient)),
       textSize = textSize ?? TextSizeController(),
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

  /// Catálogo de convocatorias con búsqueda (M-10, decisión 5).
  final CampaignSearch campaignSearch;

  /// Panel "Mi impacto" (M-21).
  final ImpactSource impactSource;

  /// Comprobante de donación y cómo compartirlo (M-22).
  final ReceiptSource receiptSource;
  final ReceiptSharer receiptSharer;

  /// Abre enlaces fuera de la app (M-12).
  final LinkOpener linkOpener;

  /// Modo claro, oscuro o "como el teléfono", recordado entre aperturas.
  final ThemeController theme;

  /// Tamaño del texto elegido en la app (M-04), recordado entre aperturas.
  final TextSizeController textSize;
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

  static AppServices? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()?.services;

  @override
  bool updateShouldNotify(AppScope oldWidget) => oldWidget.services != services;
}
