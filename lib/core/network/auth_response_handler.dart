import '../storage/token_store.dart';
import 'credential_mode.dart';

/// Callback para notificar que la sesión debe transicionar a LOGGED_OUT (D3 T-1).
typedef OnSessionLoggedOutCallback = void Function();

/// Manejador de respuestas de autenticación en la capa de red (ADR-043 D3, D4).
class AuthResponseHandler {
  final TokenStore tokenStore;
  final OnSessionLoggedOutCallback onSessionLoggedOut;

  const AuthResponseHandler({required this.tokenStore, required this.onSessionLoggedOut});

  /// Procesa el código HTTP y aplica T-1 si corresponde.
  Future<void> handleResponse({required int statusCode, required CredentialMode credentialMode}) async {
    if (statusCode != 401) {
      return;
    }

    if (credentialMode == CredentialMode.jwt) {
      await tokenStore.clearToken();
      onSessionLoggedOut();
      return;
    }
  }
}
