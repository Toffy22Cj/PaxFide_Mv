import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:local_auth/local_auth.dart';

/// Resultado de pedir la huella o el rostro al teléfono (lo que el teléfono tenga configurado: el sistema elige).
enum BiometricCheck {
  /// Huella o rostro correctos.
  success,

  /// El usuario cerró el aviso del teléfono.
  canceled,

  /// No coincidió, se bloqueó tras varios intentos o el teléfono no pudo pedirla.
  failed,
}

/// La biometría del teléfono (M-28, enmienda 2 de ADR-043). Solo dice sí o no: la huella nunca sale del teléfono.
abstract class BiometricAuthenticator {
  /// El teléfono tiene huella o rostro configurados.
  Future<bool> isAvailable();

  Future<BiometricCheck> authenticate(String reason);
}

/// `local_auth`: Android, iOS, macOS y Windows.
class LocalAuthBiometricAuthenticator implements BiometricAuthenticator {
  LocalAuthBiometricAuthenticator([LocalAuthentication? auth]) : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  /// `local_auth` no funciona en Linux ni en la web.
  static bool get supportedPlatform =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS || Platform.isWindows);

  @override
  Future<bool> isAvailable() async {
    try {
      return await _auth.isDeviceSupported() && (await _auth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<BiometricCheck> authenticate(String reason) async {
    try {
      final ok = await _auth.authenticate(localizedReason: reason, biometricOnly: true);
      return ok ? BiometricCheck.success : BiometricCheck.failed;
    } on LocalAuthException catch (e) {
      return switch (e.code) {
        LocalAuthExceptionCode.userCanceled || LocalAuthExceptionCode.systemCanceled => BiometricCheck.canceled,
        _ => BiometricCheck.failed,
      };
    } catch (_) {
      return BiometricCheck.failed;
    }
  }
}

/// Sin biometría (Linux, web): nunca se ofrece.
class UnavailableBiometricAuthenticator implements BiometricAuthenticator {
  const UnavailableBiometricAuthenticator();

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<BiometricCheck> authenticate(String reason) async => BiometricCheck.failed;
}
