import 'app_routes.dart';

/// Resultado del parseo de un deep link entrante (ADR-043 D9).
class ParsedDeepLink {
  final String route;
  final Map<String, String> parameters;
  final RouteCategory category;

  const ParsedDeepLink({
    required this.route,
    required this.parameters,
    required this.category,
  });

  /// Enlace estructuralmente inválido o no reconocido (R5).
  const ParsedDeepLink.unapproved()
      : route = '',
        parameters = const {},
        category = RouteCategory.notApproved;

  bool get isApproved => category != RouteCategory.notApproved;
}

/// Único parser para enlaces externos y del escáner interno (ADR-043 D9 R1).
///
/// Invariante R3: no ejecuta comandos, no genera commandId ni crea entradas
/// en el Outbox. Es una función pura de [Uri] a [ParsedDeepLink].
///
/// Hosts (R5): el host canónico NO está fijado (infraestructura de enlaces
/// pendiente, ADR-043 §5). Por eso la lista de hosts permitidos se inyecta y
/// está vacía por defecto: mientras nadie la configure, todo enlace externo
/// con host se trata como No aprobado. Un path sin esquema ni host (escáner
/// interno o navegación de la app) se clasifica directamente.
class DeepLinkParser {
  final Set<String> allowedHosts;

  const DeepLinkParser({this.allowedHosts = const {}});

  ParsedDeepLink parse(Uri uri) {
    if (uri.hasAuthority || uri.hasScheme) {
      final host = uri.host.toLowerCase();
      if (uri.scheme != 'https' || host.isEmpty || !allowedHosts.contains(host)) {
        return const ParsedDeepLink.unapproved();
      }
    }

    final match = AppRoutes.matchSegments(uri.pathSegments);
    if (!match.isApproved) {
      return const ParsedDeepLink.unapproved();
    }
    return ParsedDeepLink(
      route: match.path,
      parameters: match.params,
      category: match.category,
    );
  }
}
