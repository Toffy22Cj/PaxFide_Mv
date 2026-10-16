import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/core/errors/app_exceptions.dart';
import 'package:paxfide_mobile/core/network/credential_mode.dart';
import 'package:paxfide_mobile/core/storage/device_credential_store.dart';
import 'package:paxfide_mobile/features/auth/biometrics/biometric_authenticator.dart';
import 'package:paxfide_mobile/features/auth/biometrics/biometric_login.dart';
import 'package:paxfide_mobile/features/auth/data/auth_api.dart';
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

    test('activar: confirma la huella, da de alta con la sesión y guarda la credencial', () async {
      api.routes['POST /auth/device-credentials'] = (_) => ok({'credentialId': 'cred-9', 'deviceToken': 'tok-9'}, 201);

      expect(await bio.enable(), BiometricEnableResult.enabled);
      expect(reader.calls, 1);
      expect(api.calls.single.credentialMode, CredentialMode.jwt);
      final saved = await store.read();
      expect(saved?.credentialId, 'cred-9');
      expect(saved?.deviceToken, 'tok-9');
    });

    test('activar sin confirmar la huella, o sin biometría en el teléfono, no llama al backend', () async {
      reader.result = BiometricCheck.canceled;
      expect(await bio.enable(), BiometricEnableResult.canceled);
      reader.available = false;
      expect(await bio.enable(), BiometricEnableResult.unavailable);
      expect(api.calls, isEmpty);
      expect(await store.read(), isNull);
    });

    test('con el máximo de dispositivos (409) lo dice', () async {
      api.routes['POST /auth/device-credentials'] = (_) => status(409);
      expect(await bio.enable(), BiometricEnableResult.tooManyDevices);
    });

    test('desactivar: revoca en el backend y la borra; si ya no existía (404) también la borra', () async {
      await store.write(_stored);
      api.routes['POST /auth/device-credentials/cred-1/revoke'] = (_) => status(204);
      await bio.disable();
      expect(api.calls.single.credentialMode, CredentialMode.jwt);
      expect(await store.read(), isNull);

      await store.write(_stored);
      api.routes['POST /auth/device-credentials/cred-1/revoke'] = (_) => status(404);
      await bio.disable();
      expect(await store.read(), isNull);
    });

    test('desactivar sin conexión no la borra, para no dejarla viva en el backend', () async {
      await store.write(_stored);
      api.routes['POST /auth/device-credentials/cred-1/revoke'] = (_) => const NetworkTimeoutException();

      await expectLater(bio.disable(), throwsA(isA<AppException>()));
      expect(await store.read(), isNotNull);
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

  group('activar y desactivar desde la app', () {
    testWidgets('activarla con la sesión iniciada guarda la credencial', (tester) async {
      final h = Harness(token: 't', biometric: FakeBiometricAuthenticator());
      h.api.routes['POST /auth/device-credentials'] = (_) => ok({'credentialId': 'cred-9', 'deviceToken': 'tok-9'}, 201);
      await h.pump(tester);

      await tester.tap(find.byKey(const Key('home-biometric')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('biometric-switch')));
      await tester.pumpAndSettle();

      expect((await h.deviceCredentials.read())?.credentialId, 'cred-9');
      expect(find.textContaining('La próxima vez podrás entrar con tu huella'), findsOneWidget);
    });

    testWidgets('desactivarla la revoca y la borra', (tester) async {
      final h = Harness(token: 't', biometric: FakeBiometricAuthenticator());
      await h.deviceCredentials.write(_stored);
      h.api.routes['POST /auth/device-credentials/cred-1/revoke'] = (_) => status(204);
      await h.pump(tester);

      await tester.tap(find.byKey(const Key('home-biometric')));
      await tester.pumpAndSettle();
      expect(find.text('Activada en este teléfono'), findsOneWidget);
      await tester.tap(find.byKey(const Key('biometric-switch')));
      await tester.pumpAndSettle();

      expect(await h.deviceCredentials.read(), isNull);
      expect(h.api.calls.where((c) => c.path == '/auth/device-credentials/cred-1/revoke'), hasLength(1));
    });

    testWidgets('sin biometría en el teléfono lo explica y no ofrece el interruptor', (tester) async {
      final h = Harness(token: 't');
      await h.pump(tester);

      await tester.tap(find.byKey(const Key('home-biometric')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('biometric-unavailable')), findsOneWidget);
      expect(find.byKey(const Key('biometric-switch')), findsNothing);
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
