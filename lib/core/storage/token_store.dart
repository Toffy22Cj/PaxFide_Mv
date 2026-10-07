/// Contrato abstracto para el almacenamiento seguro de credenciales (ADR-043 D5).
abstract class TokenStore {
  Future<String?> readToken();
  Future<void> writeToken(String token);
  Future<void> clearToken();
}
