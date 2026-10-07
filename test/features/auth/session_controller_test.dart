import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/core/errors/app_exceptions.dart';
import 'package:paxfide_mobile/core/network/api_response.dart';
import 'package:paxfide_mobile/core/network/auth_response_handler.dart';
import 'package:paxfide_mobile/core/storage/token_store.dart';
import 'package:paxfide_mobile/features/auth/data/auth_api.dart';
import 'package:paxfide_mobile/features/auth/domain/principal.dart';
import 'package:paxfide_mobile/features/auth/domain/session_controller.dart';
import 'package:paxfide_mobile/features/auth/domain/session_state.dart';

import '../../support/fakes.dart';

const me = ApiResponse(
  statusCode: 200,
  data: {'accountId': 'acc-1', 'organizationId': 'org-1', 'roles': ['EMPLOYEE']},
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
    session = SessionController(tokenStore: tokens, authApi: AuthApi(api));
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
    // D3: nada más se persiste (ni rol, ni principal, ni organización).
    expect(secure.values.keys, ['paxfide.session.jwt']);
    expect(secure.values.values.join(), isNot(contains('EMPLOYEE')));
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
}
