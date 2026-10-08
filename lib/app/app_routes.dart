/// Categorías de rutas formalizadas en ADR-043 D8 y front-fase1.md §10.
enum RouteCategory {
  public,
  authTransitory, // /login, /register
  authenticated,
  notApproved, // Rutas no aprobadas, desconocidas o fuera de v1 (/campaigns)
}

/// Árbol de rutas v1 (ADR-043 D8 con la §0 de 2026-10-07).
///
/// Cambios respecto a front-fase1.md §9:
/// - `/tracking` sin parámetro: el código de seguimiento nunca va en una URL.
/// - `/register` (transitoria de auth): el registro de cuenta ya existe (D10 actualizado).
/// - `/prediction` (autenticada): excepción de alcance de la §0 A3.
class AppRoutes {
  // Rutas públicas aprobadas
  static const String campaignPublic = '/c/:publicCode';
  static const String tracking = '/tracking';

  // Transitorias de autenticación (nunca restaurables)
  static const String login = '/login';
  static const String register = '/register';

  // Rutas autenticadas aprobadas
  static const String home = '/home';
  static const String donations = '/donations';
  static const String operator = '/operator';
  static const String operatorPending = '/operator/pending';
  static const String asset = '/assets/:assetRef';
  static const String prediction = '/prediction';

  // Fuera de v1 (diferida por secuenciación contractual, §9)
  static const String campaignsDiferido = '/campaigns';

  /// Longitud máxima defensiva de un parámetro (§10: no se inventa formato).
  static const int maxParamLength = 256;

  static const _fixedAuthenticated = {home, donations, operator, operatorPending, prediction};

  static String campaignPath(String publicCode) => '/c/$publicCode';
  static String assetPath(String assetRef) => '/assets/$assetRef';

  /// Validación estructural de un parámetro: no vacío, sin espacios, sin '/', longitud máxima.
  static bool isValidParam(String value) =>
      value.isNotEmpty &&
      value.length <= maxParamLength &&
      !value.contains('/') &&
      value.trim() == value &&
      !value.contains(RegExp(r'\s'));

  /// Parámetros que una ruta concreta admite (y solo esos). `null` si la ruta no es del árbol.
  static Map<String, String>? paramsOf(String path) {
    if (path == tracking || path == login || path == register || _fixedAuthenticated.contains(path)) {
      return const {};
    }
    final segments = path.split('/');
    // '/c/X' → ['', 'c', 'X']
    if (segments.length == 3 && segments[0].isEmpty) {
      final value = Uri.decodeComponent(segments[2]);
      if (!isValidParam(value)) return null;
      if (segments[1] == 'c') return {'publicCode': value};
      if (segments[1] == 'assets') return {'assetRef': value};
    }
    return null;
  }

  /// Clasifica una ruta según su forma exacta. Cualquier otra cosa es No aprobada.
  static RouteCategory categorize(String path) {
    final params = _safeParams(path);
    if (params == null) return RouteCategory.notApproved;
    if (path == tracking || path.startsWith('/c/')) return RouteCategory.public;
    if (path == login || path == register) return RouteCategory.authTransitory;
    return RouteCategory.authenticated;
  }

  static Map<String, String>? _safeParams(String path) {
    try {
      return paramsOf(path);
    } on ArgumentError {
      return null; // escape % mal formado
    } on FormatException {
      return null;
    }
  }
}
