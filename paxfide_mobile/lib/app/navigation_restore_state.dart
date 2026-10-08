import 'app_routes.dart';

/// Estado de restauración de navegación formalizado en ADR-043 D7 y §8.
///
/// Solo contiene contexto de navegación estructural, NUNCA verdad de dominio,
/// credenciales, roles, datos del Outbox ni información financiera.
///
/// Persistencia: todavía no implementada (requiere almacenamiento local; ver
/// D12). Esta clase solo define y valida la estructura.
class NavigationRestoreState {
  /// Versión de esquema que esta build sabe leer.
  static const int currentSchemaVersion = 1;

  final String route;
  final Map<String, String> allowedParams;
  final int schemaVersion;

  const NavigationRestoreState({
    required this.route,
    this.allowedParams = const {},
    required this.schemaVersion,
  });

  /// Validación ESTRUCTURAL (§8), nunca de dominio:
  /// - `schemaVersion` compatible con esta build;
  /// - la ruta pertenece al árbol aprobado;
  /// - la ruta no es transitoria (`/login` nunca se restaura);
  /// - los parámetros guardados coinciden con los de la ruta.
  ///
  /// Si devuelve false, el estado se descarta y se aplica el fallback según
  /// la sesión. La Decisión B (descartar rutas autenticadas bajo LOGGED_OUT)
  /// la aplica el guard, no esta clase.
  bool isValid() {
    if (schemaVersion != currentSchemaVersion) return false;

    final match = AppRoutes.match(route);
    if (!match.isApproved) return false;
    if (match.category == RouteCategory.authTransitory) return false;

    for (final entry in allowedParams.entries) {
      if (match.params[entry.key] != entry.value) return false;
    }
    return true;
  }
}
