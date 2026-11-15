import 'package:flutter/foundation.dart';

import '../../core/storage/secure_key_value_store.dart';

/// Tamaño del texto dentro de la app (M-04). Se suma al del teléfono: "Grande" en un teléfono que ya tiene el texto
/// grande lo agranda un poco más. Se recuerda entre aperturas de la app.
enum TextSize {
  normal('Normal', 1.0),
  large('Grande', 1.2),
  extraLarge('Muy grande', 1.4);

  const TextSize(this.label, this.factor);
  final String label;
  final double factor;
}

class TextSizeController extends ValueNotifier<TextSize> {
  TextSizeController([this._store]) : super(TextSize.normal);

  static const storageKey = 'paxfide.ui.textSize';

  final SecureKeyValueStore? _store;

  Future<void> load() async {
    try {
      final saved = await _store?.read(storageKey);
      value = TextSize.values.firstWhere((s) => s.name == saved, orElse: () => TextSize.normal);
    } catch (_) {
      value = TextSize.normal;
    }
  }

  Future<void> select(TextSize size) async {
    value = size;
    try {
      await _store?.write(storageKey, size.name);
    } catch (_) {
      // Si no se puede guardar, el cambio vale para esta sesión.
    }
  }
}
