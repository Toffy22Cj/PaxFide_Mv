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

/// Credencial de este dispositivo para entrar con biometría (M-28). El `deviceToken` solo llega en el alta.
class DeviceEnrollment {
  const DeviceEnrollment({required this.credentialId, required this.deviceToken});
  final String credentialId;
  final String deviceToken;
}

/// `POST /auth/login`, `POST /auth/register`, `GET /me` y entrar con biometría (referencia-api-v1 §1).
class AuthApi {
  const AuthApi(this._api);

  final ApiClient _api;

  /// Devuelve el JWT. 401 único para email inexistente, contraseña errónea o cuenta inactiva.
  /// Si la cuenta tiene aceptaciones pendientes, el backend responde 403 `AcceptanceRequired`
  /// y se lanza [AcceptanceRequiredException] con las versiones pendientes.
  Future<String> login(
    String email,
    String password, {
    String? acceptedTermsVersion,
    String? acceptedDataPolicyVersion,
  }) async {
    final r = await _api.post(
      '/auth/login',
      body: {
        'email': email,
        'password': password,
        'acceptedTermsVersion': ?acceptedTermsVersion,
        'acceptedDataPolicyVersion': ?acceptedDataPolicyVersion,
      },
      credentialMode: CredentialMode.none,
    );
    if (r.statusCode == 403 && r.data?['title'] == 'AcceptanceRequired') {
      final terms = r.data?['pendingTermsVersion'];
      final dataPolicy = r.data?['pendingDataPolicyVersion'];
      final pendingTerms = terms is String && terms.isNotEmpty ? terms : null;
      final pendingDataPolicy = dataPolicy is String && dataPolicy.isNotEmpty ? dataPolicy : null;
      if (pendingTerms == null && pendingDataPolicy == null) {
        throw const MalformedResponseException();
      }
      throw AcceptanceRequiredException(pendingTermsVersion: pendingTerms, pendingDataPolicyVersion: pendingDataPolicy);
    }
    final token = r.requireData()['token'];
    if (token is! String || token.isEmpty) throw const MalformedResponseException();
    return token;
  }

  /// 201 `{accountId, status}`. Sin `Command-Id` (DD-56). 409 si el email ya existe; 400 si la contraseña es corta
  /// o si falta alguna de las versiones vigentes de términos o política de datos (`acceptedTermsVersion`,
  /// `acceptedDataPolicyVersion`).
  Future<void> register(
    String email,
    String password, {
    required String acceptedTermsVersion,
    required String acceptedDataPolicyVersion,
  }) async {
    final r = await _api.post(
      '/auth/register',
      body: {
        'email': email,
        'password': password,
        'acceptedTermsVersion': acceptedTermsVersion,
        'acceptedDataPolicyVersion': acceptedDataPolicyVersion,
      },
      credentialMode: CredentialMode.none,
    );
    r.requireData();
  }

  /// `POST /auth/password-reset`: solicita un enlace de recuperación de contraseña.
  /// Responde 202 sin cuerpo tanto si la cuenta existe como si no. 400 si el email va vacío.
  Future<void> requestPasswordReset(String email) async {
    final r = await _api.post('/auth/password-reset', body: {'email': email}, credentialMode: CredentialMode.none);
    if (!r.isSuccess) {
      throw r.error ?? BadRequestException(r.statusCode);
    }
  }

  /// `POST /auth/device-credentials` con la sesión iniciada: da de alta este dispositivo para entrar con biometría.
  Future<DeviceEnrollment> enrollDevice({String? deviceName}) async {
    final r = await _api.post(
      '/auth/device-credentials',
      body: {'deviceName': ?deviceName},
      credentialMode: CredentialMode.jwt,
    );
    final j = r.requireData();
    final id = j['credentialId'];
    final token = j['deviceToken'];
    if (id is! String || id.isEmpty || token is! String || token.isEmpty) throw const MalformedResponseException();
    return DeviceEnrollment(credentialId: id, deviceToken: token);
  }

  /// `POST /auth/device-login`: devuelve el JWT, como [login]. El mismo 401 para un token inexistente, revocado o de
  /// una cuenta inactiva.
  Future<String> deviceLogin(String deviceToken) async {
    final r = await _api.post(
      '/auth/device-login',
      body: {'deviceToken': deviceToken},
      credentialMode: CredentialMode.none,
    );
    final token = r.requireData()['token'];
    if (token is! String || token.isEmpty) throw const MalformedResponseException();
    return token;
  }

  Future<MeDto> me() async {
    final r = await _api.get('/me', credentialMode: CredentialMode.jwt);
    return MeDto.fromJson(r.requireData());
  }
}
