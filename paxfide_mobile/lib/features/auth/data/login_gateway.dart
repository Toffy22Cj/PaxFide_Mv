/// Resultado de un intento de login.
///
/// Distingue rechazo determinista, fallo de red y ausencia de contrato
/// (regla 2.6): cada caso tiene su propio tipo y su propio mensaje en la UI.
sealed class LoginResult {
  const LoginResult();
}

class LoginSucceeded extends LoginResult {
  final String token;
  const LoginSucceeded(this.token);
}

/// El backend rechazó las credenciales (rechazo inequívoco).
class LoginRejected extends LoginResult {
  const LoginRejected();
}

/// No se pudo contactar al backend.
class LoginNetworkError extends LoginResult {
  const LoginNetworkError();
}

/// La app no puede hacer login (compilada sin servidor configurado).
class LoginUnavailable extends LoginResult {
  const LoginUnavailable();
}

/// Puerto de login. Implementación real: `HttpLoginGateway`.
abstract class LoginGateway {
  Future<LoginResult> login({required String email, required String password});
}

/// Sin servidor configurado: no se simula nada.
class UnavailableLoginGateway implements LoginGateway {
  const UnavailableLoginGateway();

  @override
  Future<LoginResult> login({required String email, required String password}) async {
    return const LoginUnavailable();
  }
}

/// Login simulado SOLO para desarrollo.
///
/// Se activa únicamente compilando con
/// `--dart-define=PAXFIDE_FAKE_AUTH=true` (ver [kFakeAuthEnabled]).
/// Acepta cualquier credencial y entrega un token opaco sin significado.
/// No produce roles ni datos de cuenta.
class DevFakeLoginGateway implements LoginGateway {
  final Duration delay;

  const DevFakeLoginGateway({this.delay = const Duration(milliseconds: 500)});

  @override
  Future<LoginResult> login({required String email, required String password}) async {
    await Future<void>.delayed(delay);
    return const LoginSucceeded('dev-fake-token');
  }
}

/// Bandera de build. Falsa por defecto: un build normal nunca usa el login
/// simulado.
const bool kFakeAuthEnabled = bool.fromEnvironment('PAXFIDE_FAKE_AUTH');
