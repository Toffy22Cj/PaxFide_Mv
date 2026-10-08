import 'lifecycle_status.dart';

/// Acciones operativas sobre un PhysicalAsset (front-fase1.md §9, ADR-043 D2).
enum AssetAction {
  dispatch(LifecycleStatus.dispatched, 'DISPATCH'),
  receive(LifecycleStatus.received, 'RECEIVE'),
  deliver(LifecycleStatus.delivered, 'DELIVER'),
  readOnly(null, 'READ_ONLY');

  const AssetAction(this.expectedStatusAfter, this.wire);

  /// Estado que debe observarse tras el comando; base de la reconciliación de `AMBIGUOUS` (D6).
  final LifecycleStatus? expectedStatusAfter;

  /// Nombre estable con el que se guarda en el Outbox.
  final String wire;

  static AssetAction? fromWire(String value) {
    for (final a in values) {
      if (a.wire == value) return a;
    }
    return null;
  }
}
