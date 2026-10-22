import 'secure_key_value_store.dart';

/// Almacenamiento seguro de credenciales (ADR-043 D5). El JWT solo vive aquí.
abstract class TokenStore {
  Future<String?> readToken();

  /// Con [remember] en false ("Recordarme en este teléfono" desmarcado) el token solo vive en memoria: al cerrar la
  /// app hay que volver a entrar.
  Future<void> writeToken(String token, {bool remember = true});
  Future<void> clearToken();
}

class SecureTokenStore implements TokenStore {
  SecureTokenStore(this._store);

  static const _key = 'paxfide.session.jwt';

  final SecureKeyValueStore _store;

  /// Token de una sesión que no se recuerda en el teléfono.
  String? _memory;

  @override
  Future<String?> readToken() async => _memory ?? await _store.read(_key);

  @override
  Future<void> writeToken(String token, {bool remember = true}) async {
    if (remember) {
      _memory = null;
      await _store.write(_key, token);
    } else {
      _memory = token;
      await _store.delete(_key);
    }
  }

  @override
  Future<void> clearToken() async {
    _memory = null;
    await _store.delete(_key);
  }
}
