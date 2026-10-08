import 'package:paxfide_mobile/core/network/api_client.dart';
import 'package:paxfide_mobile/core/network/api_response.dart';
import 'package:paxfide_mobile/core/network/auth_response_handler.dart';
import 'package:paxfide_mobile/core/network/credential_mode.dart';
import 'package:paxfide_mobile/core/offline/outbox_item.dart';
import 'package:paxfide_mobile/core/storage/outbox_store.dart';
import 'package:paxfide_mobile/core/storage/secure_key_value_store.dart';
import 'package:paxfide_mobile/core/storage/token_store.dart';

class InMemoryTokenStore implements TokenStore {
  String? _token;

  @override
  Future<String?> readToken() async => _token;

  @override
  Future<void> writeToken(String token) async => _token = token;

  @override
  Future<void> clearToken() async => _token = null;
}

class InMemoryOutboxStore implements OutboxStore {
  InMemoryOutboxStore([List<OutboxItem> initial = const []]) {
    for (final i in initial) {
      _items[i.commandId] = i;
    }
  }

  final Map<String, OutboxItem> _items = {};

  @override
  Future<List<OutboxItem>> getAllItems() async => _items.values.toList();

  @override
  Future<void> saveItem(OutboxItem item) async => _items[item.commandId] = item;

  @override
  Future<void> updateStatus(String commandId, OutboxItem updatedItem) async => _items[commandId] = updatedItem;

  @override
  Future<void> deleteItem(String commandId) async => _items.remove(commandId);
}

/// `ApiClient` falso: devuelve respuestas o lanza excepciones programadas y registra cada llamada.
class FakeApiClient implements ApiClient {
  FakeApiClient({this.authHandler});

  /// Si se da, cada respuesta pasa por él, como en el cliente real (T-1).
  AuthResponseHandler? authHandler;
  final List<RecordedCall> calls = [];
  final List<Object> _queue = [];

  /// Respuestas por ruta para las pruebas de flujo (se usan si la cola está vacía).
  final Map<String, Object Function(RecordedCall call)> routes = {};

  /// Último recurso: si devuelve `null`, la llamada sin respuesta programada falla.
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
  }) => _next(RecordedCall('GET', path, headers ?? const {}, null, credentialMode, null));

  @override
  Future<ApiResponse> post(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    required CredentialMode credentialMode,
    Future<void> Function()? beforeSend,
  }) => _next(RecordedCall('POST', path, headers ?? const {}, body, credentialMode, beforeSend));
}

class RecordedCall {
  RecordedCall(this.method, this.path, this.headers, this.body, this.credentialMode, this.beforeSend);
  final String method;
  final String path;
  final Map<String, String> headers;
  final Map<String, dynamic>? body;
  final CredentialMode credentialMode;
  final Future<void> Function()? beforeSend;
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
