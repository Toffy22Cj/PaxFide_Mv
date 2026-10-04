/// Estado de restauración de navegación formalizado en ADR-043 D7 y §8.
/// 
/// Solo contiene contexto de navegación estructural, NUNCA verdad de dominio,
/// credenciales, roles, datos del Outbox ni información financiera.
class NavigationRestoreState {
  final String route;
  final Map<String, String> allowedParams;
  final int schemaVersion;

  const NavigationRestoreState({
    required this.route,
    this.allowedParams = const {},
    required this.schemaVersion,
  });

  /// Validación estructural defensiva (D8, §10): no vacío + longitud defensiva.
  bool isValid() {
    if (route.trim().isEmpty || route.length > 256) return false;
    for (final entry in allowedParams.entries) {
      if (entry.key.isEmpty || entry.value.isEmpty || entry.value.length > 512) {
        return false;
      }
    }
    return true;
  }
}