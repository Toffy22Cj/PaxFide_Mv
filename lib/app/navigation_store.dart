import '../core/storage/secure_key_value_store.dart';
import 'navigation_restore_state.dart';

/// Persistencia de la única posición de restauración (ADR-043 D7). Usa el almacén cifrado aprobado (D12).
/// Solo guarda estados válidos (rutas del árbol, sin credenciales).
class NavigationStore {
  const NavigationStore(this._store);

  static const _key = 'paxfide.navigation.restore';

  final SecureKeyValueStore _store;

  Future<NavigationRestoreState?> read() async {
    final raw = await _store.read(_key);
    if (raw == null) return null;
    final state = NavigationRestoreState.tryFromJson(raw);
    if (state == null || !state.isValid()) {
      await _store.delete(_key); // corrupto o incompatible → se descarta
      return null;
    }
    return state;
  }

  Future<void> save(NavigationRestoreState state) async {
    if (!state.isValid()) return;
    await _store.write(_key, state.toJson());
  }
}
