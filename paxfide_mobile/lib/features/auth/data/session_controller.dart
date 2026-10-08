import 'package:flutter/foundation.dart';

import '../../../core/storage/token_store.dart';
import '../domain/session_state.dart';

/// Lanzada cuando se intenta una transición de sesión que la máquina de
/// ADR-043 D3 no permite (regla 2.6: excepción nombrada, no genérica).
class InvalidSessionTransitionException implements Exception {
  final SessionStatus from;
  final String operation;

  const InvalidSessionTransitionException(this.from, this.operation);

  @override
  String toString() =>
      'InvalidSessionTransitionException: "$operation" no está permitido desde $from';
}

/// Dueño único de la máquina de sesión (ADR-043 D3).
///
/// - Emite cada cambio de [SessionState]; el router reevalúa el guard en cada
///   emisión (front-fase1.md §10, Concurrencia).
/// - No conoce roles ni decodifica el JWT.
/// - No toca el Outbox en ninguna transición (H2 sigue abierto).
class SessionController extends ValueNotifier<SessionState> {
  final TokenStore _tokenStore;

  SessionController({required TokenStore tokenStore})
      : _tokenStore = tokenStore,
        super(const SessionState.unknown());

  /// UNKNOWN → RESTORING → AUTHENTICATED | LOGGED_OUT.
  ///
  /// Con token presente se pasa a AUTHENTICATED; su validez la decide el
  /// backend en la primera petición (un 401 con JWT dispara T-1).
  /// Si la lectura del almacén falla, se sale a LOGGED_OUT: RESTORING nunca
  /// queda sin salida.
  Future<void> restore() async {
    if (value.status != SessionStatus.unknown) {
      throw InvalidSessionTransitionException(value.status, 'restore');
    }
    value = const SessionState.restoring();

    String? token;
    try {
      token = await _tokenStore.readToken();
    } catch (_) {
      token = null;
    }

    value = (token != null && token.isNotEmpty)
        ? const SessionState.authenticated()
        : const SessionState.loggedOut();
  }

  /// LOGGED_OUT → AUTHENTICATED tras un login correcto.
  Future<void> establish(String token) async {
    if (value.status != SessionStatus.loggedOut) {
      throw InvalidSessionTransitionException(value.status, 'establish');
    }
    if (token.isEmpty) {
      throw const InvalidSessionTransitionException(
          SessionStatus.loggedOut, 'establish con token vacío');
    }
    await _tokenStore.writeToken(token);
    value = const SessionState.authenticated();
  }

  /// AUTHENTICATED → LOGGED_OUT por logout manual. Limpia el token.
  /// No decide nada sobre el Outbox (H2).
  Future<void> logout() async {
    await _tokenStore.clearToken();
    value = const SessionState.loggedOut();
  }

  /// AUTHENTICATED → LOGGED_OUT por T-1. El [AuthResponseHandler] ya limpió
  /// el token; aquí solo se emite la transición.
  void markLoggedOutByUnauthorized() {
    value = const SessionState.loggedOut();
  }
}
