import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/core/errors/app_exceptions.dart';
import 'package:paxfide_mobile/core/network/api_response.dart';
import 'package:paxfide_mobile/features/auth/data/auth_api.dart';
import 'package:paxfide_mobile/features/auth/domain/legal_versions.dart';

import '../../support/fakes.dart';

void main() {
  late FakeApiClient api;
  late AuthApi authApi;

  setUp(() {
    api = FakeApiClient();
    authApi = AuthApi(api);
  });

  test('1. register envía las dos versiones de las constantes', () async {
    api.enqueue(const ApiResponse(statusCode: 201, data: {'accountId': 'acc-1', 'status': 'ACTIVE'}));
    await authApi.register(
      'nuevo@demo',
      'password12345',
      acceptedTermsVersion: currentTermsVersion,
      acceptedDataPolicyVersion: currentDataPolicyVersion,
    );
    expect(api.calls, hasLength(1));
    final call = api.calls.first;
    expect(call.path, '/auth/register');
    expect(call.body, {
      'email': 'nuevo@demo',
      'password': 'password12345',
      'acceptedTermsVersion': 'v1-2026-10',
      'acceptedDataPolicyVersion': 'v1-2026-10',
    });
  });

  test('2. login sin versiones no envía esas claves', () async {
    api.enqueue(const ApiResponse(statusCode: 200, data: {'token': 'jwt-1'}));
    final token = await authApi.login('user@demo', 'password12345');
    expect(token, 'jwt-1');
    expect(api.calls, hasLength(1));
    final call = api.calls.first;
    expect(call.path, '/auth/login');
    expect(call.body, {'email': 'user@demo', 'password': 'password12345'});
    expect(call.body?.containsKey('acceptedTermsVersion'), isFalse);
    expect(call.body?.containsKey('acceptedDataPolicyVersion'), isFalse);
  });

  test('3. login con versiones las envía', () async {
    api.enqueue(const ApiResponse(statusCode: 200, data: {'token': 'jwt-1'}));
    final token = await authApi.login(
      'user@demo',
      'password12345',
      acceptedTermsVersion: 'v1-2026-10',
      acceptedDataPolicyVersion: 'v1-2026-10',
    );
    expect(token, 'jwt-1');
    expect(api.calls, hasLength(1));
    final call = api.calls.first;
    expect(call.path, '/auth/login');
    expect(call.body, {
      'email': 'user@demo',
      'password': 'password12345',
      'acceptedTermsVersion': 'v1-2026-10',
      'acceptedDataPolicyVersion': 'v1-2026-10',
    });
  });

  test('4. 403 AcceptanceRequired con las dos pendientes lanza la excepción con ambas', () async {
    api.enqueue(
      const ApiResponse(
        statusCode: 403,
        data: {
          'type': 'about:blank',
          'status': 403,
          'title': 'AcceptanceRequired',
          'detail': 'Debe aceptar los términos',
          'pendingTermsVersion': 'v1-2026-10',
          'pendingDataPolicyVersion': 'v1-2026-10',
        },
      ),
    );
    try {
      await authApi.login('user@demo', 'password12345');
      fail('Debería haber lanzado AcceptanceRequiredException');
    } on AcceptanceRequiredException catch (e) {
      expect(e.statusCode, 403);
      expect(e.pendingTermsVersion, 'v1-2026-10');
      expect(e.pendingDataPolicyVersion, 'v1-2026-10');
    }
  });

  test('5. con una sola pendiente, la otra queda null', () async {
    // Solo términos
    api.enqueue(
      const ApiResponse(statusCode: 403, data: {'title': 'AcceptanceRequired', 'pendingTermsVersion': 'v1-2026-10'}),
    );
    try {
      await authApi.login('user@demo', 'password12345');
      fail('Debería haber lanzado AcceptanceRequiredException');
    } on AcceptanceRequiredException catch (e) {
      expect(e.pendingTermsVersion, 'v1-2026-10');
      expect(e.pendingDataPolicyVersion, isNull);
    }

    // Solo política de datos
    api.enqueue(
      const ApiResponse(
        statusCode: 403,
        data: {'title': 'AcceptanceRequired', 'pendingDataPolicyVersion': 'v1-2026-10'},
      ),
    );
    try {
      await authApi.login('user@demo', 'password12345');
      fail('Debería haber lanzado AcceptanceRequiredException');
    } on AcceptanceRequiredException catch (e) {
      expect(e.pendingTermsVersion, isNull);
      expect(e.pendingDataPolicyVersion, 'v1-2026-10');
    }
  });

  test('6. 403 sin ese title sigue lanzando ForbiddenException', () async {
    api.enqueue(const ApiResponse(statusCode: 403, data: {'title': 'Forbidden'}));
    await expectLater(authApi.login('user@demo', 'password12345'), throwsA(isA<ForbiddenException>()));

    api.enqueue(const ApiResponse(statusCode: 403));
    await expectLater(authApi.login('user@demo', 'password12345'), throwsA(isA<ForbiddenException>()));
  });

  test('7. 403 AcceptanceRequired sin versiones lanza MalformedResponseException', () async {
    api.enqueue(const ApiResponse(statusCode: 403, data: {'title': 'AcceptanceRequired'}));
    await expectLater(authApi.login('user@demo', 'password12345'), throwsA(isA<MalformedResponseException>()));

    api.enqueue(
      const ApiResponse(
        statusCode: 403,
        data: {'title': 'AcceptanceRequired', 'pendingTermsVersion': '', 'pendingDataPolicyVersion': ''},
      ),
    );
    await expectLater(authApi.login('user@demo', 'password12345'), throwsA(isA<MalformedResponseException>()));
  });

  group('requestPasswordReset', () {
    test('envía {email} a /auth/password-reset y acepta 202 sin cuerpo', () async {
      api.enqueue(const ApiResponse(statusCode: 202));
      await authApi.requestPasswordReset('olvidado@demo.com');
      expect(api.calls, hasLength(1));
      final call = api.calls.first;
      expect(call.path, '/auth/password-reset');
      expect(call.body, {'email': 'olvidado@demo.com'});
    });

    test('400 lanza BadRequestException', () async {
      api.enqueue(const ApiResponse(statusCode: 400));
      await expectLater(authApi.requestPasswordReset(''), throwsA(isA<BadRequestException>()));
    });

    test('500 lanza ServerErrorException', () async {
      api.enqueue(const ApiResponse(statusCode: 500));
      await expectLater(authApi.requestPasswordReset('err@demo.com'), throwsA(isA<ServerErrorException>()));
    });
  });
}
