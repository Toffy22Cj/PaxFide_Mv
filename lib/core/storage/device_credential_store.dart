import 'dart:convert';

import 'secure_key_value_store.dart';

/// Credencial de este dispositivo para entrar con biometría (M-28, enmienda 2 de ADR-043).
class StoredDeviceCredential {
  const StoredDeviceCredential({required this.credentialId, required this.deviceToken});
  final String credentialId;
  final String deviceToken;
}

/// Dónde vive la credencial del dispositivo. Separada del JWT: cerrar sesión no la borra, porque es lo que permite
/// volver a entrar con la huella.
abstract class DeviceCredentialStore {
  Future<StoredDeviceCredential?> read();
  Future<void> write(StoredDeviceCredential credential);
  Future<void> clear();
}

/// En `flutter_secure_storage` (ADR-043 D5), como el JWT. Un valor ilegible cuenta como ausente.
class SecureDeviceCredentialStore implements DeviceCredentialStore {
  const SecureDeviceCredentialStore(this._store);

  static const _key = 'paxfide.biometric.device';

  final SecureKeyValueStore _store;

  @override
  Future<StoredDeviceCredential?> read() async {
    final raw = await _store.read(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final j = jsonDecode(raw);
      if (j is Map && j['credentialId'] is String && j['deviceToken'] is String) {
        return StoredDeviceCredential(
          credentialId: j['credentialId'] as String,
          deviceToken: j['deviceToken'] as String,
        );
      }
    } on FormatException {
      // ilegible: como si no hubiera
    }
    return null;
  }

  @override
  Future<void> write(StoredDeviceCredential credential) =>
      _store.write(_key, jsonEncode({'credentialId': credential.credentialId, 'deviceToken': credential.deviceToken}));

  @override
  Future<void> clear() => _store.delete(_key);
}

/// En memoria: sin almacén seguro (tests y plataformas sin biometría).
class MemoryDeviceCredentialStore implements DeviceCredentialStore {
  StoredDeviceCredential? _value;

  @override
  Future<StoredDeviceCredential?> read() async => _value;

  @override
  Future<void> write(StoredDeviceCredential credential) async => _value = credential;

  @override
  Future<void> clear() async => _value = null;
}
