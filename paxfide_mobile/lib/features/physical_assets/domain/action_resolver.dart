import 'asset_action.dart';
import 'lifecycle_status.dart';

/// Resuelve la acción disponible según el estado del ciclo de vida (ADR-043 D2, §9).
/// 
/// IMPORTANTE: ActionResolver NO es autorización (P7).
/// Deriva qué acción mostrar en la interfaz; la autoridad de ejecución
/// reside exclusivamente en el backend.
class ActionResolver {
  const ActionResolver();

  AssetAction resolve(LifecycleStatus status) {
    switch (status) {
      case LifecycleStatus.registered:
        return AssetAction.dispatch;
      case LifecycleStatus.dispatched:
        return AssetAction.receive;
      case LifecycleStatus.received:
        return AssetAction.deliver;
      case LifecycleStatus.delivered:
        return AssetAction.readOnly;
    }
  }
}