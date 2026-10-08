import '../../../core/errors/app_exceptions.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/credential_mode.dart';
import '../domain/principal.dart';

/// Motivo de un registro rechazado (referencia-api-v1 §1).
enum RegisterRejection {
  /// 409 `DuplicateEmail`.
  duplicateEmail,

  /// 400: campos vacíos, email mal formado o contraseña de menos de 12
  /// caracteres (`PasswordTooShort`).
  invalidInput,
}

class RegisterRejectedException extends AppException {
  final RegisterRejection reason;
  const RegisterRejectedException(this.reason) : super('Registro rechazado');
}

/// `POST /auth/login`, `POST /auth/register` y `GET /me` (referencia-api-v1 §1).
class AuthApi {
  const AuthApi(this._api);

  final ApiClient _api;

  /// Contraseña mínima que exige el backend.
  static const int minPasswordLength = 12;

  /// Devuelve el JWT. El backend da el mismo 401 para email inexistente,
  /// contraseña errónea o cuenta inactiva.
  Future<String> login(String email, String password) async {
    final r = await _api.post(
      '/auth/login',
      body: {'email': email, 'password': password},
      credentialMode: CredentialMode.none,
    );
    final token = r.requireData()['token'];
    if (token is! String || token.isEmpty) throw const MalformedResponseException();
    return token;
  }

  /// 201 `{accountId, status}`. Sin `Command-Id` (DD-56).
  Future<void> register(String email, String password) async {
    final r = await _api.post(
      '/auth/register',
      body: {'email': email, 'password': password},
      credentialMode: CredentialMode.none,
    );
    if (r.statusCode == 409) throw const RegisterRejectedException(RegisterRejection.duplicateEmail);
    if (r.statusCode == 400) throw const RegisterRejectedException(RegisterRejection.invalidInput);
    r.requireData();
  }

  /// `GET /me` con el JWT guardado. Un 401 lo gestiona T-1 en el cliente HTTP.
  Future<Principal> me() async {
    final r = await _api.get('/me', credentialMode: CredentialMode.jwt);
    try {
      return Principal.fromJson(r.requireData());
    } on FormatException {
      throw const MalformedResponseException();
    }
  }
}
