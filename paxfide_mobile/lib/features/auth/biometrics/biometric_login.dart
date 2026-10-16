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

/// Resultado de activar la huella.
enum BiometricEnableResult { enabled, canceled, unavailable, tooManyDevices, networkError }

/// Entrar con biometría (ADR-043 §8.8). El teléfono comprueba la huella o el rostro; si es correcta, envía el token
/// de este dispositivo y recibe un JWT como en el login normal. Nunca se guarda la contraseña.
class BiometricLogin {
  BiometricLogin({required AuthApi api, required DeviceCredentialStore store, required BiometricAuthenticator authenticator})
      : _api = api,
        _store = store,
        _authenticator = authenticator;

  final AuthApi _api;
  final DeviceCredentialStore _store;
  final BiometricAuthenticator _authenticator;

  static const loginReason = 'Pon tu huella para entrar a PaxFide';
  static const enableReason = 'Pon tu huella para activar la entrada con biometría';

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

  /// Con la sesión iniciada: confirma la huella y da de alta este dispositivo.
  Future<BiometricEnableResult> enable({String? deviceName}) async {
    if (!await _authenticator.isAvailable()) return BiometricEnableResult.unavailable;
    if (await _authenticator.authenticate(enableReason) != BiometricCheck.success) {
      return BiometricEnableResult.canceled;
    }
    try {
      final previous = await _stored();
      final e = await _api.enrollDevice(deviceName: deviceName);
      await _store.write(StoredDeviceCredential(credentialId: e.credentialId, deviceToken: e.deviceToken));
      // Si ya había una de este teléfono (p. ej. de otra cuenta), se revoca en lo posible.
      if (previous != null) await _revokeQuietly(previous.credentialId);
      return BiometricEnableResult.enabled;
    } on ConflictException {
      return BiometricEnableResult.tooManyDevices;
    } on AppException {
      return BiometricEnableResult.networkError;
    }
  }

  /// Con la sesión iniciada: la revoca en el backend y la borra de este teléfono. Si ya no existía en el backend
  /// (404) también se borra. Sin conexión no se borra nada y lanza la excepción, para no dejarla viva en el backend.
  Future<void> disable() async {
    final stored = await _stored();
    if (stored == null) return;
    try {
      await _api.revokeDevice(stored.credentialId);
    } on NotFoundException {
      // ya no servía
    } on UnauthorizedException {
      // de otra sesión: el backend la anulará al cambiar la contraseña; aquí se borra igual
    }
    await _store.clear();
  }

  Future<void> _revokeQuietly(String credentialId) async {
    try {
      await _api.revokeDevice(credentialId);
    } on AppException {
      // de otra cuenta o sin conexión: queda sin uso, porque este teléfono ya no guarda su token
    }
  }
}
