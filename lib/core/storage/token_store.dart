import 'secure_key_value_store.dart';

/// Almacenamiento seguro de credenciales (ADR-043 D5). El JWT solo vive aquí.
abstract class TokenStore {
  Future<String?> readToken();
  Future<void> writeToken(String token);
  Future<void> clearToken();
}

class SecureTokenStore implements TokenStore {
  const SecureTokenStore(this._store);

  static const _key = 'paxfide.session.jwt';

  final SecureKeyValueStore _store;

  @override
  Future<String?> readToken() => _store.read(_key);

  @override
  Future<void> writeToken(String token) => _store.write(_key, token);

  @override
  Future<void> clearToken() => _store.delete(_key);
}
