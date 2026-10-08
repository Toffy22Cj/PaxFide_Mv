/// Rol de una cuenta dentro de su organización, tal como lo devuelve
/// `GET /api/v1/me` (ADR-038, ADR-043 §0).
enum OrgRole {
  administrator('ADMINISTRATOR'),
  representative('REPRESENTATIVE'),
  employee('EMPLOYEE');

  final String apiValue;
  const OrgRole(this.apiValue);

  /// Valor del backend → rol. Un valor desconocido devuelve null: quien
  /// parsea decide ignorarlo; nunca se convierte en otro rol por defecto.
  static OrgRole? fromApi(String value) {
    for (final role in OrgRole.values) {
      if (role.apiValue == value) return role;
    }
    return null;
  }
}

/// Quién es la cuenta autenticada: respuesta de `GET /api/v1/me`
/// (`{accountId, organizationId?, roles, platformAuthority?}`).
///
/// INVARIANTES (ADR-043 §0, D3):
/// - Vive solo en memoria, dentro de la sesión. Nunca se persiste ni entra en
///   `NavigationRestoreState`.
/// - Nunca se obtiene decodificando el JWT ni se elige en la UI.
/// - Solo decide qué se MUESTRA; el backend autoriza cada petición (P7).
class Principal {
  final String accountId;
  final String? organizationId;
  final Set<OrgRole> roles;
  final String? platformAuthority;

  const Principal({
    required this.accountId,
    this.organizationId,
    this.roles = const {},
    this.platformAuthority,
  });

  /// Cuenta sin organización: donante.
  bool get isDonor => organizationId == null;

  /// Operador de campo: ve las acciones sobre activos físicos.
  bool get isFieldOperator => roles.contains(OrgRole.employee);

  /// La predicción es la única pantalla visible para administración en el
  /// móvil (ADR-043 §0, A3).
  bool get canSeePrediction =>
      roles.contains(OrgRole.administrator) || roles.contains(OrgRole.representative);

  /// Construye el principal desde el cuerpo de `/me`. Lanza
  /// [FormatException] si falta `accountId` o `roles` no es una lista.
  factory Principal.fromJson(Map<String, dynamic> json) {
    final accountId = json['accountId'];
    if (accountId is! String || accountId.isEmpty) {
      throw const FormatException('/me sin accountId');
    }
    final rawRoles = json['roles'] ?? const <dynamic>[];
    if (rawRoles is! List) {
      throw const FormatException('/me con roles que no son una lista');
    }
    final roles = <OrgRole>{};
    for (final raw in rawRoles) {
      final role = raw is String ? OrgRole.fromApi(raw) : null;
      if (role != null) roles.add(role);
    }
    final organizationId = json['organizationId'];
    final platformAuthority = json['platformAuthority'];
    return Principal(
      accountId: accountId,
      organizationId: organizationId is String ? organizationId : null,
      roles: roles,
      platformAuthority: platformAuthority is String ? platformAuthority : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Principal &&
          accountId == other.accountId &&
          organizationId == other.organizationId &&
          platformAuthority == other.platformAuthority &&
          roles.length == other.roles.length &&
          roles.containsAll(other.roles);

  @override
  int get hashCode => Object.hash(
        accountId,
        organizationId,
        platformAuthority,
        Object.hashAllUnordered(roles),
      );
}
