import 'package:paxfide_mobile/core/network/api_client.dart';
import 'package:paxfide_mobile/core/network/api_response.dart';
import 'package:paxfide_mobile/core/network/auth_response_handler.dart';
import 'package:paxfide_mobile/core/network/credential_mode.dart';
import 'package:paxfide_mobile/core/offline/outbox_item.dart';
import 'package:paxfide_mobile/core/storage/outbox_store.dart';
import 'package:paxfide_mobile/core/storage/secure_key_value_store.dart';
import 'package:paxfide_mobile/core/storage/token_store.dart';
import 'package:paxfide_mobile/features/auth/data/login_gateway.dart';
import 'package:paxfide_mobile/features/auth/data/me_gateway.dart';
import 'package:paxfide_mobile/features/auth/domain/principal.dart';

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
  Future<List<OutboxItem>> getItemsFor(String accountId) async =>
      items.values.where((i) => i.accountId == accountId).toList();

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

/// `ApiClient` falso: devuelve respuestas o lanza excepciones programadas y
/// registra cada llamada.
class FakeApiClient implements ApiClient {
  FakeApiClient({this.authHandler});

  /// Si se da, cada respuesta pasa por él, como en el cliente real (T-1).
  AuthResponseHandler? authHandler;
  final List<RecordedCall> calls = [];
  final List<Object> _queue = [];

  /// Respuestas por "MÉTODO ruta" (se usan si la cola está vacía).
  final Map<String, Object Function(RecordedCall call)> routes = {};

  /// Último recurso: si devuelve null, la llamada sin respuesta programada falla.
  Object? Function(RecordedCall call)? fallback;

  /// Programa la siguiente respuesta ([ApiResponse]) o excepción.
  void enqueue(Object responseOrError) => _queue.add(responseOrError);

  Future<ApiResponse> _next(RecordedCall call) async {
    calls.add(call);
    if (call.beforeSend != null) await call.beforeSend!();
    final Object r;
    if (_queue.isNotEmpty) {
      r = _queue.removeAt(0);
    } else if (routes.containsKey('${call.method} ${call.path}')) {
      r = routes['${call.method} ${call.path}']!(call);
    } else if (fallback?.call(call) case final Object f) {
      r = f;
    } else {
      throw StateError('FakeApiClient: sin respuesta programada para ${call.method} ${call.path}');
    }
    if (r is ApiResponse) {
      await authHandler?.handleResponse(statusCode: r.statusCode, credentialMode: call.credentialMode);
      return r;
    }
    throw r;
  }

  @override
  Future<ApiResponse> get(
    String path, {
    Map<String, String>? queryParams,
    Map<String, String>? headers,
    required CredentialMode credentialMode,
  }) =>
      _next(RecordedCall('GET', path, headers ?? const {}, null, credentialMode, null, queryParams));

  @override
  Future<ApiResponse> post(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    required CredentialMode credentialMode,
    Future<void> Function()? beforeSend,
  }) =>
      _next(RecordedCall('POST', path, headers ?? const {}, body, credentialMode, beforeSend));
}

class RecordedCall {
  RecordedCall(this.method, this.path, this.headers, this.body, this.credentialMode, this.beforeSend,
      [this.queryParams]);
  final String method;
  final String path;
  final Map<String, String> headers;
  final Map<String, dynamic>? body;
  final CredentialMode credentialMode;
  final Future<void> Function()? beforeSend;
  final Map<String, String>? queryParams;
}

class InMemorySecureKeyValueStore implements SecureKeyValueStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
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

/// MeGateway falso con resultado configurable.
class FakeMeGateway implements MeGateway {
  MeResult result;
  int calls = 0;

  FakeMeGateway(this.result);

  FakeMeGateway.principal(Principal principal) : result = MeSucceeded(principal);

  @override
  Future<MeResult> fetch(String token) async {
    calls++;
    return result;
  }
}

ApiResponse ok(Map<String, dynamic> data, [int status = 200]) => ApiResponse(statusCode: status, data: data);
ApiResponse status(int code) => ApiResponse(statusCode: code);

const donor = Principal(accountId: 'acc-donor');
const fieldOperator = Principal(
  accountId: 'acc-employee',
  organizationId: 'org-1',
  roles: {OrgRole.employee},
);
const administrator = Principal(
  accountId: 'acc-admin',
  organizationId: 'org-1',
  roles: {OrgRole.administrator},
);
const operatorAndAdmin = Principal(
  accountId: 'acc-both',
  organizationId: 'org-1',
  roles: {OrgRole.employee, OrgRole.administrator},
);
