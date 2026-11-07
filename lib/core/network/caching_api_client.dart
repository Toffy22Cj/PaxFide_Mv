import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../errors/app_exceptions.dart';
import '../storage/secure_key_value_store.dart';
import 'api_client.dart';
import 'api_response.dart';
import 'credential_mode.dart';

/// Lecturas sin conexión (Enmienda 4 de ADR-043, S2). Envuelve el cliente real:
/// - un `GET` sin sesión (`none`) o con la de la cuenta (`jwt`) que responde 2xx guarda su cuerpo, cifrado, en el
///   almacén seguro (D5/D12), por cuenta;
/// - si el mismo `GET` falla por la red, devuelve el cuerpo guardado y marca [offline];
/// - nunca guarda el seguimiento por código (`tracking`), ni los campos de [secretFields] de ninguna respuesta, lo que lleva cabeceras propias (`Intent-Token`), `GET /me`
///   (lo guarda la sesión, S1) ni respuestas de error; los comandos (`POST`/`PUT`) pasan sin tocar.
class CachingApiClient implements ApiClient {
  CachingApiClient(this._inner, this._store, {required this.accountId});

  final ApiClient _inner;
  final SecureKeyValueStore _store;

  /// La cuenta de la sesión: lo guardado con JWT es de ella sola (H2).
  final String? Function() accountId;

  static const prefix = 'paxfide.cache.';

  /// Tamaño máximo de un cuerpo guardado (el almacén seguro no es para cargas grandes).
  static const maxBytes = 256 * 1024;

  /// `true` mientras lo último que se leyó salió de lo guardado (sin red); `false` en cuanto la red responde.
  final ValueNotifier<bool> offline = ValueNotifier(false);

  String? _key(String path, Map<String, String>? query, Map<String, String>? headers, CredentialMode mode) {
    if (mode == CredentialMode.tracking || (headers?.isNotEmpty ?? false) || path == '/me') return null;
    final owner = mode == CredentialMode.jwt ? accountId() : 'public';
    if (owner == null) return null;
    final q = query == null || query.isEmpty ? '' : '?${Uri(queryParameters: query).query}';
    return '$prefix$owner.$path$q';
  }

  @override
  Future<ApiResponse> get(
    String path, {
    Map<String, String>? queryParams,
    Map<String, String>? headers,
    required CredentialMode credentialMode,
  }) async {
    final key = _key(path, queryParams, headers, credentialMode);
    try {
      final r = await _inner.get(path, queryParams: queryParams, headers: headers, credentialMode: credentialMode);
      offline.value = false;
      if (key != null && r.isSuccess && r.data != null) {
        final body = jsonEncode(_withoutSecrets(r.data));
        if (body.length <= maxBytes) await _quietly(() => _store.write(key, body));
      }
      return r;
    } on TransportException catch (e) {
      // Sin JWT la petición no salió por falta de sesión, no de red: no se sirve nada guardado.
      if (key == null || e is MissingCredentialException) rethrow;
      final saved = await _read(key);
      if (saved == null) rethrow;
      offline.value = true;
      return ApiResponse(statusCode: 200, data: saved, headers: const {'x-paxfide-cached': 'true'});
    }
  }

  /// Credenciales que nunca se guardan (ADR-043 §0): el código de seguimiento que trae «Mis donaciones», y los tokens.
  static const secretFields = {'trackingCode', 'statusToken', 'token', 'deviceToken'};

  static Object? _withoutSecrets(Object? v) => switch (v) {
    Map() => {
      for (final e in v.entries)
        if (!secretFields.contains(e.key)) e.key: _withoutSecrets(e.value),
    },
    List() => [for (final x in v) _withoutSecrets(x)],
    _ => v,
  };

  Future<Map<String, dynamic>?> _read(String key) async {
    try {
      final raw = await _store.read(key);
      final j = raw == null ? null : jsonDecode(raw);
      return j is Map<String, dynamic> ? j : null;
    } on Object {
      return null;
    }
  }

  static Future<void> _quietly(Future<void> Function() body) async {
    try {
      await body();
    } on Object {
      // si no se puede guardar, la lectura sigue igual
    }
  }

  @override
  Future<ApiResponse> post(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    required CredentialMode credentialMode,
    Future<void> Function()? beforeSend,
  }) => _inner.post(path, body: body, headers: headers, credentialMode: credentialMode, beforeSend: beforeSend);

  @override
  Future<ApiResponse> put(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    required CredentialMode credentialMode,
  }) => _inner.put(path, body: body, headers: headers, credentialMode: credentialMode);

  @override
  Future<ApiResponse> postFile(
    String path, {
    required String field,
    required String filename,
    required String contentType,
    required List<int> bytes,
    required CredentialMode credentialMode,
  }) => _inner.postFile(
    path,
    field: field,
    filename: filename,
    contentType: contentType,
    bytes: bytes,
    credentialMode: credentialMode,
  );
}
