import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/core/errors/app_exceptions.dart';
import 'package:paxfide_mobile/core/network/api_response.dart';
import 'package:paxfide_mobile/core/network/auth_response_handler.dart';
import 'package:paxfide_mobile/features/auth/data/profile_store.dart';
import 'package:paxfide_mobile/core/storage/token_store.dart';
import 'package:paxfide_mobile/features/auth/data/auth_api.dart';
import 'package:paxfide_mobile/features/auth/domain/principal.dart';
import 'package:paxfide_mobile/features/auth/domain/session_controller.dart';
import 'package:paxfide_mobile/features/auth/domain/session_state.dart';

import '../../support/fakes.dart';

const me = ApiResponse(
  statusCode: 200,
  data: {
    'accountId': 'acc-1',
    'organizationId': 'org-1',
    'roles': ['EMPLOYEE'],
  },
);

void main() {
  late InMemorySecureKeyValueStore secure;
  late SecureTokenStore tokens;
  late FakeApiClient api;
  late SessionController session;
  late List<SessionStatus> seen;

  setUp(() {
    secure = InMemorySecureKeyValueStore();
    tokens = SecureTokenStore(secure);
    api = FakeApiClient();
    session = SessionController(tokenStore: tokens, authApi: AuthApi(api), profileStore: SecureProfileStore(secure));
    api.authHandler = AuthResponseHandler(tokenStore: tokens, onSessionLoggedOut: session.onUnauthorized);
    seen = [];
    session.addListener(() => seen.add(session.state.status));
  });

  test('restaurar sin token: UNKNOWN → RESTORING → LOGGED_OUT, sin pedir /me', () async {
    await session.restore();
    expect(seen, [SessionStatus.restoring, SessionStatus.loggedOut]);
    expect(api.calls, isEmpty);
  });

  test('restaurar con token: /me → AUTHENTICATED con el principal en memoria', () async {
    await tokens.writeToken('jwt');
    api.enqueue(me);
    await session.restore();
    expect(seen, [SessionStatus.restoring, SessionStatus.authenticated]);
    expect(session.principal?.accountId, 'acc-1');
    expect(session.principal?.showsOperatorActions, isTrue);
    expect(session.principal?.showsPrediction, isFalse);
  });

  test('restaurar con token caducado: 401 en /me → T-1 → LOGGED_OUT y token borrado', () async {
    await tokens.writeToken('jwt');
    api.enqueue(const ApiResponse(statusCode: 401));
    await session.restore();
    expect(session.state.status, SessionStatus.loggedOut);
    expect(await tokens.readToken(), isNull);
  });

  test('restaurar sin red: AUTHENTICATED con perfil no disponible y salida "Reintentar"', () async {
    await tokens.writeToken('jwt');
    api.enqueue(const ConnectionNotEstablishedException());
    await session.restore();
    expect(session.state.status, SessionStatus.authenticated);
    expect(session.profileStatus, ProfileStatus.unavailable);
    expect(session.principal, isNull);
    api.enqueue(me);
    await session.reloadProfile();
    expect(session.profileStatus, ProfileStatus.loaded);
    expect(session.principal?.accountId, 'acc-1');
  });

  test('login: guarda el JWT solo en el TokenStore y lee el rol de /me', () async {
    api.enqueue(const ApiResponse(statusCode: 200, data: {'token': 'jwt-nuevo'}));
    api.enqueue(me);
    session.onUnauthorized(); // estado LOGGED_OUT de partida
    await session.login('a@b.c', 'pw');
    expect(session.state.status, SessionStatus.authenticated);
    expect(await tokens.readToken(), 'jwt-nuevo');
    // D3, cambiado por la Enmienda 4 (S1): además del JWT, solo el perfil de la sesión recordada, cifrado, para entrar
    // sin conexión. Nada más.
    expect(secure.values.keys, unorderedEquals(['paxfide.session.jwt', 'paxfide.session.profile']));
    // El rol solo está en el perfil guardado (cifrado), nunca suelto en otra clave.
    expect(secure.values['paxfide.session.jwt'], isNot(contains('EMPLOYEE')));
  });

  test('login con credenciales erróneas: lanza y no guarda nada', () async {
    api.enqueue(const ApiResponse(statusCode: 401));
    await expectLater(session.login('a@b.c', 'mal'), throwsA(isA<UnauthorizedException>()));
    expect(await tokens.readToken(), isNull);
    expect(session.state.status, isNot(SessionStatus.authenticated));
  });

  test('logout: borra el token y el principal', () async {
    await tokens.writeToken('jwt');
    api.enqueue(me);
    await session.restore();
    await session.logout();
    expect(session.state.status, SessionStatus.loggedOut);
    expect(session.principal, isNull);
    expect(await tokens.readToken(), isNull);
  });

  test('principal: predicción solo para ADMINISTRATOR/REPRESENTATIVE con organización', () {
    MeDto dto(List<String> roles, {String? org = 'o'}) => MeDto(accountId: 'a', organizationId: org, roles: roles);
    expect(MeDto.fromJson({'accountId': 'a', 'roles': <String>[]}).roles, isEmpty);
    expect(() => MeDto.fromJson({'roles': <String>[]}), throwsA(isA<MalformedResponseException>()));
    for (final r in ['ADMINISTRATOR', 'REPRESENTATIVE']) {
      expect(Principal.fromMe(dto([r])).showsPrediction, isTrue);
      expect(Principal.fromMe(dto([r], org: null)).showsPrediction, isFalse);
    }
    expect(Principal.fromMe(dto(['EMPLOYEE'])).showsPrediction, isFalse);
    expect(Principal.fromMe(dto(['ADMINISTRATOR'])).showsOperatorActions, isFalse);
  });

  group('Enmienda 4, S1: entrar sin conexión con la sesión recordada', () {
    test('con red, el perfil de una sesión recordada se guarda cifrado', () async {
      await tokens.writeToken('jwt');
      api.enqueue(me);
      await session.restore();
      expect(secure.values[SecureProfileStore.key], contains('acc-1'));
      expect(session.profileStatus, ProfileStatus.loaded);
    });

    test('sin red y con el perfil guardado: AUTHENTICATED con el perfil guardado, marcado como sin conexión', () async {
      await tokens.writeToken('jwt');
      await SecureProfileStore(secure).write(
        const MeDto(accountId: 'acc-1', organizationId: 'org-1', roles: ['EMPLOYEE']),
      );
      api.enqueue(const ConnectionNotEstablishedException());
      await session.restore();
      expect(session.state.status, SessionStatus.authenticated);
      expect(session.principal?.accountId, 'acc-1');
      expect(session.principal?.showsOperatorActions, isTrue);
      expect(session.profileStatus, ProfileStatus.offline);

      // Al volver la red, se refresca
      api.enqueue(me);
      await session.reloadProfile();
      expect(session.profileStatus, ProfileStatus.loaded);
    });

    test('sin red y sin perfil guardado: como antes, perfil no disponible', () async {
      await tokens.writeToken('jwt');
      api.enqueue(const ConnectionNotEstablishedException());
      await session.restore();
      expect(session.state.status, SessionStatus.authenticated);
      expect(session.principal, isNull);
      expect(session.profileStatus, ProfileStatus.unavailable);
    });

    test('cerrar sesión, o un 401, borran el perfil guardado', () async {
      await tokens.writeToken('jwt');
      api.enqueue(me);
      await session.restore();
      await session.logout();
      expect(secure.values[SecureProfileStore.key], isNull);

      await tokens.writeToken('jwt');
      await SecureProfileStore(secure).write(const MeDto(accountId: 'acc-1', roles: []));
      session.onUnauthorized();
      await Future<void>.delayed(Duration.zero);
      expect(secure.values[SecureProfileStore.key], isNull);
    });

    test('una sesión no recordada no guarda el perfil', () async {
      api.enqueue(me);
      await session.loginWithToken('jwt', remember: false);
      expect(secure.values[SecureProfileStore.key], isNull);
    });
  });
}
