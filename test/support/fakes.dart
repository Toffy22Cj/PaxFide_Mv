import 'dart:async';

import 'package:paxfide_mobile/core/links/link_opener.dart';
import 'package:paxfide_mobile/core/media/photo_picker.dart';
import 'package:paxfide_mobile/core/network/api_client.dart';
import 'package:paxfide_mobile/core/network/api_response.dart';
import 'package:paxfide_mobile/core/network/auth_response_handler.dart';
import 'package:paxfide_mobile/core/network/credential_mode.dart';
import 'package:paxfide_mobile/core/offline/outbox_item.dart';
import 'package:paxfide_mobile/core/storage/outbox_store.dart';
import 'package:paxfide_mobile/core/storage/secure_key_value_store.dart';
import 'package:paxfide_mobile/core/storage/token_store.dart';
import 'package:paxfide_mobile/features/auth/biometrics/biometric_authenticator.dart';

class InMemoryTokenStore implements TokenStore {
  String? _token;

  @override
  Future<String?> readToken() async => _token;

  @override
  Future<void> writeToken(String token, {bool remember = true}) async => _token = token;

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

  /// Rutas que se responden siempre con [routes], aunque haya respuestas en la cola (lecturas de fondo, como el
  /// resumen de donaciones de Inicio, que no deben quedarse con respuestas pensadas para otra llamada).
  final Set<String> routeFirst = {};

  /// Último recurso: si devuelve `null`, la llamada sin respuesta programada falla.
  Object? Function(RecordedCall call)? fallback;

  /// Programa la siguiente respuesta ([ApiResponse]) o excepción.
  void enqueue(Object responseOrError) => _queue.add(responseOrError);

  Future<ApiResponse> _next(RecordedCall call) async {
    calls.add(call);
    if (call.beforeSend != null) await call.beforeSend!();
    Object r;
    final key = '${call.method} ${call.path}';
    if (routeFirst.contains(key) && routes.containsKey(key)) {
      r = routes[key]!(call);
    } else if (_queue.isNotEmpty) {
      r = _queue.removeAt(0);
    } else if (routes.containsKey('${call.method} ${call.path}')) {
      r = routes['${call.method} ${call.path}']!(call);
    } else if (fallback?.call(call) case final Object f) {
      r = f;
    } else {
      throw StateError('FakeApiClient: sin respuesta programada para ${call.method} ${call.path}');
    }
    // Una ruta puede devolver un Future para simular una respuesta que tarda (estados de carga).
    if (r is Future<Object>) r = await r;
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

  @override
  Future<ApiResponse> put(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    required CredentialMode credentialMode,
  }) => _next(RecordedCall('PUT', path, headers ?? const {}, body, credentialMode, null));

  /// El archivo se registra como `{field, filename, contentType, length}`; los bytes, en [RecordedCall.bytes].
  @override
  Future<ApiResponse> postFile(
    String path, {
    required String field,
    required String filename,
    required String contentType,
    required List<int> bytes,
    required CredentialMode credentialMode,
  }) => _next(
    RecordedCall(
      'POST',
      path,
      const {},
      {'field': field, 'filename': filename, 'contentType': contentType, 'length': bytes.length},
      credentialMode,
      null,
      bytes: bytes,
    ),
  );
}

class RecordedCall {
  RecordedCall(this.method, this.path, this.headers, this.body, this.credentialMode, this.beforeSend, {this.bytes});
  final List<int>? bytes;
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

/// Biometría del teléfono simulada. Con [pending] la huella queda esperando hasta [complete].
class FakeBiometricAuthenticator implements BiometricAuthenticator {
  FakeBiometricAuthenticator({this.available = true, this.result = BiometricCheck.success, this.pending = false});

  bool available;
  BiometricCheck result;
  bool pending;
  int calls = 0;
  Completer<BiometricCheck>? _waiting;

  void complete(BiometricCheck r) => _waiting?.complete(r);

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<BiometricCheck> authenticate(String reason) {
    calls++;
    if (!pending) return Future.value(result);
    _waiting = Completer<BiometricCheck>();
    return _waiting!.future;
  }
}

/// Navegador simulado: registra los enlaces abiertos.
class FakeLinkOpener implements LinkOpener {
  final opened = <Uri>[];
  bool succeed = true;

  @override
  Future<bool> open(Uri url) async {
    opened.add(url);
    return succeed;
  }
}

/// Cámara y galería simuladas: devuelven [next] (null = la persona cancela) y cuentan las llamadas.
class FakePhotoPicker implements PhotoPicker {
  PickedPhoto? next = const PickedPhoto(
    bytes: [0xFF, 0xD8, 0xFF, 0xD9],
    contentType: 'image/jpeg',
    filename: 'entrega.jpg',
  );
  Object? error;
  int calls = 0;

  Future<PickedPhoto?> _pick() async {
    calls++;
    if (error case final Object e) throw e;
    return next;
  }

  @override
  Future<PickedPhoto?> takePhoto() => _pick();

  @override
  Future<PickedPhoto?> choosePhoto() => _pick();
}
