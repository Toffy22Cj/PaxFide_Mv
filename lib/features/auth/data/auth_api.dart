import '../../../core/errors/app_exceptions.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/credential_mode.dart';

/// Respuesta de `GET /api/v1/me` (ficha N1): exactamente estos cuatro campos.
class MeDto {
  const MeDto({required this.accountId, this.organizationId, required this.roles, this.platformAuthority});

  final String accountId;
  final String? organizationId;
  final List<String> roles;
  final String? platformAuthority;

  static MeDto fromJson(Map<String, dynamic> j) {
    final id = j['accountId'];
    final roles = j['roles'];
    if (id is! String || id.isEmpty || roles is! List) throw const MalformedResponseException();
    return MeDto(
      accountId: id,
      organizationId: j['organizationId'] is String ? j['organizationId'] as String : null,
      roles: [
        for (final r in roles)
          if (r is String) r,
      ],
      platformAuthority: j['platformAuthority'] is String ? j['platformAuthority'] as String : null,
    );
  }
}

/// `POST /auth/login`, `POST /auth/register` y `GET /me` (referencia-api-v1 §1).
class AuthApi {
  const AuthApi(this._api);

  final ApiClient _api;

  /// Devuelve el JWT. 401 único para email inexistente, contraseña errónea o cuenta inactiva.
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

  /// 201 `{accountId, status}`. Sin `Command-Id` (DD-56). 409 si el email ya existe.
  Future<void> register(String email, String password) async {
    final r = await _api.post(
      '/auth/register',
      body: {'email': email, 'password': password},
      credentialMode: CredentialMode.none,
    );
    r.requireData();
  }

  Future<MeDto> me() async {
    final r = await _api.get('/me', credentialMode: CredentialMode.jwt);
    return MeDto.fromJson(r.requireData());
  }
}
