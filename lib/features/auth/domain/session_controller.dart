import 'package:flutter/foundation.dart';

import '../../../core/errors/app_exceptions.dart';
import '../../../core/storage/token_store.dart';
import '../data/auth_api.dart';
import 'principal.dart';
import 'session_state.dart';

/// Estado del perfil (`/me`) dentro de una sesión `AUTHENTICATED`.
enum ProfileStatus { none, loading, loaded, unavailable }

/// Máquina de sesión (ADR-043 D3, front-fase1.md §3):
/// `UNKNOWN → RESTORING → AUTHENTICATED | LOGGED_OUT`; `AUTHENTICATED → LOGGED_OUT` por logout o T-1;
/// `LOGGED_OUT → AUTHENTICATED` por login.
///
/// El [principal] sale de `GET /me` y vive solo en memoria. Si `/me` no se puede leer por un fallo de red, la sesión
/// sigue `AUTHENTICATED` con el perfil `unavailable` y una salida explícita: [reloadProfile] (DDM-08).
/// Nunca toca el Outbox (H2: las entradas sobreviven al logout).
class SessionController extends ChangeNotifier {
  SessionController({required this.tokenStore, required this.authApi});

  final TokenStore tokenStore;
  final AuthApi authApi;

  SessionState _state = const SessionState.unknown();
  Principal? _principal;
  ProfileStatus _profile = ProfileStatus.none;

  SessionState get state => _state;
  Principal? get principal => _principal;
  ProfileStatus get profileStatus => _profile;

  void _set(SessionState s, {Principal? principal, ProfileStatus profile = ProfileStatus.none}) {
    _state = s;
    _principal = principal;
    _profile = profile;
    notifyListeners();
  }

  /// Arranque: `UNKNOWN → RESTORING → AUTHENTICATED | LOGGED_OUT`.
  Future<void> restore() async {
    if (_state.status != SessionStatus.unknown) return;
    _set(const SessionState.restoring());
    final token = await tokenStore.readToken();
    if (token == null || token.isEmpty) {
      _set(const SessionState.loggedOut());
      return;
    }
    await _loadProfileAfterToken();
  }

  /// `LOGGED_OUT → AUTHENTICATED`. Errores: [UnauthorizedException] (credenciales), [TransportException],
  /// [ApiHttpException]. Sin efectos duplicables: reintentar es seguro (§13).
  Future<void> login(String email, String password) async {
    final token = await authApi.login(email, password);
    await tokenStore.writeToken(token);
    await _loadProfileAfterToken();
    if (_state.status != SessionStatus.authenticated) throw const UnauthorizedException();
  }

  Future<void> _loadProfileAfterToken() async {
    try {
      final me = await authApi.me();
      _set(const SessionState.authenticated(), principal: Principal.fromMe(me), profile: ProfileStatus.loaded);
    } on UnauthorizedException {
      // T-1 ya limpió el token (AuthResponseHandler) y llamó a onUnauthorized.
      if (_state.status != SessionStatus.loggedOut) _set(const SessionState.loggedOut());
    } on AppException {
      _set(const SessionState.authenticated(), profile: ProfileStatus.unavailable);
    }
  }

  /// Salida de `ProfileStatus.unavailable`.
  Future<void> reloadProfile() async {
    if (_state.status != SessionStatus.authenticated) return;
    _set(const SessionState.authenticated(), principal: _principal, profile: ProfileStatus.loading);
    await _loadProfileAfterToken();
  }

  /// Logout manual. No decide nada sobre el Outbox (invariante 4 de §10; H2).
  Future<void> logout() async {
    await tokenStore.clearToken();
    _set(const SessionState.loggedOut());
  }

  /// T-1: lo invoca [AuthResponseHandler] tras limpiar el token.
  void onUnauthorized() {
    if (_state.status == SessionStatus.loggedOut) return;
    _set(const SessionState.loggedOut());
  }
}
