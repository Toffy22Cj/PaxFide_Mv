/// Intención de navegación por deep link pendiente de login (ADR-043 D9 R2).
///
/// INVARIANTE: vive ÚNICAMENTE en memoria. Desaparece si la app muere, si el login se cancela o fracasa, o tras
/// consumirse una única vez. Un deep link nuevo la reemplaza.
class PendingIntent {
  final String route;
  final Map<String, String> params;

  const PendingIntent({required this.route, this.params = const {}});
}

/// Contenedor en memoria de la única [PendingIntent] (R2). No tiene ni puede tener persistencia.
class PendingIntentHolder {
  PendingIntent? _current;

  PendingIntent? get current => _current;

  /// Registra la intención; reemplaza la anterior.
  void retain(PendingIntent intent) => _current = intent;

  /// Consumo único: devuelve la intención y la borra.
  PendingIntent? consume() {
    final i = _current;
    _current = null;
    return i;
  }

  /// Login cancelado o fallido.
  void discard() => _current = null;
}
