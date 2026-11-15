import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/core/errors/app_exceptions.dart';
import 'package:paxfide_mobile/core/network/api_response.dart';
import 'package:paxfide_mobile/core/network/credential_mode.dart';
import 'package:paxfide_mobile/features/account/data/account_api.dart';

import '../../support/fakes.dart';

ApiResponse _problem(int status, String title) =>
    ApiResponse(statusCode: status, data: {'type': 'about:blank', 'title': title, 'status': status});

void main() {
  late FakeApiClient api;
  late AccountApi account;

  setUp(() {
    api = FakeApiClient();
    account = AccountApi(api);
  });

  test('profile lee correo y nombre; las partes vacías o ausentes quedan en null', () async {
    api.enqueue(const ApiResponse(statusCode: 200, data: {'email': 'a@demo', 'givenName': 'Ana', 'familyName': ''}));
    final p = await account.profile();
    expect(api.calls.single.credentialMode, CredentialMode.jwt);
    expect(p.email, 'a@demo');
    expect(p.givenName, 'Ana');
    expect(p.familyName, isNull);
    expect(p.fullName, 'Ana');
  });

  test('profile sin correo es una respuesta inesperada', () async {
    api.enqueue(const ApiResponse(statusCode: 200, data: {'givenName': 'Ana'}));
    expect(account.profile(), throwsA(isA<MalformedResponseException>()));
  });

  test('updateProfile recorta y manda null para borrar', () async {
    api.enqueue(const ApiResponse(statusCode: 200, data: {'email': 'a@demo', 'givenName': 'Ana'}));
    await account.updateProfile(givenName: '  Ana  ', familyName: '   ');
    final call = api.calls.single;
    expect(call.method, 'PUT');
    expect(call.path, '/account/profile');
    expect(call.body, {'givenName': 'Ana', 'familyName': null});
  });

  test('changePassword devuelve el token nuevo', () async {
    api.enqueue(const ApiResponse(statusCode: 200, data: {'token': 'jwt-2'}));
    expect(await account.changePassword(currentPassword: 'actual-12345', newPassword: 'nueva-1234567'), 'jwt-2');
    expect(api.calls.single.body, {'currentPassword': 'actual-12345', 'newPassword': 'nueva-1234567'});
  });

  test('changePassword: los 400 con nombre se distinguen', () async {
    api.enqueue(_problem(400, 'CurrentPasswordIncorrect'));
    await expectLater(
      account.changePassword(currentPassword: 'x', newPassword: 'nueva-1234567'),
      throwsA(isA<CurrentPasswordIncorrectException>()),
    );
    api.enqueue(_problem(400, 'PasswordTooShort'));
    await expectLater(
      account.changePassword(currentPassword: 'x', newPassword: 'corta'),
      throwsA(isA<NewPasswordTooShortException>()),
    );
    api.enqueue(_problem(400, 'BadRequest'));
    await expectLater(
      account.changePassword(currentPassword: '', newPassword: ''),
      throwsA(isA<BadRequestException>()),
    );
  });

  test('changePassword: un 500 llega como ServerErrorException (el cambio pudo confirmarse)', () async {
    api.enqueue(const ApiResponse(statusCode: 500));
    expect(
      account.changePassword(currentPassword: 'x', newPassword: 'nueva-1234567'),
      throwsA(isA<ServerErrorException>()),
    );
  });

  test('deactivate: 204 sin cuerpo es un éxito', () async {
    api.enqueue(const ApiResponse(statusCode: 204));
    await account.deactivate(currentPassword: 'actual-12345');
    expect(api.calls.single.path, '/account/deactivate');
    expect(api.calls.single.body, {'currentPassword': 'actual-12345'});
  });

  test('deactivate: contraseña incorrecta y los 409 llevan su motivo', () async {
    api.enqueue(_problem(400, 'CurrentPasswordIncorrect'));
    await expectLater(account.deactivate(currentPassword: 'x'), throwsA(isA<CurrentPasswordIncorrectException>()));
    api.enqueue(_problem(409, 'RepresentativeTransferRequired'));
    await expectLater(
      account.deactivate(currentPassword: 'x'),
      throwsA(isA<DeactivationBlockedException>().having((e) => e.reason, 'reason', 'RepresentativeTransferRequired')),
    );
  });
}
