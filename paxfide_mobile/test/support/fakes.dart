import 'package:paxfide_mobile/core/network/api_client.dart';
import 'package:paxfide_mobile/core/network/api_response.dart';
import 'package:paxfide_mobile/core/network/credential_mode.dart';
import 'package:paxfide_mobile/core/offline/outbox_item.dart';
import 'package:paxfide_mobile/core/storage/outbox_store.dart';
import 'package:paxfide_mobile/core/storage/token_store.dart';
import 'package:paxfide_mobile/features/auth/data/login_gateway.dart';

/// TokenStore falso que registra cada llamada.
class FakeTokenStore implements TokenStore {
  String? token;
  int writes = 0;
  int clears = 0;
  bool throwOnRead = false;

  FakeTokenStore({this.token});

  @override
  Future<String?> readToken() async {
    if (throwOnRead) throw StateError('fallo de lectura simulado');
    return token;
  }

  @override
  Future<void> writeToken(String token) async {
    writes++;
    this.token = token;
  }

  @override
  Future<void> clearToken() async {
    clears++;
    token = null;
  }
}

/// OutboxStore falso en memoria que registra cada escritura.
class FakeOutboxStore implements OutboxStore {
  final Map<String, OutboxItem> items = {};
  final List<String> updatedIds = [];
  final List<String> savedIds = [];
  final List<String> deletedIds = [];

  FakeOutboxStore([List<OutboxItem> initial = const []]) {
    for (final item in initial) {
      items[item.commandId] = item;
    }
  }

  int get writeCount => updatedIds.length + savedIds.length + deletedIds.length;

  @override
  Future<List<OutboxItem>> getAllItems() async => items.values.toList();

  @override
  Future<void> saveItem(OutboxItem item) async {
    savedIds.add(item.commandId);
    items[item.commandId] = item;
  }

  @override
  Future<void> updateStatus(String commandId, OutboxItem updatedItem) async {
    updatedIds.add(commandId);
    items[commandId] = updatedItem;
  }

  @override
  Future<void> deleteItem(String commandId) async {
    deletedIds.add(commandId);
    items.remove(commandId);
  }
}

/// Petición registrada por [FakeApiClient].
class RecordedRequest {
  final String method;
  final String path;
  final CredentialMode credentialMode;
  const RecordedRequest(this.method, this.path, this.credentialMode);
}

/// ApiClient falso: devuelve la respuesta configurada o lanza el error
/// configurado, y registra cada petición.
class FakeApiClient implements ApiClient {
  ApiResponse response;
  Object? error;
  final List<RecordedRequest> requests = [];

  FakeApiClient({this.response = const ApiResponse(statusCode: 200), this.error});

  @override
  Future<ApiResponse> get(
    String path, {
    Map<String, String>? queryParams,
    Map<String, String>? headers,
    required CredentialMode credentialMode,
  }) async {
    requests.add(RecordedRequest('GET', path, credentialMode));
    if (error != null) throw error!;
    return response;
  }

  @override
  Future<ApiResponse> post(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    required CredentialMode credentialMode,
  }) async {
    requests.add(RecordedRequest('POST', path, credentialMode));
    if (error != null) throw error!;
    return response;
  }
}

/// LoginGateway falso con resultado configurable.
class FakeLoginGateway implements LoginGateway {
  LoginResult result;
  int calls = 0;

  FakeLoginGateway(this.result);

  @override
  Future<LoginResult> login({required String email, required String password}) async {
    calls++;
    return result;
  }
}
