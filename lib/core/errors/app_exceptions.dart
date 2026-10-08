/// Excepciones del proyecto (ADR-043 D4: error en tres capas; regla 2.6: cada fallo con nombre propio).
///
/// Los mensajes son fijos: nunca incluyen la URL, cabeceras, el cuerpo ni el token de la petición.
abstract class AppException implements Exception {
  final String message;
  const AppException(this.message);

  @override
  String toString() => '$runtimeType: $message';
}

// -------------------------------------------------------------
// Capa 1: transporte
// -------------------------------------------------------------

/// Fallo de transporte. [isAmbiguous] dice si el backend pudo haber recibido la petición.
abstract class TransportException extends AppException {
  const TransportException(super.message);

  /// `true` si no se sabe si el backend ejecutó la petición (regla 2.6). Nunca se clasifica como `FAILED`.
  bool get isAmbiguous;
}

/// Determinista: no se pudo abrir la conexión; la petición **no salió** del dispositivo.
class ConnectionNotEstablishedException extends TransportException {
  const ConnectionNotEstablishedException([super.message = 'No se pudo conectar con el servidor']);

  @override
  bool get isAmbiguous => false;
}

/// Ambiguo: timeout sin respuesta; el backend pudo haber procesado la petición.
class NetworkTimeoutException extends TransportException {
  const NetworkTimeoutException([super.message = 'Tiempo de espera agotado sin respuesta confirmada']);

  @override
  bool get isAmbiguous => true;
}

/// Ambiguo: la conexión se cortó después de enviar la petición.
class ConnectionInterruptedException extends TransportException {
  const ConnectionInterruptedException([super.message = 'La conexión se interrumpió sin respuesta confirmada']);

  @override
  bool get isAmbiguous => true;
}

// -------------------------------------------------------------
// Capa 2: respuestas HTTP de la API (se conserva el código real)
// -------------------------------------------------------------

class ApiHttpException extends AppException {
  final int statusCode;
  const ApiHttpException(this.statusCode, [super.message = 'Respuesta de error del servidor']);

  /// 4xx: rechazo inequívoco del backend.
  bool get isClientError => statusCode >= 400 && statusCode < 500;
}

/// 401 (sujeto a T-1 solo con JWT).
class UnauthorizedException extends ApiHttpException {
  const UnauthorizedException() : super(401, 'Credenciales inválidas o expiradas');
}

/// 403: estado de pantalla, nunca redirect.
class ForbiddenException extends ApiHttpException {
  const ForbiddenException() : super(403, 'Acceso no autorizado para esta operación');
}

/// 404.
class NotFoundException extends ApiHttpException {
  const NotFoundException() : super(404, 'Recurso no encontrado');
}

/// 409: conflicto de estado o de invariante; el cliente no reintenta automáticamente.
class ConflictException extends ApiHttpException {
  const ConflictException() : super(409, 'Conflicto con el estado actual');
}

/// 400 u otro 4xx de validación.
class BadRequestException extends ApiHttpException {
  const BadRequestException([int statusCode = 400]) : super(statusCode, 'Petición no válida');
}

/// 5xx.
class ServerErrorException extends ApiHttpException {
  const ServerErrorException([int statusCode = 500]) : super(statusCode, 'Error interno del servidor');
}

/// Respuesta con cuerpo que no se puede interpretar.
class MalformedResponseException extends AppException {
  const MalformedResponseException() : super('Respuesta del servidor con formato inesperado');
}
