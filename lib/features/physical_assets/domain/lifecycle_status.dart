/// Estados del ciclo de vida de un PhysicalAsset (front-fase1.md §9 y `AssetLifecycleStatus` del backend).
///
/// `DEPLETED` existe en el backend (un activo agotado tras una división) y no estaba en §9: es de solo lectura.
enum LifecycleStatus {
  registered('REGISTERED'),
  dispatched('DISPATCHED'),
  received('RECEIVED'),
  delivered('DELIVERED'),
  depleted('DEPLETED');

  const LifecycleStatus(this.wire);

  /// Valor tal como lo envía el backend.
  final String wire;

  /// `null` si el backend envía un valor que este cliente no conoce (se trata como solo lectura).
  static LifecycleStatus? fromWire(String? value) {
    for (final s in values) {
      if (s.wire == value) return s;
    }
    return null;
  }
}
