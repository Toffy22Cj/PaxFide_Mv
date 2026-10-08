import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/core/errors/app_exceptions.dart';
import 'package:paxfide_mobile/core/network/auth_response_handler.dart';
import 'package:paxfide_mobile/core/network/credential_mode.dart';
import 'package:paxfide_mobile/core/network/http_api_client.dart';

import '../support/fakes.dart';

/// Servidor HTTP local real (dart:io) para probar el transporte sin red externa.
class _Server {
  late HttpServer server;
  final requests = <({String method, String path, Map<String, String> headers, String body})>[];
  FutureOr<void> Function(HttpRequest r)? handler;

  Future<void> start() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((r) async {
      final body = await utf8.decoder.bind(r).join();
      final headers = <String, String>{};
      r.headers.forEach((k, v) => headers[k] = v.join(','));
      requests.add((method: r.method, path: r.uri.path, headers: headers, body: body));
      if (handler != null) {
        await handler!(r);
      } else {
        r.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write('{"ok":true}');
        await r.response.close();
      }
    });
  }

  Uri get base => Uri.parse('http://127.0.0.1:${server.port}/api/v1');
}

void main() {
  late _Server srv;
  late FakeTokenStore tokens;
  late int loggedOut;
  late HttpApiClient client;

  setUp(() async {
    srv = _Server();
    await srv.start();
    tokens = FakeTokenStore();
    loggedOut = 0;
    client = HttpApiClient(
      baseUrl: srv.base,
      tokenStore: tokens,
      authResponseHandler: AuthResponseHandler(tokenStore: tokens, onSessionLoggedOut: () => loggedOut++),
      responseTimeout: const Duration(milliseconds: 600),
    );
  });

  tearDown(() => srv.server.close(force: true));

  test('jwt: pone el JWT del TokenStore y une la base con la ruta', () async {
    await tokens.writeToken('el-jwt');
    final r = await client.get('/me', credentialMode: CredentialMode.jwt);
    expect(r.statusCode, 200);
    expect(r.data, {'ok': true});
    expect(srv.requests.single.path, '/api/v1/me');
    expect(srv.requests.single.headers['authorization'], 'Bearer el-jwt');
  });

  test('none: nunca envía Authorization aunque haya JWT', () async {
    await tokens.writeToken('el-jwt');
    await client.post('/auth/login', body: {'email': 'a', 'password': 'b'}, credentialMode: CredentialMode.none);
    expect(srv.requests.single.headers.containsKey('authorization'), isFalse);
    expect(jsonDecode(srv.requests.single.body), {'email': 'a', 'password': 'b'});
  });

  test('tracking: usa la cabecera de la feature y nunca el JWT', () async {
    await tokens.writeToken('el-jwt');
    await client.get(
      '/donations/tracking',
      headers: {'Authorization': 'Bearer codigo'},
      credentialMode: CredentialMode.tracking,
    );
    expect(srv.requests.single.headers['authorization'], 'Bearer codigo');
  });

  test('credenciales no intercambiables: Authorization manual con jwt/none, o tracking sin ella → error', () async {
    expect(
      () => client.get('/x', headers: {'Authorization': 'Bearer y'}, credentialMode: CredentialMode.jwt),
      throwsArgumentError,
    );
    expect(() => client.get('/x', credentialMode: CredentialMode.tracking), throwsArgumentError);
    expect(srv.requests, isEmpty);
  });

  test('T-1: 401 con JWT limpia el token y cierra la sesión', () async {
    await tokens.writeToken('el-jwt');
    srv.handler = (r) async {
      r.response.statusCode = 401;
      await r.response.close();
    };
    final r = await client.get('/me', credentialMode: CredentialMode.jwt);
    expect(r.statusCode, 401);
    expect(await tokens.readToken(), isNull);
    expect(loggedOut, 1);
  });

  test('negativa: 401 de seguimiento no toca la sesión', () async {
    await tokens.writeToken('el-jwt');
    srv.handler = (r) async {
      r.response.statusCode = 401;
      await r.response.close();
    };
    await client.get(
      '/donations/tracking',
      headers: {'Authorization': 'Bearer c'},
      credentialMode: CredentialMode.tracking,
    );
    expect(await tokens.readToken(), 'el-jwt');
    expect(loggedOut, 0);
  });

  test('sin JWT guardado: la petición no sale y equivale a 401 (T-1)', () async {
    final r = await client.get('/me', credentialMode: CredentialMode.jwt);
    expect(r.statusCode, 401);
    expect(srv.requests, isEmpty);
    expect(loggedOut, 1);
  });

  test('no se pudo conectar → determinista, y beforeSend NO se invoca', () async {
    final port = srv.server.port;
    await srv.server.close(force: true);
    final c = HttpApiClient(
      baseUrl: Uri.parse('http://127.0.0.1:$port/api/v1'),
      tokenStore: tokens,
      authResponseHandler: AuthResponseHandler(tokenStore: tokens, onSessionLoggedOut: () {}),
    );
    var called = false;
    await expectLater(
      c.post('/x', body: const {}, credentialMode: CredentialMode.none, beforeSend: () async => called = true),
      throwsA(isA<ConnectionNotEstablishedException>().having((e) => e.isAmbiguous, 'ambigua', false)),
    );
    expect(called, isFalse);
  });

  test('timeout tras enviar → ambiguo (nunca determinista), y beforeSend se invocó', () async {
    srv.handler = (r) => Future<void>.delayed(const Duration(seconds: 2), () => r.response.close());
    var called = false;
    await expectLater(
      client.post('/x', body: const {}, credentialMode: CredentialMode.none, beforeSend: () async => called = true),
      throwsA(isA<NetworkTimeoutException>().having((e) => e.isAmbiguous, 'ambigua', true)),
    );
    expect(called, isTrue);
  });

  test('conexión cortada tras enviar → ambiguo', () async {
    srv.handler = (r) async {
      final socket = await r.response.detachSocket(writeHeaders: false);
      socket.destroy();
    };
    await expectLater(
      client.post('/x', body: const {}, credentialMode: CredentialMode.none),
      throwsA(isA<TransportException>().having((e) => e.isAmbiguous, 'ambigua', true)),
    );
  });

  test('los mensajes de error no contienen la URL ni el token', () async {
    await tokens.writeToken('jwt-secreto');
    srv.handler = (r) => Future<void>.delayed(const Duration(seconds: 2), () => r.response.close());
    try {
      await client.get('/assets/A-1', credentialMode: CredentialMode.jwt);
      fail('debía lanzar');
    } on AppException catch (e) {
      expect(e.toString(), isNot(contains('jwt-secreto')));
      expect(e.toString(), isNot(contains('127.0.0.1')));
    }
  });
}
