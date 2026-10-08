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

  /// La predicción se muestra a `ADMINISTRATOR`/`REPRESENTATIVE` con organización (§0 A3).
  bool get showsPrediction =>
      organizationId != null && (roles.contains(administrator) || roles.contains(representative));
}
