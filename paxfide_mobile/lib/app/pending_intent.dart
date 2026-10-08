/// Intención de navegación por deep link pendiente de resolver (ADR-043 D9 R2).
///
/// INVARIANTE: vive ÚNICAMENTE en memoria. Desaparece si la app muere, si el
/// login falla o se cancela (DDM-12) o tras consumirse una única vez.
class PendingIntent {
  final String route;
  final Map<String, String> params;

  const PendingIntent({
    required this.route,
    this.params = const {},
  });
}

/// Contenedor en memoria del único [PendingIntent]. Un enlace nuevo reemplaza
/// al anterior.
class PendingIntentHolder {
  PendingIntent? _pending;

  bool get hasPending => _pending != null;

  void set(PendingIntent intent) => _pending = intent;

  void clear() => _pending = null;

  /// Consumo único.
  PendingIntent? take() {
    final p = _pending;
    _pending = null;
    return p;
  }
}
