import '../../../core/storage/secure_key_value_store.dart';

/// «Pedir la huella o el rostro al abrir la app» (enmienda 8 de ADR-043, PROPUESTA). Es una preferencia de este
/// teléfono: sin valor guardado está apagada, y solo tiene efecto si la biometría está activada en el teléfono.
abstract class BiometricLockPreference {
  Future<bool> isEnabled();
  Future<void> set(bool enabled);
  Future<void> clear();
}

/// En `flutter_secure_storage` (ADR-043 D5), como la credencial del dispositivo. Un valor ilegible cuenta como apagado.
class SecureBiometricLockPreference implements BiometricLockPreference {
  const SecureBiometricLockPreference(this._store);

  static const key = 'paxfide.biometric.lock';

  final SecureKeyValueStore _store;

  @override
  Future<bool> isEnabled() async {
    try {
      return await _store.read(key) == '1';
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> set(bool enabled) => _store.write(key, enabled ? '1' : '0');

  @override
  Future<void> clear() => _store.delete(key);
}

/// En memoria: tests y plataformas sin biometría.
class MemoryBiometricLockPreference implements BiometricLockPreference {
  bool _value = false;

  @override
  Future<bool> isEnabled() async => _value;

  @override
  Future<void> set(bool enabled) async => _value = enabled;

  @override
  Future<void> clear() async => _value = false;
}
