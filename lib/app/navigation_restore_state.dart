import 'dart:convert';

import 'app_routes.dart';

/// Estado de restauración de navegación (ADR-043 D7, front-fase1.md §8).
///
/// Solo contexto de navegación estructural, NUNCA verdad de dominio, credenciales, roles, datos del Outbox,
/// `PendingIntent` ni información financiera. Como el seguimiento no lleva código en la ruta (§0), ninguna
/// ruta restaurable contiene una credencial.
class NavigationRestoreState {
  static const int currentSchemaVersion = 1;

  final String route;
  final Map<String, String> allowedParams;
  final int schemaVersion;

  const NavigationRestoreState({required this.route, this.allowedParams = const {}, required this.schemaVersion});

  /// Validación estructural (§8): versión compatible, ruta del árbol aprobado y restaurable (no transitoria)
  /// y parámetros exactamente los de la ruta. Nunca valida dominio.
  bool isValid() {
    if (schemaVersion != currentSchemaVersion) return false;
    final category = AppRoutes.categorize(route);
    if (category != RouteCategory.public && category != RouteCategory.authenticated) return false;
    final expected = AppRoutes.paramsOf(route);
    if (expected == null || expected.length != allowedParams.length) return false;
    for (final e in expected.entries) {
      if (allowedParams[e.key] != e.value) return false;
    }
    return true;
  }

  RouteCategory get category => AppRoutes.categorize(route);

  String toJson() => jsonEncode({'v': schemaVersion, 'route': route, 'params': allowedParams});

  /// JSON corrupto o con tipos inesperados → `null` (se descarta → fallback según sesión).
  static NavigationRestoreState? tryFromJson(String raw) {
    try {
      final m = jsonDecode(raw);
      if (m is! Map) return null;
      final v = m['v'];
      final route = m['route'];
      final params = m['params'];
      if (v is! int || route is! String || params is! Map) return null;
      return NavigationRestoreState(
        route: route,
        allowedParams: {
          for (final e in params.entries)
            if (e.key is String && e.value is String) e.key as String: e.value as String,
        },
        schemaVersion: v,
      );
    } on FormatException {
      return null;
    }
  }
}
