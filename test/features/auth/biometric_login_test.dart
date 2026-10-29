import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/core/errors/app_exceptions.dart';
import 'package:paxfide_mobile/core/network/api_response.dart';
import 'package:paxfide_mobile/core/network/credential_mode.dart';
import 'package:paxfide_mobile/core/storage/device_credential_store.dart';
import 'package:paxfide_mobile/features/auth/biometrics/biometric_authenticator.dart';
import 'package:paxfide_mobile/features/auth/biometrics/biometric_login.dart';
import 'package:paxfide_mobile/features/auth/data/auth_api.dart';

import '../../support/app_harness.dart';
import '../../support/fakes.dart';

const _stored = StoredDeviceCredential(credentialId: 'cred-1', deviceToken: 'tok-1');
const _deviceKey = 'paxfide.biometric.device';

ApiResponse _ok(Map<String, dynamic> data, [int code = 200]) => ApiResponse(statusCode: code, data: data);

/// La lista de Cuenta (para desplazarla hasta lo que queda debajo del pliegue).
/// La lista de Cuenta: el primer `Scrollable` de la pantalla (los campos de texto que vienen después tienen el suyo).
final _accountList = find.byType(Scrollable).first;

void main() {
  group('BiometricLogin (M-28)', () {
    late FakeApiClient api;
    late MemoryDeviceCredentialStore store;
    late FakeBiometricAuthenticator reader;
    late BiometricLogin bio;

    setUp(() {
      api = FakeApiClient();
      store = MemoryDeviceCredentialStore();
      reader = FakeBiometricAuthenticator();
      bio = BiometricLogin(api: AuthApi(api), store: store, authenticator: reader);
    });

    test('con huella o rostro correctos envía el token del dispositivo, sin sesión, y devuelve el JWT', () async {
      await store.write(_stored);
      api.routes['POST /auth/device-login'] = (_) => _ok({'token': 'jwt-1'});
      final r = await bio.login();
      expect(r, isA<BiometricLoginSucceeded>().having((s) => s.token, 'token', 'jwt-1'));
      expect(api.calls.single.body, {'deviceToken': 'tok-1'});
      expect(api.calls.single.credentialMode, CredentialMode.none);
    });

    test('si se cancela no se llama al backend', () async {
      await store.write(_stored);
      reader.result = BiometricCheck.canceled;
      expect(await bio.login(), isA<BiometricLoginDismissed>());
      expect(api.calls, isEmpty);
    });

    test('un 401 borra la credencial de este teléfono; sin conexión se conserva', () async {
      await store.write(_stored);
      api.routes['POST /auth/device-login'] = (_) => const NetworkTimeoutException();
      expect(await bio.login(), isA<BiometricLoginNetworkError>());
      expect(await store.read(), isNotNull);
      api.routes['POST /auth/device-login'] = (_) => const ApiResponse(statusCode: 401);
      expect(await bio.login(), isA<BiometricLoginRevoked>());
      expect(await store.read(), isNull);
    });

    test('registrar da de alta con la sesión; 409 o sin conexión no guarda nada', () async {
      api.routes['POST /auth/device-credentials'] = (_) => const ApiResponse(statusCode: 409);
      expect(await bio.register(), BiometricEnableResult.tooManyDevices);
      api.routes['POST /auth/device-credentials'] = (_) => const NetworkTimeoutException();
      expect(await bio.register(), BiometricEnableResult.networkError);
      expect(await store.read(), isNull);
      api.routes['POST /auth/device-credentials'] = (_) => _ok({'credentialId': 'cred-9', 'deviceToken': 'tok-9'}, 201);
      expect(await bio.register(), BiometricEnableResult.enabled);
      expect(api.calls.last.credentialMode, CredentialMode.jwt);
      expect((await store.read())?.deviceToken, 'tok-9');
    });
  });

  group('login: recuadro "Entrar por biometría"', () {
    Future<AppHarness> openLogin(WidgetTester tester, FakeBiometricAuthenticator reader, {bool enabled = true}) async {
      final h = AppHarness(biometric: reader);
      if (enabled) h.saveDeviceCredential();
      h.api.routes['POST /auth/device-login'] = (_) => _ok({'token': 'jwt-bio'});
      h.api.routes['GET /me'] = (_) => meResponse(roles: const []);
      await h.start(tester);
      await tester.pumpAndSettle();
      return h;
    }

    testWidgets('aparece solo, con el logo, y con huella o rostro correctos entra sin escribir nada', (tester) async {
      final h = await openLogin(tester, FakeBiometricAuthenticator());
      expect(h.biometric.calls, 1);
      expect(h.secure.values['paxfide.session.jwt'], 'jwt-bio');
      expect(h.location, '/home');
    });

    testWidgets('con la X se cierra y queda el login con contraseña y el botón para reintentar', (tester) async {
      final h = await openLogin(tester, FakeBiometricAuthenticator(pending: true));
      expect(find.byKey(const Key('biometric-login-dialog')), findsOneWidget);
      expect(find.text('Entrar por biometría'), findsOneWidget);
      expect(find.byIcon(Icons.face_outlined), findsOneWidget);
      await tester.tap(find.byKey(const Key('biometric-login-close')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('biometric-login-dialog')), findsNothing);
      expect(find.byKey(const Key('login.password')), findsOneWidget);
      expect(find.byKey(const Key('login-biometric')), findsOneWidget);
      expect(h.api.calls.where((c) => c.path == '/auth/device-login'), isEmpty);
    });

    testWidgets('si ya no sirve, lo dice y la quita de este teléfono', (tester) async {
      final h = AppHarness(biometric: FakeBiometricAuthenticator());
      h.saveDeviceCredential();
      h.api.routes['POST /auth/device-login'] = (_) => const ApiResponse(statusCode: 401);
      await h.start(tester);
      await tester.pumpAndSettle();
      expect(find.textContaining('ya no sirve en este teléfono'), findsOneWidget);
      expect(find.byKey(const Key('login-biometric')), findsNothing);
      expect(h.secure.values[_deviceKey], isNull);
    });

    testWidgets('NEGATIVA: sin activarla, o en un equipo sin biometría (Linux), no aparece', (tester) async {
      var h = await openLogin(tester, FakeBiometricAuthenticator(), enabled: false);
      expect(find.byKey(const Key('biometric-login-dialog')), findsNothing);
      expect(h.biometric.calls, 0);
      h = await openLogin(tester, FakeBiometricAuthenticator(available: false));
      expect(find.byKey(const Key('login-biometric')), findsNothing);
      expect(h.biometric.calls, 0);
    });

    testWidgets('dejar de usarla desde el login', (tester) async {
      final h = await openLogin(tester, FakeBiometricAuthenticator(pending: true));
      await tester.tap(find.byKey(const Key('biometric-login-close')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('login-biometric-forget')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('login-biometric-forget')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('biometric-forget-confirm')));
      await tester.pumpAndSettle();
      expect(h.secure.values[_deviceKey], isNull);
      expect(find.byKey(const Key('login-biometric')), findsNothing);
    });
  });

  group('activarla tras entrar con contraseña', () {
    Future<AppHarness> passwordLogin(WidgetTester tester, FakeBiometricAuthenticator reader) async {
      final h = AppHarness(biometric: reader);
      h.api.routes['POST /auth/login'] = (_) => _ok({'token': 'jwt-pass'});
      h.api.routes['GET /me'] = (_) => meResponse(roles: const []);
      h.api.routes['POST /auth/device-credentials'] = (_) =>
          _ok({'credentialId': 'cred-9', 'deviceToken': 'tok-9'}, 201);
      await h.start(tester);
      await tester.enterText(find.byKey(const Key('login.email')), 'ana@correo.co');
      await tester.enterText(find.byKey(const Key('login.password')), 'secreta');
      await tester.ensureVisible(find.byKey(const Key('login.submit')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('login.submit')));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      return h;
    }

    testWidgets('pregunta, confirma con huella o rostro y entra; la credencial queda guardada', (tester) async {
      final h = await passwordLogin(tester, FakeBiometricAuthenticator());
      expect(find.text('¿Entrar con tu huella o tu rostro la próxima vez?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('biometric-offer-yes')));
      await tester.pumpAndSettle();
      expect(h.location, '/home');
      expect(h.secure.values[_deviceKey], contains('tok-9'));
      expect(find.text('Listo. La próxima vez podrás entrar con tu huella o tu rostro.'), findsOneWidget);
    });

    testWidgets('"Ahora no": entra sin activarla', (tester) async {
      final h = await passwordLogin(tester, FakeBiometricAuthenticator());
      await tester.tap(find.byKey(const Key('biometric-offer-no')));
      await tester.pumpAndSettle();
      expect(h.location, '/home');
      expect(h.api.calls.where((c) => c.path == '/auth/device-credentials'), isEmpty);
    });

    testWidgets('NEGATIVA: sin biometría en el equipo no pregunta y la pantalla de inicio no la muestra', (
      tester,
    ) async {
      final h = await passwordLogin(tester, FakeBiometricAuthenticator(available: false));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('biometric-offer')), findsNothing);
      expect(h.location, '/home');
      expect(find.byIcon(Icons.fingerprint), findsNothing);
    });

    testWidgets('cerrar sesión no la desactiva: al volver al login aparece el recuadro', (tester) async {
      final h = AppHarness(biometric: FakeBiometricAuthenticator(pending: true));
      h.saveToken('jwt');
      h.saveDeviceCredential();
      await h.start(tester, beforeSession: () async => h.api.enqueue(meResponse(roles: const [])));
      h.services.router.go('/account');
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.byKey(const Key('account.logout')), 200, scrollable: _accountList);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('account.logout')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('account.logout.yes')));
      await tester.pumpAndSettle();
      expect(h.secure.values[_deviceKey], isNotNull);
      expect(find.byKey(const Key('biometric-login-dialog')), findsOneWidget);
    });
  });
}
