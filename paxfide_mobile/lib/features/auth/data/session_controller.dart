import 'package:flutter/foundation.dart';

import '../../../core/storage/token_store.dart';
import '../domain/session_state.dart';
import 'me_gateway.dart';

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

/// Resultado de [SessionController.establish].
enum EstablishResult {
  /// La sesión quedó AUTHENTICATED (con o sin principal).
  authenticated,

  /// `/me` respondió 401 al token recién emitido: se limpió y la sesión
  /// sigue LOGGED_OUT.
  rejected,
}

/// Dueño único de la máquina de sesión (ADR-043 D3).
///
/// - Emite cada cambio de [SessionState]; el router reevalúa el guard en cada
///   emisión (front-fase1.md §10, Concurrencia).
/// - El rol sale solo de [MeGateway] (`GET /me`) y vive en memoria dentro del
///   estado; no se persiste ni se lee del JWT (ADR-043 §0).
/// - No toca el Outbox en ninguna transición: las entradas se conservan tras
///   un logout (ADR-043 §0, A1).
class SessionController extends ValueNotifier<SessionState> {
  final TokenStore _tokenStore;
  final MeGateway _meGateway;

  SessionController({
    required TokenStore tokenStore,
    MeGateway meGateway = const UnavailableMeGateway(),
  })  : _tokenStore = tokenStore,
        _meGateway = meGateway,
        super(const SessionState.unknown());

  /// UNKNOWN → RESTORING → AUTHENTICATED | LOGGED_OUT.
  ///
  /// Con token se consulta `/me` durante RESTORING (el guard sigue
  /// esperando). Un 401 aplica T-1 y sale a LOGGED_OUT; un fallo de red o la
  /// falta de contrato dejan AUTHENTICATED sin principal. Si la lectura del
  /// almacén falla, se sale a LOGGED_OUT: RESTORING nunca queda sin salida.
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

    if (token == null || token.isEmpty) {
      value = const SessionState.loggedOut();
      return;
    }
    await _authenticateWith(token);
  }

  /// LOGGED_OUT → AUTHENTICATED tras un login correcto.
  ///
  /// Guarda el token y consulta `/me`. Si `/me` responde 401, limpia el
  /// token, la sesión sigue LOGGED_OUT y devuelve [EstablishResult.rejected].
  Future<EstablishResult> establish(String token) async {
    if (value.status != SessionStatus.loggedOut) {
      throw InvalidSessionTransitionException(value.status, 'establish');
    }
    if (token.isEmpty) {
      throw const InvalidSessionTransitionException(
          SessionStatus.loggedOut, 'establish con token vacío');
    }
    await _tokenStore.writeToken(token);
    final authenticated = await _authenticateWith(token);
    return authenticated ? EstablishResult.authenticated : EstablishResult.rejected;
  }

  /// Vuelve a pedir `/me` estando AUTHENTICATED (p. ej. "Reintentar" cuando
  /// el perfil no cargó). Un 401 aplica T-1.
  Future<void> reloadPrincipal() async {
    if (value.status != SessionStatus.authenticated) {
      throw InvalidSessionTransitionException(value.status, 'reloadPrincipal');
    }
    String? token;
    try {
      token = await _tokenStore.readToken();
    } catch (_) {
      token = null;
    }
    if (token == null || token.isEmpty) {
      value = const SessionState.loggedOut();
      return;
    }
    await _authenticateWith(token);
  }

  /// AUTHENTICATED → LOGGED_OUT por logout manual. Limpia el token.
  /// El Outbox no se toca (ADR-043 §0, A1).
  Future<void> logout() async {
    await _tokenStore.clearToken();
    value = const SessionState.loggedOut();
  }

  /// AUTHENTICATED → LOGGED_OUT por T-1. El [AuthResponseHandler] ya limpió
  /// el token; aquí solo se emite la transición.
  void markLoggedOutByUnauthorized() {
    value = const SessionState.loggedOut();
  }

  /// Consulta `/me` y fija el estado. Devuelve false si `/me` respondió 401.
  Future<bool> _authenticateWith(String token) async {
    MeResult result;
    try {
      result = await _meGateway.fetch(token);
    } catch (_) {
      result = const MeNetworkError();
    }

    switch (result) {
      case MeSucceeded(:final principal):
        value = SessionState.authenticated(principal: principal);
        return true;
      case MeUnauthorized():
        // T-1: el token no vale.
        await _tokenStore.clearToken();
        value = const SessionState.loggedOut();
        return false;
      case MeNetworkError():
      case MeUnavailable():
        value = const SessionState.authenticated();
        return true;
    }
  }
}
