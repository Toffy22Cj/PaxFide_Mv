/// Clase base para todas las excepciones del proyecto PaxFide.
abstract class AppException implements Exception {
  final String message;
  const AppException(this.message);

  @override
  String toString() => '$runtimeType: $message';
}

// -------------------------------------------------------------
// Capa 1: Fallos de Transporte / Red (ADR-043 D4)
// -------------------------------------------------------------

/// Fallo ambiguo: timeout donde no se sabe si backend procesó (Regla 2.6).
class NetworkTimeoutException extends AppException {
  const NetworkTimeoutException([super.message = 'Timeout de conexión sin respuesta confirmada']);
}

/// Fallo determinista de conexión (ej. sin interfaz de red activa).
class NetworkConnectionException extends AppException {
  const NetworkConnectionException([super.message = 'Fallo de conexión o red inaccesible']);
}

// -------------------------------------------------------------
// Capa 2: Respuestas HTTP de la API (ADR-043 D3, D4)
// -------------------------------------------------------------

/// Respuesta 401 Unauthorized (sujeto a regla T-1 en JWT o tracking).
class UnauthorizedException extends AppException {
  final int statusCode;
  const UnauthorizedException([super.message = 'Credenciales inválidas o expiradas'])
      : statusCode = 401;
}

/// Respuesta 403 Forbidden (estado de pantalla, nunca redirect).
class ForbiddenException extends AppException {
  final int statusCode;
  const ForbiddenException([super.message = 'Acceso no autorizado para esta operación'])
      : statusCode = 403;
}

/// Respuesta 404 Not Found (recurso no existente).
class NotFoundException extends AppException {
  final int statusCode;
  const NotFoundException([super.message = 'Recurso no encontrado'])
      : statusCode = 404;
}

/// Error determinista devuelto por backend (4xx de validación o rechazo inequívoco).
class BadRequestException extends AppException {
  final int statusCode;
  const BadRequestException(super.message)
      : statusCode = 400;
}

/// Error del servidor (5xx).
class ServerErrorException extends AppException {
  final int statusCode;
  const ServerErrorException([super.message = 'Error interno del servidor'])
      : statusCode = 500;
}