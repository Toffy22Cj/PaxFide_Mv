import '../../../core/errors/app_exceptions.dart';
import '../../../core/storage/device_credential_store.dart';
import '../data/auth_api.dart';
import 'biometric_authenticator.dart';

/// Resultado de entrar con biometría.
sealed class BiometricLoginResult {
  const BiometricLoginResult();
}

/// Huella correcta y el backend dio el JWT.
class BiometricLoginSucceeded extends BiometricLoginResult {
  const BiometricLoginSucceeded(this.token);
  final String token;
}

/// El usuario cerró el aviso o la huella no coincidió: se queda en el login con contraseña, sin mensaje.
class BiometricLoginDismissed extends BiometricLoginResult {
  const BiometricLoginDismissed();
}

/// El backend ya no acepta la credencial (cambio de contraseña, revocada o cuenta inactiva): se borró de este
/// teléfono y hay que volver a activarla.
class BiometricLoginRevoked extends BiometricLoginResult {
  const BiometricLoginRevoked();
}

/// Sin conexión o error del servidor: la credencial se conserva.
class BiometricLoginNetworkError extends BiometricLoginResult {
  const BiometricLoginNetworkError();
}

/// Resultado de registrar este teléfono para entrar con biometría.
enum BiometricEnableResult { enabled, tooManyDevices, networkError }

/// Entrar con biometría (M-28, enmienda 2 de ADR-043). El teléfono comprueba la huella o el rostro; si es correcta, envía el token
/// de este dispositivo y recibe un JWT como en el login normal. Nunca se guarda la contraseña.
class BiometricLogin {
  BiometricLogin({required this._api, required this._store, required this._authenticator});

  final AuthApi _api;
  final DeviceCredentialStore _store;
  final BiometricAuthenticator _authenticator;

  static const loginReason = 'Usa tu huella o tu rostro para entrar a PaxFide';
  static const enableReason = 'Usa tu huella o tu rostro para activar la entrada con biometría';

  Future<StoredDeviceCredential?> _stored() async {
    try {
      return await _store.read();
    } catch (_) {
      return null;
    }
  }

  /// El teléfono tiene huella o rostro configurados (para ofrecer activarla).
  Future<bool> isAvailable() => _authenticator.isAvailable();

  /// Está activada en este teléfono.
  Future<bool> isEnabled() async => await _stored() != null;

  /// Hay que mostrar "Entrar por biometría" en el login: está activada y el teléfono puede pedirla.
  Future<bool> canOffer() async => await isEnabled() && await _authenticator.isAvailable();

  Future<BiometricLoginResult> login() async {
    final stored = await _stored();
    if (stored == null) return const BiometricLoginRevoked();
    if (await _authenticator.authenticate(loginReason) != BiometricCheck.success) {
      return const BiometricLoginDismissed();
    }
    try {
      return BiometricLoginSucceeded(await _api.deviceLogin(stored.deviceToken));
    } on UnauthorizedException {
      await _store.clear();
      return const BiometricLoginRevoked();
    } on BadRequestException {
      await _store.clear();
      return const BiometricLoginRevoked();
    } on AppException {
      return const BiometricLoginNetworkError();
    }
  }

  /// Tras entrar con contraseña: se ofrece activarla si el teléfono tiene biometría y aún no está activada.
  Future<bool> canOfferEnrollment() async => !await isEnabled() && await _authenticator.isAvailable();

  /// En el login, antes de entrar: el usuario confirma con su huella que quiere activarla.
  Future<bool> confirmEnrollment() async => await _authenticator.authenticate(enableReason) == BiometricCheck.success;

  /// Con la sesión ya iniciada (justo después de [confirmEnrollment]): da de alta este teléfono y guarda la
  /// credencial.
  Future<BiometricEnableResult> register({String? deviceName}) async {
    try {
      final e = await _api.enrollDevice(deviceName: deviceName);
      await _store.write(StoredDeviceCredential(credentialId: e.credentialId, deviceToken: e.deviceToken));
      return BiometricEnableResult.enabled;
    } on ConflictException {
      return BiometricEnableResult.tooManyDevices;
    } on AppException {
      return BiometricEnableResult.networkError;
    }
  }

  /// Desde el login, sin sesión: deja de usar la huella en este teléfono. Se borra el token del teléfono, así que la
  /// credencial del backend queda sin uso (nadie más tiene el token); se anula del todo al cambiar la contraseña.
  Future<void> forget() => _store.clear();
}
