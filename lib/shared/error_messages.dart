import '../core/errors/app_exceptions.dart';

/// Mensaje para el usuario. Nunca incluye datos de la petición (URL, tokens, cuerpos).
String describeError(Object error) {
  if (error is ConnectionNotEstablishedException) return 'Sin conexión con el servidor. No se envió nada.';
  if (error is TransportException) return 'No pudimos confirmar la respuesta del servidor.';
  if (error is UnauthorizedException) return 'Tu sesión no es válida. Vuelve a entrar.';
  if (error is ForbiddenException) return 'Tu cuenta no tiene acceso a esto.';
  if (error is NotFoundException) return 'No lo encontramos.';
  if (error is ConflictException) return 'El servidor rechazó la operación por el estado actual.';
  if (error is ServerErrorException) return 'El servidor tuvo un error.';
  if (error is ApiHttpException) return 'El servidor rechazó la petición.';
  if (error is MalformedResponseException) return 'Respuesta inesperada del servidor.';
  return 'Ocurrió un error inesperado.';
}
