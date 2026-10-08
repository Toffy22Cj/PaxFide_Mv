/// Estados de la máquina del Outbox formalizados en ADR-043 D6.
/// Incluye AMBIGUOUS para fallos de red no deterministas (Regla 2.6).
enum OutboxStatus {
  pending,
  inFlight,
  ambiguous,
  failed,
  acknowledged,
}