import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/core/network/auth_response_handler.dart';
import 'package:paxfide_mobile/core/network/credential_mode.dart';
import 'package:paxfide_mobile/features/auth/data/login_gateway.dart';
import 'package:paxfide_mobile/features/auth/data/me_gateway.dart';
import 'package:paxfide_mobile/features/auth/domain/principal.dart';
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

  group('Principal desde /me — ADR-043 §0', () {
    test('restore con token: el principal sale de /me', () async {
      final s = SessionController(
        tokenStore: FakeTokenStore(token: 't'),
        meGateway: FakeMeGateway.principal(fieldOperator),
      );
      await s.restore();
      expect(s.value, const SessionState.authenticated(principal: fieldOperator));
    });

    test('restore: /me consultado durante RESTORING (el guard sigue esperando)', () async {
      final me = FakeMeGateway.principal(donor);
      final s = SessionController(tokenStore: FakeTokenStore(token: 't'), meGateway: me);
      final seen = <SessionStatus>[];
      s.addListener(() => seen.add(s.value.status));
      await s.restore();
      expect(seen, [SessionStatus.restoring, SessionStatus.authenticated]);
      expect(me.calls, 1);
    });

    test('restore con /me 401 → T-1: limpia el token y sale a LOGGED_OUT', () async {
      final store = FakeTokenStore(token: 't');
      final s = SessionController(
        tokenStore: store,
        meGateway: FakeMeGateway(const MeUnauthorized()),
      );
      await s.restore();
      expect(s.value, const SessionState.loggedOut());
      expect(store.token, isNull);
    });

    test('NEGATIVA: /me sin respuesta → AUTHENTICATED sin principal, nunca un rol por defecto', () async {
      for (final result in const [MeNetworkError(), MeUnavailable()]) {
        final s = SessionController(
          tokenStore: FakeTokenStore(token: 't'),
          meGateway: FakeMeGateway(result),
        );
        await s.restore();
        expect(s.value.status, SessionStatus.authenticated);
        expect(s.value.principal, isNull);
      }
    });

    test('establish: guarda el token y carga el principal', () async {
      final store = FakeTokenStore();
      final s = SessionController(
        tokenStore: store,
        meGateway: FakeMeGateway.principal(administrator),
      );
      await s.restore();
      final r = await s.establish('jwt');
      expect(r, EstablishResult.authenticated);
      expect(s.value.principal, administrator);
      expect(store.token, 'jwt');
    });

    test('establish con /me 401 → rejected, sin token y LOGGED_OUT', () async {
      final store = FakeTokenStore();
      final s = SessionController(
        tokenStore: store,
        meGateway: FakeMeGateway(const MeUnauthorized()),
      );
      await s.restore();
      final r = await s.establish('jwt');
      expect(r, EstablishResult.rejected);
      expect(s.value, const SessionState.loggedOut());
      expect(store.token, isNull);
    });

    test('reloadPrincipal: AUTHENTICATED sin principal → con principal', () async {
      final me = FakeMeGateway(const MeNetworkError());
      final s = SessionController(tokenStore: FakeTokenStore(token: 't'), meGateway: me);
      await s.restore();
      expect(s.value.principal, isNull);
      me.result = const MeSucceeded(donor);
      await s.reloadPrincipal();
      expect(s.value.principal, donor);
    });

    test('NEGATIVA: el gateway de /me por defecto no inventa roles', () async {
      expect(await defaultMeGateway().fetch('t'), isA<MeUnavailable>());
    });

    test('Principal.fromJson: roles conocidos, desconocidos ignorados', () {
      final p = Principal.fromJson({
        'accountId': 'a',
        'organizationId': 'o',
        'roles': ['EMPLOYEE', 'ADMINISTRATOR', 'OTRO'],
      });
      expect(p.roles, {OrgRole.employee, OrgRole.administrator});
      expect(p.isDonor, isFalse);
      expect(p.isFieldOperator, isTrue);
      expect(p.canSeePrediction, isTrue);
    });

    test('Principal.fromJson: sin organización es donante', () {
      final p = Principal.fromJson({'accountId': 'a', 'roles': <String>[]});
      expect(p.isDonor, isTrue);
      expect(p.isFieldOperator, isFalse);
      expect(p.canSeePrediction, isFalse);
    });

    test('NEGATIVA: Principal.fromJson sin accountId lanza FormatException', () {
      expect(() => Principal.fromJson({'roles': <String>[]}), throwsFormatException);
    });
  });
}
