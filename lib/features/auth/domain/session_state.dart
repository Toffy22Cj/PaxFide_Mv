/// Estados de sesión formalizados en ADR-043 D3 y front-fase1.md §3.
/// Deliberadamente sin REFRESHING ni TOKEN_EXPIRED.
enum SessionStatus { unknown, restoring, authenticated, loggedOut }

class SessionState {
  final SessionStatus status;

  const SessionState._(this.status);

  const SessionState.unknown() : this._(SessionStatus.unknown);
  const SessionState.restoring() : this._(SessionStatus.restoring);
  const SessionState.authenticated() : this._(SessionStatus.authenticated);
  const SessionState.loggedOut() : this._(SessionStatus.loggedOut);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is SessionState && runtimeType == other.runtimeType && status == other.status;

  @override
  int get hashCode => status.hashCode;
}
