import '../../../core/errors/app_exceptions.dart';
import 'auth_api.dart';
import 'login_gateway.dart';
import 'me_gateway.dart';

/// [LoginGateway] contra `POST /auth/login`.
class HttpLoginGateway implements LoginGateway {
  const HttpLoginGateway(this._api);
  final AuthApi _api;

  @override
  Future<LoginResult> login({required String email, required String password}) async {
    try {
      return LoginSucceeded(await _api.login(email, password));
    } on ApiNotConfiguredException {
      return const LoginUnavailable();
    } on TransportException {
      return const LoginNetworkError();
    } on ApiHttpException catch (e) {
      // 401 (credenciales) y 400 (campos) son rechazos inequívocos; un 5xx
      // no dice nada de las credenciales.
      return e.isClientError ? const LoginRejected() : const LoginNetworkError();
    } on MalformedResponseException {
      return const LoginNetworkError();
    }
  }
}

/// [MeGateway] contra `GET /me`. El token ya está en el `TokenStore`: el
/// cliente HTTP lo añade con `CredentialMode.jwt`.
class HttpMeGateway implements MeGateway {
  const HttpMeGateway(this._api);
  final AuthApi _api;

  @override
  Future<MeResult> fetch(String token) async {
    try {
      return MeSucceeded(await _api.me());
    } on UnauthorizedException {
      return const MeUnauthorized();
    } on ApiNotConfiguredException {
      return const MeUnavailable();
    } on AppException {
      return const MeNetworkError();
    }
  }
}
