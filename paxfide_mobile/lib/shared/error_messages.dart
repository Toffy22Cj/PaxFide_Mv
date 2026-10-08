import '../core/errors/app_exceptions.dart';

/// Mensaje para el usuario. Nunca incluye datos de la petición (URL, tokens, cuerpos).
String describeError(Object error) {
  if (error is ApiNotConfiguredException) {
    return 'La app no está conectada a ningún servidor.';
  }
  if (error is ConnectionNotEstablishedException) return 'Sin conexión. Revisa tu internet e inténtalo de nuevo.';
  if (error is TransportException) return 'Se cortó la conexión. Inténtalo de nuevo.';
  if (error is UnauthorizedException) return 'Tu sesión terminó. Vuelve a entrar.';
  if (error is ForbiddenException) return 'Tu cuenta no tiene acceso a esto.';
  if (error is NotFoundException) return 'No lo encontramos.';
  if (error is ConflictException) return 'No se pudo hacer: algo cambió mientras tanto. Actualiza e inténtalo de nuevo.';
  if (error is ServerErrorException) return 'Algo falló de nuestro lado. Inténtalo en unos minutos.';
  if (error is ApiHttpException) return 'No se pudo completar. Revisa los datos.';
  if (error is MalformedResponseException) return 'Algo falló de nuestro lado. Inténtalo en unos minutos.';
  return 'Ocurrió un error inesperado.';
}
