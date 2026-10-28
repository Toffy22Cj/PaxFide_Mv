import '../../../core/errors/app_exceptions.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/network/credential_mode.dart';

/// 400 `CurrentPasswordIncorrect` de cambiar la contraseña o desactivar la cuenta (ADR-050 D5 y D6). Nunca 401:
/// no toca la sesión (T-1).
class CurrentPasswordIncorrectException extends ApiHttpException {
  const CurrentPasswordIncorrectException() : super(400, 'La contraseña actual no es correcta');
}

/// 400 `PasswordTooShort`: la contraseña nueva tiene menos de 12 caracteres.
class NewPasswordTooShortException extends ApiHttpException {
  const NewPasswordTooShortException() : super(400, 'La contraseña nueva es demasiado corta');
}

/// 409 de `POST /account/deactivate` (ADR-050 D6): la cuenta no se puede desactivar y sigue `ACTIVE`.
/// [reason] es el `title` del backend: `PlatformAdministratorDeactivation`, `RepresentativeTransferRequired` o
/// `ActiveCampaignResponsible`.
class DeactivationBlockedException extends ApiHttpException {
  const DeactivationBlockedException(this.reason) : super(409, 'La cuenta no se puede desactivar');
  final String reason;
}

/// `GET /account/profile`: el correo y el nombre de la propia cuenta. El nombre es privado (ADR-050 D1).
class AccountProfile {
  const AccountProfile({required this.email, this.givenName, this.familyName});
  final String email;
  final String? givenName;
  final String? familyName;

  /// "Nombre Apellido", o null si no hay ninguno de los dos.
  String? get fullName {
    final parts = [givenName, familyName].whereType<String>().where((p) => p.isNotEmpty);
    return parts.isEmpty ? null : parts.join(' ');
  }
}

/// La propia cuenta (referencia-api-v1 §1, ADR-050): perfil, contraseña y desactivación. Todo con la sesión y sin
/// `Command-Id`. Nunca registra correos ni contraseñas.
class AccountApi {
  const AccountApi(this._api);
  final ApiClient _api;

  /// Longitud máxima de cada parte del nombre, en puntos de código (ADR-050 D1).
  static const maxNameLength = 100;

  static String? _title(ApiResponse r) => r.data?['title'] is String ? r.data!['title'] as String : null;

  static AccountProfile _profile(Map<String, dynamic> j) {
    final email = j['email'];
    if (email is! String || email.isEmpty) throw const MalformedResponseException();
    String? opt(String k) => j[k] is String && (j[k] as String).isNotEmpty ? j[k] as String : null;
    return AccountProfile(email: email, givenName: opt('givenName'), familyName: opt('familyName'));
  }

  Future<AccountProfile> profile() async =>
      _profile((await _api.get('/account/profile', credentialMode: CredentialMode.jwt)).requireData());

  /// `PUT /account/profile`. Se recortan los espacios; vacío o null **borra** el campo. 400 si una parte pasa de
  /// [maxNameLength] puntos de código.
  Future<AccountProfile> updateProfile({String? givenName, String? familyName}) async {
    String? clean(String? v) => v == null || v.trim().isEmpty ? null : v.trim();
    final r = await _api.put(
      '/account/profile',
      body: {'givenName': clean(givenName), 'familyName': clean(familyName)},
      credentialMode: CredentialMode.jwt,
    );
    return _profile(r.requireData());
  }

  /// `POST /account/password` → el token nuevo. La sesión actual sigue con él y las demás quedan revocadas.
  /// Errores con nombre: [CurrentPasswordIncorrectException] (gana si las dos cosas fallan) y
  /// [NewPasswordTooShortException]. Un 500 puede significar que la contraseña **sí** cambió y todas las sesiones
  /// se revocaron (ADR-038 #7): quien llama debe llevar a iniciar sesión otra vez.
  Future<String> changePassword({required String currentPassword, required String newPassword}) async {
    final r = await _api.post(
      '/account/password',
      body: {'currentPassword': currentPassword, 'newPassword': newPassword},
      credentialMode: CredentialMode.jwt,
    );
    if (r.statusCode == 400) {
      switch (_title(r)) {
        case 'CurrentPasswordIncorrect':
          throw const CurrentPasswordIncorrectException();
        case 'PasswordTooShort':
          throw const NewPasswordTooShortException();
      }
    }
    final token = r.requireData()['token'];
    if (token is! String || token.isEmpty) throw const MalformedResponseException();
    return token;
  }

  /// `POST /account/deactivate` → 204. La cuenta pasa a `INACTIVE` y **todos** sus tokens quedan revocados, también
  /// el de esta petición: quien llama cierra la sesión. No se puede deshacer desde la app.
  Future<void> deactivate({required String currentPassword}) async {
    final r = await _api.post(
      '/account/deactivate',
      body: {'currentPassword': currentPassword},
      credentialMode: CredentialMode.jwt,
    );
    if (r.isSuccess) return;
    if (r.statusCode == 400 && _title(r) == 'CurrentPasswordIncorrect') {
      throw const CurrentPasswordIncorrectException();
    }
    if (r.statusCode == 409) throw DeactivationBlockedException(_title(r) ?? '');
    throw r.error!;
  }
}
