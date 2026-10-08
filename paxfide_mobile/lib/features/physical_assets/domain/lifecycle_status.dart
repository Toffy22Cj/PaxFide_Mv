/// Valor de `lifecycleStatus` que esta versión no conoce. Nunca se convierte
/// en otro estado por defecto.
class UnknownLifecycleStatusException implements Exception {
  final String value;
  const UnknownLifecycleStatusException(this.value);

  @override
  String toString() => 'UnknownLifecycleStatusException: "$value"';
}

/// Estados del ciclo de vida de un PhysicalAsset, iguales a
/// `AssetLifecycleStatus` del backend.
enum LifecycleStatus {
  registered('REGISTERED'),
  dispatched('DISPATCHED'),
  received('RECEIVED'),
  delivered('DELIVERED'),

  /// El activo se agotó al dividirse por completo. Terminal.
  depleted('DEPLETED');

  final String apiValue;
  const LifecycleStatus(this.apiValue);

  /// Texto del backend → estado. Lanza [UnknownLifecycleStatusException] con
  /// un valor desconocido.
  static LifecycleStatus fromApi(String value) {
    for (final status in LifecycleStatus.values) {
      if (status.apiValue == value) return status;
    }
    throw UnknownLifecycleStatusException(value);
  }
}
