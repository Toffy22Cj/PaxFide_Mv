import 'package:flutter/widgets.dart';

import '../core/network/api_client.dart';
import '../core/network/auth_response_handler.dart';
import '../core/network/http_api_client.dart';
import '../core/network/unconfigured_api_client.dart';
import '../core/offline/outbox_recovery.dart';
import '../core/offline/sync_engine.dart';
import '../core/storage/outbox_store.dart';
import '../core/storage/secure_key_value_store.dart';
import '../core/storage/token_store.dart';
import '../features/auth/data/auth_api.dart';
import '../features/auth/data/http_auth_gateways.dart';
import '../features/auth/data/login_gateway.dart';
import '../features/auth/data/me_gateway.dart';
import '../features/auth/data/session_controller.dart';
import '../features/campaigns/data/campaign_api.dart';
import '../features/donations/data/account_donations_api.dart';
import '../features/donations/data/donation_intent_api.dart';
import '../features/physical_assets/data/physical_asset_api.dart';
import '../features/physical_assets/domain/asset_operations.dart';
import '../features/prediction/data/prediction_api.dart';
import '../features/tracking/data/tracking_api.dart';
import 'app_config.dart';
import 'deep_link_parser.dart';
import 'pending_intent.dart';
import 'public_links.dart';
import 'qr_scanner_sheet.dart';

/// Dependencias de la app, construidas en `main.dart` o en los tests con un
/// `ApiClient` falso.
class AppServices {
  AppServices({
    required this.config,
    required this.apiClient,
    required this.session,
    required this.loginGateway,
    required this.outboxStore,
    this.qrScannerBuilder = defaultQrScanner,
  })  : authApi = AuthApi(apiClient),
        campaignApi = CampaignApi(apiClient),
        donationIntentApi = DonationIntentApi(apiClient),
        accountDonationsApi = AccountDonationsApi(apiClient),
        trackingApi = TrackingApi(apiClient),
        physicalAssetApi = PhysicalAssetApi(apiClient),
        predictionApi = PredictionApi(apiClient),
        deepLinkParser = DeepLinkParser.forOrigin(config.publicOrigin),
        publicLinks = PublicLinks(config.publicOrigin),
        syncEngine = SyncEngine(store: outboxStore, apiClient: apiClient) {
    assetOperations = AssetOperations(engine: syncEngine, api: physicalAssetApi);
  }

  final AppConfig config;
  final ApiClient apiClient;
  final SessionController session;
  final LoginGateway loginGateway;
  final OutboxStore outboxStore;
  final QrScannerBuilder qrScannerBuilder;

  final AuthApi authApi;
  final CampaignApi campaignApi;
  final DonationIntentApi donationIntentApi;
  final AccountDonationsApi accountDonationsApi;
  final TrackingApi trackingApi;
  final PhysicalAssetApi physicalAssetApi;
  final PredictionApi predictionApi;
  final DeepLinkParser deepLinkParser;
  final PublicLinks publicLinks;
  final SyncEngine syncEngine;
  late final AssetOperations assetOperations;
  final PendingIntentHolder pendingIntents = PendingIntentHolder();
}

/// Construye las dependencias reales.
///
/// - Con `PAXFIDE_API_BASE_URL`: cliente HTTP real (`dart:io`, DDM-04).
/// - Sin él: ninguna petición sale ([UnconfiguredApiClient]) y el login
///   informa de que no está disponible.
/// - `PAXFIDE_FAKE_AUTH=true` (solo desarrollo): login y `/me` simulados.
AppServices buildServices({
  required AppConfig config,
  required SecureKeyValueStore secureStore,
  ApiClient Function(TokenStore tokenStore, AuthResponseHandler handler)? apiClientFactory,
}) {
  final tokenStore = SecureTokenStore(secureStore);
  late final SessionController session;
  final handler = AuthResponseHandler(
    tokenStore: tokenStore,
    onSessionLoggedOut: () => session.markLoggedOutByUnauthorized(),
  );
  final baseUrl = config.apiBaseUrl;
  final ApiClient api = apiClientFactory?.call(tokenStore, handler) ??
      (baseUrl == null
          ? const UnconfiguredApiClient()
          : HttpApiClient(baseUrl: baseUrl, tokenStore: tokenStore, authResponseHandler: handler));
  final authApi = AuthApi(api);

  final LoginGateway loginGateway;
  final MeGateway meGateway;
  if (kFakeAuthEnabled) {
    loginGateway = const DevFakeLoginGateway();
    meGateway = DevFakeMeGateway.fromEnvironment();
  } else {
    loginGateway = HttpLoginGateway(authApi);
    meGateway = HttpMeGateway(authApi);
  }
  session = SessionController(tokenStore: tokenStore, meGateway: meGateway);

  return AppServices(
    config: config,
    apiClient: api,
    session: session,
    loginGateway: loginGateway,
    outboxStore: SecureOutboxStore(secureStore),
  );
}

/// Arranque: T-2 antes que nada (toda entrada `IN_FLIGHT` de la ejecución
/// anterior pasa a `AMBIGUOUS`, nunca a `PENDING`) y después la sesión. Si el
/// almacén no se puede leer, no se toca y `/operator/pending` lo muestra.
Future<void> startServices(AppServices services) async {
  try {
    await OutboxRecovery(services.outboxStore).executeRecoveryT2();
  } on OutboxStoreUnreadableException {
    // Sin sobrescribir (DDM-23).
  }
  await services.session.restore();
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
