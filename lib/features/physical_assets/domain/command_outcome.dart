import '../../../core/errors/app_exceptions.dart';
import '../../../core/network/api_response.dart';

/// Resultado de enviar un comando (ADR-043 D6, regla 2.6).
enum CommandOutcome {
  /// 2xx: el backend lo aceptó.
  acknowledged,

  /// Rechazo inequívoco (4xx): no se reintenta con el mismo `Command-Id`.
  failed,

  /// No se sabe si el backend lo ejecutó (timeout, corte tras enviar, 5xx). Nunca se reintenta solo.
  ambiguous,

  /// La petición no llegó a salir (no se pudo conectar): no hubo efecto.
  notSent,
}

/// Clasificación única de respuestas y fallos de transporte.
CommandOutcome classifyResponse(ApiResponse r) {
  if (r.isSuccess) return CommandOutcome.acknowledged;
  if (r.statusCode >= 500) return CommandOutcome.ambiguous; // DDM-17: el servidor pudo haber aplicado el comando
  return CommandOutcome.failed;
}

CommandOutcome classifyTransport(TransportException e) =>
    e.isAmbiguous ? CommandOutcome.ambiguous : CommandOutcome.notSent;
