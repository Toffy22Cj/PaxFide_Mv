import 'dart:convert';

import 'auth_api.dart';
import '../../../core/storage/secure_key_value_store.dart';

/// Perfil (`GET /me`) de la sesión recordada, cifrado (Enmienda 4 de ADR-043, S1): para entrar sin conexión.
abstract class ProfileStore {
  Future<MeDto?> read();
  Future<void> write(MeDto me);
  Future<void> clear();
}

class SecureProfileStore implements ProfileStore {
  const SecureProfileStore(this._store);

  static const key = 'paxfide.session.profile';

  final SecureKeyValueStore _store;

  @override
  Future<MeDto?> read() async {
    try {
      final raw = await _store.read(key);
      if (raw == null || raw.isEmpty) return null;
      final j = jsonDecode(raw);
      return j is Map<String, dynamic> ? MeDto.fromJson(j) : null;
    } on Object {
      return null; // ilegible: como si no hubiera
    }
  }

  @override
  Future<void> write(MeDto me) => _store.write(
    key,
    jsonEncode({
      'accountId': me.accountId,
      'organizationId': ?me.organizationId,
      'roles': me.roles,
      'platformAuthority': ?me.platformAuthority,
    }),
  );

  @override
  Future<void> clear() => _store.delete(key);
}

/// Sin almacén (tests que no lo necesitan): nunca hay perfil guardado.
class NoProfileStore implements ProfileStore {
  const NoProfileStore();

  @override
  Future<MeDto?> read() async => null;

  @override
  Future<void> write(MeDto me) async {}

  @override
  Future<void> clear() async {}
}
