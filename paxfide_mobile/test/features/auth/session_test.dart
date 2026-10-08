import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/core/network/auth_response_handler.dart';
import 'package:paxfide_mobile/core/network/credential_mode.dart';
import 'package:paxfide_mobile/features/auth/data/login_gateway.dart';
import 'package:paxfide_mobile/features/auth/data/session_controller.dart';
import 'package:paxfide_mobile/features/auth/domain/session_state.dart';

import '../../support/fakes.dart';

void main() {
  group('SessionController — máquina de ADR-043 D3', () {
    test('arranca en UNKNOWN', () {
      final s = SessionController(tokenStore: FakeTokenStore());
      expect(s.value, const SessionState.unknown());
    });

    test('restore sin token: UNKNOWN → RESTORING → LOGGED_OUT', () async {
      final s = SessionController(tokenStore: FakeTokenStore());
      final seen = <SessionStatus>[];
      s.addListener(() => seen.add(s.value.status));
      await s.restore();
      expect(seen, [SessionStatus.restoring, SessionStatus.loggedOut]);
    });

    test('restore con token: → AUTHENTICATED', () async {
      final s = SessionController(tokenStore: FakeTokenStore(token: 't'));
      await s.restore();
      expect(s.value.status, SessionStatus.authenticated);
    });

    test('restore con fallo del almacén → LOGGED_OUT (RESTORING nunca queda sin salida)', () async {
      final store = FakeTokenStore()..throwOnRead = true;
      final s = SessionController(tokenStore: store);
      await s.restore();
      expect(s.value.status, SessionStatus.loggedOut);
    });

    test('NEGATIVA: restore dos veces lanza excepción nombrada', () async {
      final s = SessionController(tokenStore: FakeTokenStore());
      await s.restore();
      await expectLater(s.restore(), throwsA(isA<InvalidSessionTransitionException>()));
    });

    test('establish: LOGGED_OUT → AUTHENTICATED y guarda el token', () async {
      final store = FakeTokenStore();
      final s = SessionController(tokenStore: store);
      await s.restore();
      await s.establish('jwt-opaco');
      expect(s.value.status, SessionStatus.authenticated);
      expect(store.token, 'jwt-opaco');
    });

    test('NEGATIVA: establish fuera de LOGGED_OUT no escribe token', () async {
      final store = FakeTokenStore();
      final s = SessionController(tokenStore: store);
      await expectLater(s.establish('t'), throwsA(isA<InvalidSessionTransitionException>()));
      expect(store.writes, 0);
    });

    test('logout: → LOGGED_OUT y limpia el token', () async {
      final store = FakeTokenStore(token: 't');
      final s = SessionController(tokenStore: store);
      await s.restore();
      await s.logout();
      expect(s.value.status, SessionStatus.loggedOut);
      expect(store.token, isNull);
      expect(store.clears, 1);
    });
  });

  group('AuthResponseHandler — T-1', () {
    late FakeTokenStore store;
    late int loggedOutCalls;
    late AuthResponseHandler handler;

    setUp(() {
      store = FakeTokenStore(token: 't');
      loggedOutCalls = 0;
      handler = AuthResponseHandler(
        tokenStore: store,
        onSessionLoggedOut: () => loggedOutCalls++,
      );
    });

    test('401 con JWT → limpia token y notifica LOGGED_OUT', () async {
      await handler.handleResponse(statusCode: 401, credentialMode: CredentialMode.jwt);
      expect(store.token, isNull);
      expect(loggedOutCalls, 1);
    });

    test('NEGATIVA: 401 de tracking no limpia token ni cambia la sesión', () async {
      await handler.handleResponse(statusCode: 401, credentialMode: CredentialMode.tracking);
      expect(store.token, 't');
      expect(store.clears, 0);
      expect(loggedOutCalls, 0);
    });

    test('NEGATIVA: 401 sin credencial no limpia token ni cambia la sesión', () async {
      await handler.handleResponse(statusCode: 401, credentialMode: CredentialMode.none);
      expect(store.clears, 0);
      expect(loggedOutCalls, 0);
    });

    test('NEGATIVA: 403 con JWT no es T-1 (es estado de pantalla)', () async {
      await handler.handleResponse(statusCode: 403, credentialMode: CredentialMode.jwt);
      expect(store.clears, 0);
      expect(loggedOutCalls, 0);
    });

    test('T-1 conectado al SessionController: AUTHENTICATED → LOGGED_OUT', () async {
      final s = SessionController(tokenStore: store);
      await s.restore();
      expect(s.value.status, SessionStatus.authenticated);
      final h = AuthResponseHandler(
        tokenStore: store,
        onSessionLoggedOut: s.markLoggedOutByUnauthorized,
      );
      await h.handleResponse(statusCode: 401, credentialMode: CredentialMode.jwt);
      expect(s.value.status, SessionStatus.loggedOut);
    });
  });

  group('LoginGateway por defecto', () {
    test('sin --dart-define, el build usa el gateway no disponible', () async {
      expect(kFakeAuthEnabled, isFalse);
      final r = await defaultLoginGateway().login(email: 'a@b.co', password: 'x');
      expect(r, isA<LoginUnavailable>());
    });
  });
}
