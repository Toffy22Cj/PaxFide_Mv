import '../domain/principal.dart';
import 'login_gateway.dart';

/// Resultado de consultar `GET /api/v1/me`.
///
/// Cada caso tiene salida propia (regla 2.6): un 401 es T-1; la red o la
/// ausencia de contrato dejan la sesión sin principal, nunca con un rol
/// inventado.
sealed class MeResult {
  const MeResult();
}

class MeSucceeded extends MeResult {
  final Principal principal;
  const MeSucceeded(this.principal);
}

/// 401 con JWT: el token ya no vale.
class MeUnauthorized extends MeResult {
  const MeUnauthorized();
}

/// No se pudo contactar al backend.
class MeNetworkError extends MeResult {
  const MeNetworkError();
}

/// No hay cliente HTTP de `/me` en esta versión.
class MeUnavailable extends MeResult {
  const MeUnavailable();
}

/// Puerto de `/me`. Es la ÚNICA fuente del rol en la app.
abstract class MeGateway {
  Future<MeResult> fetch(String token);
}

/// Implementación por defecto: sin cliente HTTP, no se simula nada.
class UnavailableMeGateway implements MeGateway {
  const UnavailableMeGateway();

  @override
  Future<MeResult> fetch(String token) async => const MeUnavailable();
}

/// `/me` simulado SOLO para desarrollo, junto con el login simulado
/// (`--dart-define=PAXFIDE_FAKE_AUTH=true`).
///
/// Los roles salen de la configuración del build, nunca de la UI:
/// `--dart-define=PAXFIDE_FAKE_ROLES=EMPLOYEE,ADMINISTRATOR`
/// `--dart-define=PAXFIDE_FAKE_ORGANIZATION_ID=org-dev`
/// Sin roles ni organización, la cuenta simulada es donante.
class DevFakeMeGateway implements MeGateway {
  final Principal principal;

  const DevFakeMeGateway(this.principal);

  factory DevFakeMeGateway.fromEnvironment() {
    const rawRoles = String.fromEnvironment('PAXFIDE_FAKE_ROLES');
    const organizationId = String.fromEnvironment('PAXFIDE_FAKE_ORGANIZATION_ID');
    final roles = rawRoles
        .split(',')
        .map((r) => OrgRole.fromApi(r.trim()))
        .whereType<OrgRole>()
        .toSet();
    return DevFakeMeGateway(Principal(
      accountId: 'dev-account',
      organizationId: organizationId.isEmpty ? null : organizationId,
      roles: roles,
    ));
  }

  @override
  Future<MeResult> fetch(String token) async => MeSucceeded(principal);
}

MeGateway defaultMeGateway() =>
    kFakeAuthEnabled ? DevFakeMeGateway.fromEnvironment() : const UnavailableMeGateway();
