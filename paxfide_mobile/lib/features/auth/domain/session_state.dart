import 'principal.dart';

/// Estados de sesión formalizados en ADR-043 D3 y front-fase1.md §3.
enum SessionStatus {
  unknown,
  restoring,
  authenticated,
  loggedOut,
}

/// Estado de sesión. Solo AUTHENTICATED lleva [principal], y puede ser null
/// si `/me` no respondió: la UI muestra entonces "perfil no disponible" con
/// reintento, nunca un rol por defecto.
class SessionState {
  final SessionStatus status;
  final Principal? principal;

  const SessionState._(this.status, {this.principal});

  const SessionState.unknown() : this._(SessionStatus.unknown);
  const SessionState.restoring() : this._(SessionStatus.restoring);
  const SessionState.authenticated({Principal? principal})
      : this._(SessionStatus.authenticated, principal: principal);
  const SessionState.loggedOut() : this._(SessionStatus.loggedOut);

  bool get isAuthenticated => status == SessionStatus.authenticated;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionState && status == other.status && principal == other.principal;

  @override
  int get hashCode => Object.hash(status, principal);

  @override
  String toString() => 'SessionState($status)';
}
