// Lógica del seguimiento, igual que la web (`lib/tracking/tree.ts`, `components/tracking/events.ts`): el árbol de
// lotes y sublotes, el nombre y la descripción de cada evento y cuándo se ve el camión. Sin widgets.

/// Un nodo del árbol de lotes.
class TreeNode<T> {
  TreeNode(this.item);
  final T item;
  final List<TreeNode<T>> children = [];
}

/// El árbol de lotes. Un padre que no está en la lista (o que es el propio lote, o que cerraría un ciclo) hace de
/// raíz: nunca se inventa un padre. Conserva el orden de llegada.
List<TreeNode<T>> buildAssetTree<T>(
  List<T> items, {
  required String Function(T) ref,
  required String? Function(T) parent,
}) {
  final byRef = {for (final i in items) ref(i): i};
  T? parentOf(T i) {
    final pr = parent(i);
    if (pr == null || pr == ref(i)) return null;
    final p = byRef[pr];
    if (p == null) return null;
    final seen = {ref(i)};
    for (T? cur = p; cur != null; cur = parent(cur) == null ? null : byRef[parent(cur)]) {
      if (!seen.add(ref(cur))) return null; // un ciclo (no debería llegar): el que lo cerraría es raíz
    }
    return p;
  }

  final nodes = {for (final i in items) ref(i): TreeNode(i)};
  final roots = <TreeNode<T>>[];
  for (final i in items) {
    final p = parentOf(i);
    if (p != null) {
      nodes[ref(p)]!.children.add(nodes[ref(i)]!);
    } else {
      roots.add(nodes[ref(i)]!);
    }
  }
  return roots;
}

/// Eventos públicos del recorrido de un lote.
enum TrackingEvent {
  registered('ASSET_REGISTERED', 'Registrado', 'El lote quedó registrado con lo que se compró con las donaciones.'),
  dispatched('ASSET_DISPATCHED', 'Despachado', 'El lote salió hacia su destino con un transportista.'),
  received('ASSET_RECEIVED', 'Recibido', 'El lote llegó a una instalación y quedó bajo su custodia.'),
  delivered('ASSET_DELIVERED', 'Entregado', 'El lote se entregó en su destino final. Desde aquí ya no cambia.'),
  split('ASSET_SPLIT', 'Dividido', 'Una parte del lote se separó en un sublote, que sigue su propio recorrido.'),
  splitCompensated(
    'ASSET_SPLIT_COMPENSATED',
    'División revertida',
    'Una división no se completó y se deshizo: la cantidad volvió al lote.',
  ),
  custodyTransferred('ASSET_CUSTODY_TRANSFERRED', 'Cambio de custodio', 'El lote cambió de custodio.'),
  depleted('ASSET_DEPLETED', 'Agotado', 'El lote se repartió por completo en sublotes.');

  const TrackingEvent(this.wire, this.label, this.description);
  final String wire;
  final String label;

  /// Qué significa el paso: solo hechos, nunca quién recibe ni «en camino a X».
  final String description;

  static TrackingEvent? fromWire(String v) => values.where((e) => e.wire == v).firstOrNull;
}

/// Nombre del evento; un literal desconocido se muestra tal cual.
String eventLabel(String wire) => TrackingEvent.fromWire(wire)?.label ?? wire;

/// El camión solo si el último evento del lote es un despacho: no se anima lo que no pasó.
bool showsTruck(List<String> eventTypes) => eventTypes.isNotEmpty && eventTypes.last == TrackingEvent.dispatched.wire;

/// Texto para un paso o un lote sin zona pública. Nunca «en camino a X».
const noPublicZone = 'Sin zona pública';

/// Estado de la donación (`ACTIVA`, `EN_PROCESO`).
String donationStateLabel(String v) => switch (v) {
  'ACTIVA' => 'Activa',
  'EN_PROCESO' => 'En proceso',
  _ => v,
};
