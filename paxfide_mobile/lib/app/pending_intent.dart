/// Representa una intención de navegación por Deep Link pendiente de resolver (ADR-043 D9 R2).
/// 
/// INVARIANTE: Vive ÚNICAMENTE en memoria. Desaparece si la app muere,
/// si el login se cancela o tras consumirse una única vez.
class PendingIntent {
  final String route;
  final Map<String, String> params;

  const PendingIntent({
    required this.route,
    this.params = const {},
  });
}