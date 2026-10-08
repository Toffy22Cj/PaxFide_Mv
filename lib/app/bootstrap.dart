import '../core/network/api_client.dart';
import '../core/network/auth_response_handler.dart';
import '../core/network/http_api_client.dart';
import '../core/offline/outbox_recovery.dart';
import '../core/offline/sync_engine.dart';
import '../core/storage/outbox_store.dart';
import '../core/storage/secure_key_value_store.dart';
import '../core/storage/token_store.dart';
import '../features/auth/data/auth_api.dart';
import '../features/auth/domain/session_controller.dart';
import '../shared/widgets/state_views.dart';
import 'app_config.dart';
import 'app_pages.dart';
import 'app_services.dart';
import 'navigation_store.dart';
import 'pending_intent.dart';
import 'qr_scanner_sheet.dart';
import 'router/app_router_delegate.dart';

/// Construye las dependencias. [apiClientFactory] permite inyectar un `ApiClient` falso en los tests.
AppServices buildServices({
  required AppConfig config,
  required SecureKeyValueStore secureStore,
  ApiClient Function(TokenStore tokenStore, AuthResponseHandler handler)? apiClientFactory,
  QrScannerBuilder qrScannerBuilder = defaultQrScanner,
}) {
  final tokenStore = SecureTokenStore(secureStore);
  late final SessionController session;
  final handler = AuthResponseHandler(tokenStore: tokenStore, onSessionLoggedOut: () => session.onUnauthorized());
  final api =
      apiClientFactory?.call(tokenStore, handler) ??
      HttpApiClient(baseUrl: config.apiBaseUrl!, tokenStore: tokenStore, authResponseHandler: handler);
  final authApi = AuthApi(api);
  session = SessionController(tokenStore: tokenStore, authApi: authApi);
  final outboxStore = SecureOutboxStore(secureStore);
  final services = AppServices(
    config: config,
    apiClient: api,
    session: session,
    authApi: authApi,
    pendingIntents: PendingIntentHolder(),
    qrScannerBuilder: qrScannerBuilder,
    outboxStore: outboxStore,
    syncEngine: SyncEngine(store: outboxStore, apiClient: api),
  );
  services.router = AppRouterDelegate(
    session: session,
    navigationStore: NavigationStore(secureStore),
    pendingIntents: services.pendingIntents,
    pageBuilder: buildPage,
    waitingBuilder: (_) => const WaitingView(),
  );
  return services;
}

/// T-2 corre antes que nada: toda entrada `IN_FLIGHT` de una ejecución anterior pasa a `AMBIGUOUS` (nunca a
/// `PENDING`). Si el almacén no se puede leer, no se toca y la pantalla de pendientes lo muestra.
Future<void> runOutboxRecovery(AppServices services) async {
  try {
    await OutboxRecovery(services.outboxStore).executeRecoveryT2();
  } on OutboxStoreUnreadableException {
    // Sin sobrescribir; se informa en /operator/pending.
  }
}

/// Arranque: T-2, posición restaurable y sesión (UNKNOWN → RESTORING → …). El router ya está activo (G-1 a).
Future<void> startServices(AppServices services) async {
  await runOutboxRecovery(services);
  await services.router.loadRestorable();
  await services.session.restore();
}
