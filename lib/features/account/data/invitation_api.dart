import '../../../core/network/api_client.dart';
import '../../../core/network/credential_mode.dart';

/// `POST /invitations/accept` (ADR-049 D4): con la sesión y el token **en el cuerpo**, nunca en la URL.
/// 403 uniforme si no se puede aceptar (desconocido, caducado, usado, otro correo); 409 si ya pertenece a otra.
class InvitationApi {
  const InvitationApi(this._api);
  final ApiClient _api;

  Future<void> accept(String token) async {
    final r = await _api.post('/invitations/accept', body: {'token': token}, credentialMode: CredentialMode.jwt);
    r.requireData();
  }
}
