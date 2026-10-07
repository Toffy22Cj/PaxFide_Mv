import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../errors/app_exceptions.dart';
import '../storage/token_store.dart';
import 'api_client.dart';
import 'api_response.dart';
import 'auth_response_handler.dart';
import 'credential_mode.dart';

/// Implementación de [ApiClient] con `HttpClient` de `dart:io` (SDK, sin dependencias nuevas; DDM-04).
///
/// INVARIANTES (ADR-043 D4):
/// - Transporte puro: no conoce tipos de dominio, no genera `commandId`, no decide autorización.
/// - Credenciales no intercambiables: con `jwt` pone el JWT del [TokenStore]; con `tracking` exige que la feature
///   aporte su propia cabecera `Authorization` (el código de seguimiento) y nunca añade el JWT; con `none` no envía
///   `Authorization`. Una cabecera `Authorization` del llamante en modo `none`/`jwt` es un error de programación.
/// - Nunca registra (log) URL, cabeceras, cuerpos ni tokens.
/// - Cada respuesta pasa por [AuthResponseHandler] (T-1).
class HttpApiClient implements ApiClient {
  HttpApiClient({
    required this.baseUrl,
    required this.tokenStore,
    required this.authResponseHandler,
    HttpClient Function()? clientFactory,
    this.connectTimeout = const Duration(seconds: 10),
    this.responseTimeout = const Duration(seconds: 30),
  }) : _clientFactory = clientFactory ?? HttpClient.new;

  /// Base de la API, p. ej. `http://10.0.2.2:8080/api/v1`.
  final Uri baseUrl;
  final TokenStore tokenStore;
  final AuthResponseHandler authResponseHandler;
  final Duration connectTimeout;
  final Duration responseTimeout;
  final HttpClient Function() _clientFactory;

  @override
  Future<ApiResponse> get(
    String path, {
    Map<String, String>? queryParams,
    Map<String, String>? headers,
    required CredentialMode credentialMode,
  }) => _send('GET', path, queryParams, headers, null, credentialMode, null);

  @override
  Future<ApiResponse> post(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    required CredentialMode credentialMode,
    Future<void> Function()? beforeSend,
  }) => _send('POST', path, null, headers, body, credentialMode, beforeSend);

  Uri _resolve(String path, Map<String, String>? query) {
    final basePath = baseUrl.path.endsWith('/') ? baseUrl.path.substring(0, baseUrl.path.length - 1) : baseUrl.path;
    return baseUrl.replace(path: '$basePath$path', queryParameters: (query == null || query.isEmpty) ? null : query);
  }

  Future<ApiResponse> _send(
    String method,
    String path,
    Map<String, String>? query,
    Map<String, String>? headers,
    Map<String, dynamic>? body,
    CredentialMode mode,
    Future<void> Function()? beforeSend,
  ) async {
    final extra = Map<String, String>.from(headers ?? const {});
    final callerAuth = extra.keys.any((k) => k.toLowerCase() == 'authorization');
    switch (mode) {
      case CredentialMode.none:
      case CredentialMode.jwt:
        if (callerAuth) throw ArgumentError('Authorization no se pasa a mano con $mode');
      case CredentialMode.tracking:
        if (!callerAuth) throw ArgumentError('CredentialMode.tracking exige la cabecera Authorization');
    }

    if (mode == CredentialMode.jwt) {
      final token = await tokenStore.readToken();
      if (token == null || token.isEmpty) {
        // Sin JWT la petición no sale; para la sesión equivale a un 401 (T-1).
        await authResponseHandler.handleResponse(statusCode: 401, credentialMode: mode);
        return const ApiResponse(statusCode: 401);
      }
      extra['Authorization'] = 'Bearer $token';
    }

    final client = _clientFactory()..connectionTimeout = connectTimeout;
    try {
      final HttpClientRequest request;
      try {
        request = await client.openUrl(method, _resolve(path, query)).timeout(connectTimeout);
      } on IOException {
        throw const ConnectionNotEstablishedException();
      } on TimeoutException {
        throw const ConnectionNotEstablishedException();
      }

      request.followRedirects = false;
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      extra.forEach(request.headers.set);
      final bytes = body == null ? null : utf8.encode(jsonEncode(body));
      if (bytes != null) {
        request.headers.contentType = ContentType.json;
        request.contentLength = bytes.length;
      }

      if (beforeSend != null) {
        try {
          await beforeSend();
        } catch (_) {
          request.abort();
          rethrow;
        }
      }

      final int status;
      final String text;
      final Map<String, String> responseHeaders = {};
      try {
        if (bytes != null) request.add(bytes);
        final response = await request.close().timeout(responseTimeout);
        status = response.statusCode;
        response.headers.forEach((k, v) => responseHeaders[k] = v.join(','));
        text = await response.transform(utf8.decoder).join().timeout(responseTimeout);
      } on TimeoutException {
        throw const NetworkTimeoutException();
      } on IOException {
        throw const ConnectionInterruptedException();
      } on FormatException {
        throw const MalformedResponseException();
      }

      Map<String, dynamic>? data;
      if (text.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(text);
          if (decoded is Map<String, dynamic>) data = decoded;
        } on FormatException {
          data = null;
        }
      }

      await authResponseHandler.handleResponse(statusCode: status, credentialMode: mode);
      return ApiResponse(statusCode: status, data: data, headers: responseHeaders);
    } finally {
      client.close(force: true);
    }
  }
}
