import '../errors/app_exceptions.dart';

/// Respuesta HTTP de transporte puro (ADR-043 D4). No contiene lógica de dominio.
class ApiResponse {
  final int statusCode;
  final Map<String, dynamic>? data;
  final Map<String, String> headers;

  const ApiResponse({required this.statusCode, this.data, this.headers = const {}});

  bool get isSuccess => statusCode >= 200 && statusCode < 300;

  /// Capa 2 del modelo de error (D4): el código HTTP como excepción con nombre. No interpreta el dominio.
  ApiHttpException? get error {
    if (isSuccess) return null;
    switch (statusCode) {
      case 401:
        return const UnauthorizedException();
      case 403:
        return const ForbiddenException();
      case 404:
        return const NotFoundException();
      case 409:
        return const ConflictException();
    }
    if (statusCode >= 500) return ServerErrorException(statusCode);
    return BadRequestException(statusCode);
  }

  /// Devuelve el cuerpo si es 2xx; si no, lanza la excepción HTTP correspondiente.
  Map<String, dynamic> requireData() {
    final e = error;
    if (e != null) throw e;
    final d = data;
    if (d == null) throw const MalformedResponseException();
    return d;
  }
}
