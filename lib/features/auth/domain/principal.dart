import '../data/auth_api.dart';

/// Lo que `GET /me` dice de la cuenta, para **representar** la interfaz (ADR-043 D3, §0).
///
/// Vive solo en memoria junto a la sesión; nunca se persiste ni sale del JWT. No es autorización: el backend
/// autoriza cada petición (P7).
class Principal {
  const Principal({required this.accountId, this.organizationId, required this.roles, this.platformAuthority});

  factory Principal.fromMe(MeDto me) => Principal(
    accountId: me.accountId,
    organizationId: me.organizationId,
    roles: Set.unmodifiable(me.roles),
    platformAuthority: me.platformAuthority,
  );

  static const employee = 'EMPLOYEE';
  static const administrator = 'ADMINISTRATOR';
  static const representative = 'REPRESENTATIVE';

  final String accountId;
  final String? organizationId;
  final Set<String> roles;
  final String? platformAuthority;

  /// Las acciones del operador se muestran solo a `EMPLOYEE` (encargo §4.3).
  bool get showsOperatorActions => roles.contains(employee);

  /// Enmienda 6 de ADR-043 (E6-2), con las reglas del backend: fondos mensuales, `ADMINISTRATOR` o `EMPLOYEE` (DD-31).
  bool get showsFundsData => organizationId != null && (roles.contains(administrator) || roles.contains(employee));

  /// Actividad: `ADMINISTRATOR`, `REPRESENTATIVE` o `EMPLOYEE` (D-R6-8). Quien no tiene organización (el donante) no ve nada.
  bool get showsActivityData =>
      organizationId != null &&
      (roles.contains(administrator) || roles.contains(representative) || roles.contains(employee));

  /// «Datos de la organización»: la pantalla se ofrece si se ve al menos uno de los dos paneles.
  bool get showsOrganizationData => showsFundsData || showsActivityData;

  /// E6-3: el selector del tipo de gráfico, solo `ADMINISTRATOR` y `EMPLOYEE`; el `REPRESENTATIVE` ve el predeterminado.
  bool get choosesOrganizationCharts => roles.contains(administrator) || roles.contains(employee);

  /// La predicción se muestra a `ADMINISTRATOR`/`REPRESENTATIVE` con organización (§0 A3).
  bool get showsPrediction =>
      organizationId != null && (roles.contains(administrator) || roles.contains(representative));
}
