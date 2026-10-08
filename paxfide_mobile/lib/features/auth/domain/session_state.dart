import 'package:flutter/foundation.dart';

/// Estados de sesión formalizados en ADR-043 D3 y front-fase1.md §3.
enum SessionStatus {
  unknown,
  restoring,
  authenticated,
  loggedOut,
}

enum UserRole {
  donor,
  organization;

  static UserRole fromString(String? role) {
    if (role == null) return UserRole.donor;
    final normalized = role.trim().toLowerCase();
    if (normalized == 'organization' || normalized == 'org' || normalized == 'ong') {
      return UserRole.organization;
    }
    return UserRole.donor;
  }
}

class SessionState {
  final SessionStatus status;
  final UserRole? role;
  final String? userId;
  final String? email;

  const SessionState._(this.status, {this.role, this.userId, this.email});

  const SessionState.unknown() : this._(SessionStatus.unknown);
  const SessionState.restoring() : this._(SessionStatus.restoring);

  const SessionState.authenticated({
    UserRole role = UserRole.organization,
    String? userId,
    String? email,
  }) : this._(
          SessionStatus.authenticated,
          role: role,
          userId: userId,
          email: email,
        );

  const SessionState.loggedOut() : this._(SessionStatus.loggedOut);

  bool get isAuthenticated => status == SessionStatus.authenticated;
  bool get isOrganization => role == UserRole.organization;
  bool get isDonor => role == UserRole.donor;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          role == other.role &&
          userId == other.userId &&
          email == other.email;

  @override
  int get hashCode => Object.hash(status, role, userId, email);
}

class SessionManager {
  SessionManager._();
  static final SessionManager instance = SessionManager._();

  SessionState _current = const SessionState.loggedOut();
  SessionState get current => _current;
  UserRole get currentRole => _current.role ?? UserRole.donor;

  void setSession(SessionState state) {
    _current = state;
  }

  void authenticate({
    UserRole role = UserRole.organization,
    String? userId,
    String? email,
  }) {
    _current = SessionState.authenticated(
      role: role,
      userId: userId,
      email: email,
    );
  }

  void logOut() {
    _current = const SessionState.loggedOut();
  }
}