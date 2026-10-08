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

  Future<ApiResponse> post(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    required CredentialMode credentialMode,
  });
}