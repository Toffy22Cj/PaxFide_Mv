/// Categorías de rutas formalizadas en ADR-043 D8 y front-fase1.md §10.
enum RouteCategory {
  public,
  authTransitory, // /login
  authenticated,
  notApproved, // Rutas desconocidas, parámetros inválidos o fuera de v1 (/campaigns)
}

/// Resultado de clasificar un path contra el árbol aprobado de v1.
class RouteMatch {
  /// Patrón del árbol (p. ej. `/assets/:assetRef`). Vacío si no hay match.
  final String pattern;

  /// Path concreto normalizado (p. ej. `/assets/AS-1`).
  final String path;

  final Map<String, String> params;
  final RouteCategory category;

  const RouteMatch({
    required this.pattern,
    required this.path,
    required this.params,
    required this.category,
  });

  const RouteMatch.notApproved()
      : pattern = '',
        path = '',
        params = const {},
        category = RouteCategory.notApproved;

  bool get isApproved => category != RouteCategory.notApproved;
}

/// Definición y clasificación del árbol de rutas v1 (ADR-043 D8, §9).
///
/// La clasificación compara segmentos exactos: `/assets/a/b`, `/c` o
/// `/home/extra` NO pertenecen al árbol y son No aprobadas.
class AppRoutes {
  AppRoutes._();

  // Rutas Públicas Aprobadas
  static const String campaignPublic = '/c/:publicCode';

  /// Seguimiento SIN código en la URL (ADR-043 §0): el código se escribe a
  /// mano y viaja solo en la cabecera `Authorization`. `/tracking/<x>` es No
  /// aprobada.
  static const String tracking = '/tracking';

  // Ruta de Autenticación (Transitoria)
  static const String login = '/login';

  // Rutas Autenticadas Aprobadas
  static const String home = '/home';
  static const String donations = '/donations';
  static const String operator = '/operator';
  static const String operatorPending = '/operator/pending';
  static const String asset = '/assets/:assetRef';

  // Fuera de v1 (diferida por secuenciación contractual). No pertenece al
  // árbol: se clasifica como No aprobada.
  static const String campaignsDiferido = '/campaigns';

  /// Longitud máxima defensiva de un parámetro (ADR-043 D8). No se inventa
  /// formato de `publicCode` ni `assetRef`.
  static const int maxParamLength = 256;

  /// Validación estructural: no vacío, longitud defensiva y sin `/` (un `/`
  /// codificado como %2F cambiaría la forma del path al reconstruirlo).
  static bool isValidParam(String value) =>
      value.isNotEmpty && value.length <= maxParamLength && !value.contains('/');

  /// Construye el path concreto de un activo.
  static String assetPath(String assetRef) => '/assets/$assetRef';

  /// Clasifica un path (sin esquema ni host) contra el árbol aprobado.
  static RouteMatch match(String path) {
    final Uri uri;
    try {
      uri = Uri.parse(path);
    } on FormatException {
      return const RouteMatch.notApproved();
    }
    if (uri.hasScheme || uri.hasAuthority) {
      // Los paths internos no llevan host; los enlaces externos pasan antes
      // por DeepLinkParser.
      return const RouteMatch.notApproved();
    }
    return matchSegments(uri.pathSegments);
  }

  static RouteMatch matchSegments(List<String> rawSegments) {
    final segments = rawSegments.map((s) => s.trim()).toList();
    if (segments.isEmpty || segments.any((s) => s.isEmpty)) {
      return const RouteMatch.notApproved();
    }

    RouteMatch fixed(String pattern, RouteCategory category) => RouteMatch(
          pattern: pattern,
          path: pattern,
          params: const {},
          category: category,
        );

    RouteMatch withParam(
      String prefix,
      String pattern,
      String paramName,
      String value,
      RouteCategory category,
    ) {
      if (!isValidParam(value)) return const RouteMatch.notApproved();
      return RouteMatch(
        pattern: pattern,
        path: '/$prefix/$value',
        params: {paramName: value},
        category: category,
      );
    }

    if (segments.length == 1) {
      switch (segments[0]) {
        case 'tracking':
          return fixed(tracking, RouteCategory.public);
        case 'login':
          return fixed(login, RouteCategory.authTransitory);
        case 'home':
          return fixed(home, RouteCategory.authenticated);
        case 'donations':
          return fixed(donations, RouteCategory.authenticated);
        case 'operator':
          return fixed(operator, RouteCategory.authenticated);
      }
      return const RouteMatch.notApproved();
    }

    if (segments.length == 2) {
      final head = segments[0];
      final value = segments[1];
      switch (head) {
        case 'c':
          return withParam('c', campaignPublic, 'publicCode', value, RouteCategory.public);
        case 'assets':
          return withParam('assets', asset, 'assetRef', value, RouteCategory.authenticated);
        case 'operator':
          if (value == 'pending') {
            return fixed(operatorPending, RouteCategory.authenticated);
          }
          return const RouteMatch.notApproved();
      }
    }

    return const RouteMatch.notApproved();
  }

  /// Atajo: solo la categoría.
  static RouteCategory categorize(String path) => match(path).category;
}
