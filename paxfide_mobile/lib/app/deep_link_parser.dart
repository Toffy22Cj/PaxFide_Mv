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
/// Hosts (R5): el host canónico no está fijado en el código. Se configura al
/// compilar (`PAXFIDE_PUBLIC_BASE_URL`, DDM-03) con [DeepLinkParser.forOrigin].
/// Sin origen configurado, todo enlace con host es No aprobado. Un path sin
/// esquema ni host (navegación interna) se clasifica directamente.
class DeepLinkParser {
  final Set<String> allowedHosts;
  final Set<String> allowedSchemes;

  /// Puerto exigido (el del origen configurado); null = el del esquema.
  final int? requiredPort;

  const DeepLinkParser({
    this.allowedHosts = const {},
    this.allowedSchemes = const {'https'},
    this.requiredPort,
  });

  /// Acepta solo enlaces del origen [origin] (esquema, host y puerto).
  factory DeepLinkParser.forOrigin(Uri? origin) {
    if (origin == null) return const DeepLinkParser();
    return DeepLinkParser(
      allowedHosts: {origin.host.toLowerCase()},
      allowedSchemes: {origin.scheme},
      requiredPort: origin.hasPort ? origin.port : null,
    );
  }

  ParsedDeepLink parse(Uri uri) {
    if (uri.hasAuthority || uri.hasScheme) {
      final host = uri.host.toLowerCase();
      if (!allowedSchemes.contains(uri.scheme) || host.isEmpty || !allowedHosts.contains(host)) {
        return const ParsedDeepLink.unapproved();
      }
      if (requiredPort != null && uri.port != requiredPort) {
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

  /// Texto leído por el escáner o pegado a mano.
  ParsedDeepLink parseText(String raw) {
    final uri = Uri.tryParse(raw.trim());
    return uri == null ? const ParsedDeepLink.unapproved() : parse(uri);
  }
}
