/// Categorías de rutas formalizadas en ADR-043 D8 y front-fase1.md §10.
enum RouteCategory {
  public,
  authTransitory, // /login
  authenticated,
  notApproved,    // Rutas no aprobadas, desconocidas o fuera de v1 (/campaigns)
}

/// Definición y clasificación del árbol de rutas v1 (ADR-043 D8, §9).
class AppRoutes {
  // Rutas Públicas Aprobadas
  static const String campaignPublic = '/c/:publicCode';
  static const String tracking = '/tracking/:trackingCode';

  // Ruta de Autenticación (Transitoria)
  static const String login = '/login';

  // Rutas Autenticadas Aprobadas
  static const String home = '/home';
  static const String donations = '/donations';
  static const String operator = '/operator';
  static const String operatorPending = '/operator/pending';
  static const String asset = '/assets/:assetRef';

  // Rutas fuera de v1 (diferidas por secuenciación contractual)
  static const String campaignsDiferido = '/campaigns';

  /// Clasifica una ruta en su categoría correspondiente.
  static RouteCategory categorize(String path) {
    if (path.startsWith('/c/') || path.startsWith('/tracking/')) {
      return RouteCategory.public;
    }
    if (path == login) {
      return RouteCategory.authTransitory;
    }
    if (path == home ||
        path == donations ||
        path == operator ||
        path == operatorPending ||
        path.startsWith('/assets/')) {
      return RouteCategory.authenticated;
    }
    // /campaigns y cualquier ruta desconocida caen como no aprobadas en v1
    return RouteCategory.notApproved;
  }
}