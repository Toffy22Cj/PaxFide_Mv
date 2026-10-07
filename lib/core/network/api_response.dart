/// Representa una respuesta HTTP de transporte puro (ADR-043 D4).
/// No contiene lógica de dominio ni asume estructuras de entidades.
class ApiResponse {
  final int statusCode;
  final Map<String, dynamic>? data;
  final Map<String, String> headers;

  const ApiResponse({required this.statusCode, this.data, this.headers = const {}});

  bool get isSuccess => statusCode >= 200 && statusCode < 300;
}
