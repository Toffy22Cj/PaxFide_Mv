import 'token_store.dart';

/// Implementación provisional de [TokenStore] en memoria.
///
/// ADR-043 D5 fija `flutter_secure_storage` para el `TokenStore`; esta clase
/// solo existe hasta añadir esa implementación. Consecuencia mientras se use:
/// al reiniciar la app no hay token y la sesión se restaura como LOGGED_OUT.
class InMemoryTokenStore implements TokenStore {
  String? _token;

  @override
  Future<String?> readToken() async => _token;

  @override
  Future<void> writeToken(String token) async {
    _token = token;
  }

  @override
  Future<void> clearToken() async {
    _token = null;
  }
}
