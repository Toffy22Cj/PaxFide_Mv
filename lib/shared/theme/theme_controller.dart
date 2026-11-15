import 'package:flutter/material.dart';

import '../../core/storage/secure_key_value_store.dart';

/// Modo claro, oscuro o "como el teléfono" ([ThemeMode.system], el inicial). Se recuerda entre aperturas de la app.
class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController([this._store]) : super(ThemeMode.system);

  static const storageKey = 'paxfide.ui.theme';

  final SecureKeyValueStore? _store;

  /// Lee la elección guardada. Un valor ausente o desconocido deja "como el teléfono".
  Future<void> load() async {
    try {
      final saved = await _store?.read(storageKey);
      value = ThemeMode.values.firstWhere((m) => m.name == saved, orElse: () => ThemeMode.system);
    } catch (_) {
      value = ThemeMode.system;
    }
  }

  Future<void> select(ThemeMode mode) async {
    value = mode;
    try {
      await _store?.write(storageKey, mode.name);
    } catch (_) {
      // Si no se puede guardar, el cambio vale para esta sesión.
    }
  }
}
