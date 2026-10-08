import '../errors/app_exceptions.dart';
import 'api_client.dart';
import 'api_response.dart';
import 'credential_mode.dart';

/// [ApiClient] de una app compilada sin `PAXFIDE_API_BASE_URL`: ninguna
/// petición sale y cada llamada lanza [ApiNotConfiguredException] (fallo
/// determinista, "no enviado"). No se inventa ningún host.
class UnconfiguredApiClient implements ApiClient {
  const UnconfiguredApiClient();

  @override
  Future<ApiResponse> get(
    String path, {
    Map<String, String>? queryParams,
    Map<String, String>? headers,
    required CredentialMode credentialMode,
  }) async =>
      throw const ApiNotConfiguredException();

  @override
  Future<ApiResponse> post(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    required CredentialMode credentialMode,
    Future<void> Function()? beforeSend,
  }) async =>
      throw const ApiNotConfiguredException();
}
