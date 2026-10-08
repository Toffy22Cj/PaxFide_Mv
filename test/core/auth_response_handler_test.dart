import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/core/network/auth_response_handler.dart';
import 'package:paxfide_mobile/core/network/credential_mode.dart';

import '../support/fakes.dart';

void main() {
  late InMemoryTokenStore store;
  late int loggedOut;
  late AuthResponseHandler handler;

  setUp(() async {
    store = InMemoryTokenStore();
    await store.writeToken('jwt');
    loggedOut = 0;
    handler = AuthResponseHandler(tokenStore: store, onSessionLoggedOut: () => loggedOut++);
  });

  test('T-1: 401 con JWT limpia el TokenStore y cierra la sesión', () async {
    await handler.handleResponse(statusCode: 401, credentialMode: CredentialMode.jwt);
    expect(await store.readToken(), isNull);
    expect(loggedOut, 1);
  });

  test('negativa: el 401 de seguimiento nunca modifica la sesión', () async {
    await handler.handleResponse(statusCode: 401, credentialMode: CredentialMode.tracking);
    expect(await store.readToken(), 'jwt');
    expect(loggedOut, 0);
  });

  test('negativa: 401 sin credencial, 403 y 404 no tocan la sesión', () async {
    await handler.handleResponse(statusCode: 401, credentialMode: CredentialMode.none);
    await handler.handleResponse(statusCode: 403, credentialMode: CredentialMode.jwt);
    await handler.handleResponse(statusCode: 404, credentialMode: CredentialMode.jwt);
    expect(await store.readToken(), 'jwt');
    expect(loggedOut, 0);
  });
}
