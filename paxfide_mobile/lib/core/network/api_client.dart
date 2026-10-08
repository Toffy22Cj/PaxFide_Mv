import 'api_response.dart';
import 'credential_mode.dart';

/// Contrato abstracto de transporte de red HTTP puro (ADR-043 D4).
///
/// INVARIANTES:
/// - No conoce tipos de dominio.
/// - No genera commandId.
/// - No decide autorización.
/// - Delega la gestión de credenciales según el CredentialMode indicado.
abstract class ApiClient {
  Future<ApiResponse> get(
    String path, {
    Map<String, String>? queryParams,
    Map<String, String>? headers,
    required CredentialMode credentialMode,
  });

  /// [beforeSend] se invoca con la conexión ya abierta, justo antes de escribir la petición. Si la conexión no
  /// se puede abrir, no se invoca y la petición no sale (fallo determinista). Lo usa el Outbox para pasar a
  /// `IN_FLIGHT` solo cuando la petición sale de verdad (ADR-043 D6).
  Future<ApiResponse> post(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    required CredentialMode credentialMode,
    Future<void> Function()? beforeSend,
  });
}
