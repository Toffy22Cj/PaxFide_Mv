// Enmienda 8 de ADR-043 (PROPUESTA): activar la huella desde Cuenta y pedirla al abrir la app.
// ESTAS PRUEBAS NO SE HAN EJECUTADO: el entorno donde se escribieron no tiene Flutter. Las corre Adonis
// (`flutter analyze` y `flutter test`) y pega la salida literal en el PR.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/app/app_routes.dart';
import 'package:paxfide_mobile/core/network/api_response.dart';
import 'package:paxfide_mobile/core/storage/device_credential_store.dart';
import 'package:paxfide_mobile/features/auth/biometrics/biometric_authenticator.dart';
import 'package:paxfide_mobile/features/auth/biometrics/biometric_lock_preference.dart';
import 'package:paxfide_mobile/features/auth/biometrics/biometric_login.dart';
import 'package:paxfide_mobile/features/auth/data/auth_api.dart';

import '../../support/app_harness.dart';
import '../../support/fakes.dart';

const _stored = StoredDeviceCredential(credentialId: 'cred-1', deviceToken: 'tok-1');
const _deviceKey = 'paxfide.biometric.device';
const _lockKey = 'paxfide.biometric.lock';

ApiResponse _ok(Map<String, dynamic> data, [int code = 200]) => ApiResponse(statusCode: code, data: data);

void main() {
  group('BiometricLogin: activar desde Cuenta y pedirla al abrir', () {
    late FakeApiClient api;
    late MemoryDeviceCredentialStore store;
    late MemoryBiometricLockPreference lock;
    late FakeBiometricAuthenticator reader;
    late BiometricLogin bio;

    setUp(() {
      api = FakeApiClient();
      store = MemoryDeviceCredentialStore();
      lock = MemoryBiometricLockPreference();
      reader = FakeBiometricAuthenticator();
      bio = BiometricLogin(api: AuthApi(api), store: store, authenticator: reader, lock: lock);
      api.routes['POST /auth/device-credentials'] = (_) => _ok({'credentialId': 'cred-9', 'deviceToken': 'tok-9'}, 201);
    });

    test('confirma con la huella, da de alta el teléfono y enciende «pedir al abrir»', () async {
      expect(await bio.enableWithConfirmation(), BiometricEnableResult.enabled);
      expect((await store.read())?.deviceToken, 'tok-9');
      expect(await lock.isEnabled(), isTrue);
      expect(reader.calls, 1);
    });

    test('NEGATIVA: si no se confirma con la huella no se llama al backend ni se guarda nada', () async {
      reader.result = BiometricCheck.canceled;
      expect(await bio.enableWithConfirmation(), isNull);
      expect(api.calls, isEmpty);
      expect(await store.read(), isNull);
      expect(await lock.isEnabled(), isFalse);
    });

    test('NEGATIVA: sin biometría en el teléfono devuelve null sin pedir nada', () async {
      reader.available = false;
      expect(await bio.enableWithConfirmation(), isNull);
      expect(reader.calls, 0);
      expect(api.calls, isEmpty);
    });

    test('409 (10 teléfonos) o sin conexión: ni credencial ni «pedir al abrir»', () async {
      api.routes['POST /auth/device-credentials'] = (_) => const ApiResponse(statusCode: 409);
      expect(await bio.enableWithConfirmation(), BiometricEnableResult.tooManyDevices);
      expect(await store.read(), isNull);
      expect(await lock.isEnabled(), isFalse);
    });

    test('shouldLockOnOpen: necesita credencial, preferencia y biometría en el teléfono (las tres)', () async {
      await lock.set(true);
      expect(await bio.shouldLockOnOpen(), isFalse, reason: 'sin credencial');
      await store.write(_stored);
      expect(await bio.shouldLockOnOpen(), isTrue);
      reader.available = false;
      expect(await bio.shouldLockOnOpen(), isFalse, reason: 'el teléfono ya no tiene biometría');
      reader.available = true;
      await lock.set(false);
      expect(await bio.shouldLockOnOpen(), isFalse, reason: 'preferencia apagada');
    });

    test('forget borra la credencial y también «pedir al abrir»', () async {
      await store.write(_stored);
      await lock.set(true);
      await bio.forget();
      expect(await store.read(), isNull);
      expect(await lock.isEnabled(), isFalse);
    });

    test('unlock nunca llama al backend', () async {
      expect(await bio.unlock(), BiometricCheck.success);
      expect(api.calls, isEmpty);
    });
  });

  group('al abrir la app con la sesión recordada', () {
    Future<AppHarness> open(
      WidgetTester tester,
      FakeBiometricAuthenticator reader, {
      bool credential = true,
      bool lock = true,
      bool token = true,
    }) async {
      final h = AppHarness(biometric: reader);
      if (credential) h.saveDeviceCredential();
      if (lock) h.saveBiometricLock();
      if (token) h.saveToken('jwt-1');
      h.api.routes['GET /me'] = (_) => meResponse(roles: const ['EMPLOYEE']);
      await h.start(tester);
      return h;
    }

    testWidgets('queda tapada, pide la huella, y con la huella correcta abre Inicio sin llamar al backend', (tester) async {
      final h = await open(tester, FakeBiometricAuthenticator());
      expect(h.biometric.calls, 1);
      expect(find.byKey(const Key('biometric-lock')), findsNothing);
      expect(h.location, '/home');
      expect(h.api.calls.where((c) => c.path.startsWith('/auth/')), isEmpty);
    });

    testWidgets('mientras espera la huella, la app está tapada y no se puede tocar', (tester) async {
      final h = await open(tester, FakeBiometricAuthenticator(pending: true));
      expect(find.byKey(const Key('biometric-lock')), findsOneWidget);
      expect(find.text('PaxFide está bloqueada'), findsOneWidget);
      h.biometric.complete(BiometricCheck.success);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('biometric-lock')), findsNothing);
    });

    testWidgets('si se cancela o falla, sigue bloqueada con su mensaje y se puede reintentar', (tester) async {
      final reader = FakeBiometricAuthenticator(result: BiometricCheck.canceled);
      await open(tester, reader);
      expect(find.byKey(const Key('biometric-lock')), findsOneWidget);
      expect(find.text('Cancelaste la verificación.'), findsOneWidget);
      reader.result = BiometricCheck.failed;
      await tester.tap(find.byKey(const Key('biometric-lock-unlock')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('biometric-lock')), findsOneWidget);
      expect(find.textContaining('No pudimos verificar'), findsOneWidget);
      reader.result = BiometricCheck.success;
      await tester.tap(find.byKey(const Key('biometric-lock-unlock')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('biometric-lock')), findsNothing);
    });

    testWidgets('«Entrar con contraseña» cierra la sesión y deja el login, sin desbloquear nada', (tester) async {
      final h = await open(tester, FakeBiometricAuthenticator(result: BiometricCheck.canceled));
      await tester.tap(find.byKey(const Key('biometric-lock-password')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('biometric-lock')), findsNothing);
      expect(h.secure.values['paxfide.session.jwt'], isNull);
      expect(h.location, AppRoutes.login);
    });

    testWidgets('NEGATIVA: con «pedir al abrir» apagado no se pide nada', (tester) async {
      final h = await open(tester, FakeBiometricAuthenticator(), lock: false);
      expect(h.biometric.calls, 0);
      expect(find.byKey(const Key('biometric-lock')), findsNothing);
      expect(h.location, '/home');
    });

    testWidgets('NEGATIVA: sin credencial en el teléfono no se pide, aunque la preferencia esté encendida', (tester) async {
      final h = await open(tester, FakeBiometricAuthenticator(), credential: false);
      expect(h.biometric.calls, 0);
      expect(find.byKey(const Key('biometric-lock')), findsNothing);
    });

    testWidgets('NEGATIVA: sin sesión guardada no se pide: el login ya ofrece la biometría', (tester) async {
      final h = await open(tester, FakeBiometricAuthenticator(result: BiometricCheck.canceled), token: false);
      expect(find.byKey(const Key('biometric-lock')), findsNothing);
      expect(find.byKey(const Key('login-biometric')), findsOneWidget);
      expect(h.api.calls.where((c) => c.path == '/auth/device-login'), isEmpty);
    });
  });

  group('Cuenta: activarla cuando se quiera', () {
    Future<AppHarness> openAccount(
      WidgetTester tester,
      FakeBiometricAuthenticator reader, {
      bool credential = false,
    }) async {
      final h = AppHarness(biometric: reader);
      if (credential) h.saveDeviceCredential();
      h.saveToken('jwt-1');
      h.api.routes['GET /me'] = (_) => meResponse(roles: const ['EMPLOYEE']);
      h.api.routes['POST /auth/device-credentials'] = (_) =>
          _ok({'credentialId': 'cred-9', 'deviceToken': 'tok-9'}, 201);
      await h.start(tester);
      h.services.router.go(AppRoutes.account);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('account.biometric')));
      await tester.pump();
      return h;
    }

    testWidgets('con biometría en el teléfono y sin activar: el interruptor aparece apagado, y no hay el de «al abrir»', (
      tester,
    ) async {
      await openAccount(tester, FakeBiometricAuthenticator());
      expect(find.byKey(const Key('account.biometric')), findsOneWidget);
      expect(tester.widget<SwitchListTile>(find.byKey(const Key('account.biometric'))).value, isFalse);
      expect(find.byKey(const Key('account.biometricLock')), findsNothing);
    });

    testWidgets('al encenderlo confirma con la huella, da de alta el teléfono y aparece «Pedir la huella al abrir» encendido', (
      tester,
    ) async {
      final h = await openAccount(tester, FakeBiometricAuthenticator());
      await tester.tap(find.byKey(const Key('account.biometric')));
      await tester.pumpAndSettle();
      expect(h.secure.values[_deviceKey], contains('tok-9'));
      expect(h.secure.values[_lockKey], '1');
      expect(find.byKey(const Key('account.biometricLock')), findsOneWidget);
      expect(tester.widget<SwitchListTile>(find.byKey(const Key('account.biometricLock'))).value, isTrue);
    });

    testWidgets('NEGATIVA: si se cancela la huella no se activa ni se llama al backend', (tester) async {
      final h = await openAccount(tester, FakeBiometricAuthenticator(result: BiometricCheck.canceled));
      await tester.tap(find.byKey(const Key('account.biometric')));
      await tester.pumpAndSettle();
      expect(h.secure.values[_deviceKey], isNull);
      expect(h.api.calls.where((c) => c.path == '/auth/device-credentials'), isEmpty);
      expect(tester.widget<SwitchListTile>(find.byKey(const Key('account.biometric'))).value, isFalse);
    });

    testWidgets('apagar «pedir al abrir» deja la entrada con biometría; apagar la entrada borra las dos cosas', (
      tester,
    ) async {
      final h = await openAccount(tester, FakeBiometricAuthenticator(), credential: true);
      h.saveBiometricLock();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('account.biometricLock')));
      await tester.pumpAndSettle();
      expect(h.secure.values[_lockKey], '0');
      expect(h.secure.values[_deviceKey], isNotNull);
      await tester.tap(find.byKey(const Key('account.biometric')));
      await tester.pumpAndSettle();
      expect(h.secure.values[_deviceKey], isNull);
      expect(h.secure.values[_lockKey], isNull);
      expect(find.byKey(const Key('account.biometricLock')), findsNothing);
    });

    testWidgets('NEGATIVA: sin biometría en el teléfono y sin activar, no hay ningún interruptor', (tester) async {
      final h = AppHarness(biometric: FakeBiometricAuthenticator(available: false));
      h.saveToken('jwt-1');
      h.api.routes['GET /me'] = (_) => meResponse(roles: const ['EMPLOYEE']);
      await h.start(tester);
      h.services.router.go(AppRoutes.account);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('account.biometric')), findsNothing);
      expect(find.byKey(const Key('account.biometricLock')), findsNothing);
    });
  });
}
