import 'package:flutter/foundation.dart';

import '../../core/storage/secure_key_value_store.dart';

/// Pausa de la ciudad de Inicio (web: `PauseButton`, R-F2): la elección se recuerda entre aperturas.
class CityPauseController extends ValueNotifier<bool> {
  CityPauseController([this._store]) : super(false);

  static const storageKey = 'paxfide.ui.cityPaused';

  final SecureKeyValueStore? _store;

  Future<void> load() async {
    try {
      value = await _store?.read(storageKey) == '1';
    } catch (_) {
      value = false;
    }
  }

  Future<void> toggle() async {
    value = !value;
    try {
      value ? await _store?.write(storageKey, '1') : await _store?.delete(storageKey);
    } catch (_) {
      // Si no se puede guardar, vale para esta sesión.
    }
  }
}
