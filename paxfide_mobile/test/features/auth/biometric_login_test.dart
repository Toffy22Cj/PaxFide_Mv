import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/core/errors/app_exceptions.dart';
import 'package:paxfide_mobile/core/network/credential_mode.dart';
import 'package:paxfide_mobile/core/storage/device_credential_store.dart';
import 'package:paxfide_mobile/features/auth/biometrics/biometric_authenticator.dart';
import 'package:paxfide_mobile/features/auth/biometrics/biometric_login.dart';
import 'package:paxfide_mobile/features/auth/data/auth_api.dart';
import 'package:paxfide_mobile/features/auth/data/login_gateway.dart';
import 'package:paxfide_mobile/features/auth/data/me_gateway.dart';

import '../../support/app_harness.dart';
import '../../support/fakes.dart';

const _stored = StoredDeviceCredential(credentialId: 'cred-1', deviceToken: 'tok-1');

void main() {
  group('BiometricLogin', () {
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

    test('con la huella correcta envía el token del dispositivo, sin sesión, y devuelve el JWT', () async {
      await store.write(_stored);
      api.routes['POST /auth/device-login'] = (_) => ok({'token': 'jwt-1'});

      final r = await bio.login();

      expect(r, isA<BiometricLoginSucceeded>().having((s) => s.token, 'token', 'jwt-1'));
      expect(api.calls.single.body, {'deviceToken': 'tok-1'});
      expect(api.calls.single.credentialMode, CredentialMode.none);
    });

    test('si se cancela la huella no se llama al backend', () async {
      await store.write(_stored);
      reader.result = BiometricCheck.canceled;

      expect(await bio.login(), isA<BiometricLoginDismissed>());
      expect(api.calls, isEmpty);
    });

    test('un 401 borra la credencial de este teléfono', () async {
      await store.write(_stored);
      api.routes['POST /auth/device-login'] = (_) => status(401);

      expect(await bio.login(), isA<BiometricLoginRevoked>());
      expect(await store.read(), isNull);
    });

    test('sin conexión se conserva la credencial', () async {
      await store.write(_stored);
      api.routes['POST /auth/device-login'] = (_) => const NetworkTimeoutException();

      expect(await bio.login(), isA<BiometricLoginNetworkError>());
      expect(await store.read(), isNotNull);
    });

    test('registrar: da de alta con la sesión y guarda la credencial', () async {
      api.routes['POST /auth/device-credentials'] = (_) => ok({'credentialId': 'cred-9', 'deviceToken': 'tok-9'}, 201);

      expect(await bio.register(), BiometricEnableResult.enabled);
      expect(api.calls.single.credentialMode, CredentialMode.jwt);
      final saved = await store.read();
      expect(saved?.credentialId, 'cred-9');
      expect(saved?.deviceToken, 'tok-9');
    });

    test('se ofrece activarla solo con biometría en el teléfono y si aún no está activada', () async {
      expect(await bio.canOfferEnrollment(), isTrue);
      await store.write(_stored);
      expect(await bio.canOfferEnrollment(), isFalse);
      await store.clear();
      reader.available = false;
      expect(await bio.canOfferEnrollment(), isFalse);
    });

    test('confirmar la activación pide la huella; cancelarla es un no', () async {
      expect(await bio.confirmEnrollment(), isTrue);
      reader.result = BiometricCheck.canceled;
      expect(await bio.confirmEnrollment(), isFalse);
      expect(api.calls, isEmpty);
    });

    test('con el máximo de dispositivos (409) o sin conexión no guarda nada', () async {
      api.routes['POST /auth/device-credentials'] = (_) => status(409);
      expect(await bio.register(), BiometricEnableResult.tooManyDevices);
      api.routes['POST /auth/device-credentials'] = (_) => const NetworkTimeoutException();
      expect(await bio.register(), BiometricEnableResult.networkError);
      expect(await store.read(), isNull);
    });

    test('dejar de usarla la borra del teléfono sin llamar al backend', () async {
      await store.write(_stored);
      await bio.forget();
      expect(await store.read(), isNull);
      expect(api.calls, isEmpty);
    });
  });

  group('login: recuadro "Entrar por biometría"', () {
    Future<Harness> openLogin(WidgetTester tester, FakeBiometricAuthenticator reader, {bool enabled = true}) async {
      final h = Harness(biometric: reader, meResult: const MeSucceeded(donor));
      if (enabled) await h.deviceCredentials.write(_stored);
      h.api.routes['POST /auth/device-login'] = (_) => ok({'token': 'jwt-bio'});
      await h.pump(tester, initialRoute: '/login');
      return h;
    }

    testWidgets('aparece solo y, con la huella correcta, entra sin escribir nada', (tester) async {
      final h = await openLogin(tester, FakeBiometricAuthenticator());

      expect(h.biometric.calls, 1);
      expect(h.tokenStore.token, 'jwt-bio');
      expect(find.byKey(const Key('biometric-login-dialog')), findsNothing);
      expect(find.byKey(const Key('home-logout')), findsOneWidget);
    });

    testWidgets('con la X se cierra y queda el login con contraseña', (tester) async {
      final h = await openLogin(tester, FakeBiometricAuthenticator(pending: true));
      expect(find.byKey(const Key('biometric-login-dialog')), findsOneWidget);
      expect(find.text('Entrar por biometría'), findsOneWidget);

      await tester.tap(find.byKey(const Key('biometric-login-close')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('biometric-login-dialog')), findsNothing);
      expect(find.byKey(const Key('login-password')), findsOneWidget);
      expect(find.byKey(const Key('login-biometric')), findsOneWidget, reason: 'puede volver a intentarlo');
      expect(h.api.calls.where((c) => c.path == '/auth/device-login'), isEmpty);
    });

    testWidgets('tocando fuera también se cierra', (tester) async {
      await openLogin(tester, FakeBiometricAuthenticator(pending: true));

      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('biometric-login-dialog')), findsNothing);
      expect(find.byKey(const Key('login-password')), findsOneWidget);
    });

    testWidgets('si la huella ya no sirve, lo dice y la quita de este teléfono', (tester) async {
      final h = Harness(biometric: FakeBiometricAuthenticator());
      await h.deviceCredentials.write(_stored);
      h.api.routes['POST /auth/device-login'] = (_) => status(401);
      await h.pump(tester, initialRoute: '/login');

      expect(find.byKey(const Key('login-biometric-revoked')), findsOneWidget);
      expect(find.byKey(const Key('login-biometric')), findsNothing);
      expect(await h.deviceCredentials.read(), isNull);
    });

    testWidgets('NEGATIVA: sin activarla no aparece', (tester) async {
      final h = await openLogin(tester, FakeBiometricAuthenticator(), enabled: false);
      expect(find.byKey(const Key('biometric-login-dialog')), findsNothing);
      expect(find.byKey(const Key('login-biometric')), findsNothing);
      expect(h.biometric.calls, 0);
    });

    testWidgets('NEGATIVA: en un equipo sin biometría (Linux) no aparece aunque esté guardada', (tester) async {
      final h = await openLogin(tester, FakeBiometricAuthenticator(available: false));
      expect(find.byKey(const Key('biometric-login-dialog')), findsNothing);
      expect(h.biometric.calls, 0);
    });
  });

  group('activarla desde el login, tras entrar con contraseña', () {
    Harness passwordLogin(FakeBiometricAuthenticator reader) {
      final h = Harness(biometric: reader, loginResult: const LoginSucceeded('jwt-pass'));
      h.api.routes['POST /auth/device-credentials'] = (_) => ok({'credentialId': 'cred-9', 'deviceToken': 'tok-9'}, 201);
      return h;
    }

    Future<void> submitPassword(WidgetTester tester) async {
      await tester.enterText(find.byKey(const Key('login-email')), 'ana@correo.co');
      await tester.enterText(find.byKey(const Key('login-password')), 'secreta');
      await tester.tap(find.byKey(const Key('login-submit')));
      // El botón "Entrar" sigue cargando detrás de la pregunta: no se puede "asentar".
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('pregunta, el usuario activa con su huella y entra; la credencial queda guardada', (tester) async {
      final h = passwordLogin(FakeBiometricAuthenticator());
      await h.pump(tester, initialRoute: '/login');
      await submitPassword(tester);

      expect(find.byKey(const Key('biometric-offer')), findsOneWidget);
      expect(find.text('¿Entrar con tu huella la próxima vez?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('biometric-offer-yes')));
      await tester.pumpAndSettle();

      expect(h.biometric.calls, 1);
      expect(find.byKey(const Key('home-logout')), findsOneWidget);
      final enroll = h.api.calls.singleWhere((c) => c.path == '/auth/device-credentials');
      expect(enroll.credentialMode, CredentialMode.jwt);
      expect((await h.deviceCredentials.read())?.credentialId, 'cred-9');
      expect(find.text('Listo. La próxima vez podrás entrar con tu huella.'), findsOneWidget);
    });

    testWidgets('"Ahora no": entra sin activarla', (tester) async {
      final h = passwordLogin(FakeBiometricAuthenticator());
      await h.pump(tester, initialRoute: '/login');
      await submitPassword(tester);

      await tester.tap(find.byKey(const Key('biometric-offer-no')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('home-logout')), findsOneWidget);
      expect(h.biometric.calls, 0);
      expect(h.api.calls.where((c) => c.path == '/auth/device-credentials'), isEmpty);
      expect(await h.deviceCredentials.read(), isNull);
    });

    testWidgets('si no confirma con la huella, entra sin activarla', (tester) async {
      final h = passwordLogin(FakeBiometricAuthenticator(result: BiometricCheck.canceled));
      await h.pump(tester, initialRoute: '/login');
      await submitPassword(tester);
      await tester.tap(find.byKey(const Key('biometric-offer-yes')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('home-logout')), findsOneWidget);
      expect(h.api.calls.where((c) => c.path == '/auth/device-credentials'), isEmpty);
    });

    testWidgets('NEGATIVA: sin biometría en el equipo (Linux) no pregunta', (tester) async {
      final h = passwordLogin(FakeBiometricAuthenticator(available: false));
      await h.pump(tester, initialRoute: '/login');
      await submitPassword(tester);

      expect(find.byKey(const Key('biometric-offer')), findsNothing);
      expect(find.byKey(const Key('home-logout')), findsOneWidget);
    });

    testWidgets('NEGATIVA: la pantalla de inicio no tiene nada de la huella', (tester) async {
      final h = Harness(token: 't', biometric: FakeBiometricAuthenticator());
      await h.pump(tester);
      expect(find.byKey(const Key('home-biometric')), findsNothing);
      expect(find.byIcon(Icons.fingerprint), findsNothing);
    });

    testWidgets('dejar de usarla desde el login', (tester) async {
      final h = Harness(biometric: FakeBiometricAuthenticator(pending: true));
      await h.deviceCredentials.write(_stored);
      await h.pump(tester, initialRoute: '/login');
      await tester.tap(find.byKey(const Key('biometric-login-close')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('login-biometric-forget')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('biometric-forget-confirm')));
      await tester.pumpAndSettle();

      expect(await h.deviceCredentials.read(), isNull);
      expect(find.byKey(const Key('login-biometric')), findsNothing);
    });

    testWidgets('cerrar sesión no la desactiva: al volver al login aparece el recuadro', (tester) async {
      final h = Harness(token: 't', biometric: FakeBiometricAuthenticator(pending: true));
      await h.deviceCredentials.write(_stored);
      await h.pump(tester);

      await tester.tap(find.byKey(const Key('home-logout')));
      await tester.pumpAndSettle();

      expect(await h.deviceCredentials.read(), isNotNull);
      expect(find.byKey(const Key('biometric-login-dialog')), findsOneWidget);
    });
  });
}
