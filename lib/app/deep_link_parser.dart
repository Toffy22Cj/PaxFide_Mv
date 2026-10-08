import 'app_routes.dart';

/// Resultado del parseo de un deep link entrante (ADR-043 D9).
class ParsedDeepLink {
  final String route;
  final Map<String, String> parameters;
  final RouteCategory category;

  const ParsedDeepLink({required this.route, required this.parameters, required this.category});

  /// Enlace estructuralmente inválido o no reconocido (R5).
  const ParsedDeepLink.unapproved() : route = '', parameters = const {}, category = RouteCategory.notApproved;

  bool get isApproved => category != RouteCategory.notApproved;

  @override
  String toString() => 'ParsedDeepLink($route, $category)';
}

/// Único parser para enlaces externos y del escáner interno (ADR-043 D9 R1).
///
/// - Solo aprueba los tres payloads de QR (matriz §4b): `/assets/{assetRef}`, `/c/{publicCode}` y
///   el de seguimiento. Cualquier otra ruta, aunque exista en el árbol, no es un payload: No aprobada.
/// - R5: el esquema y el host deben coincidir con el origen canónico configurado (DDM-03). Sin origen
///   configurado no se aprueba ningún enlace.
/// - Seguimiento: el enlace abre `/tracking` **sin** el código. El código se descarta aquí y nunca llega a
///   una ruta, a `NavigationRestoreState` ni a un log (decisión de la web, ADR-043 §0).
/// - R3: no ejecuta comandos, no genera `commandId` ni crea entradas en el Outbox.
class DeepLinkParser {
  const DeepLinkParser({required this.canonicalOrigin});

  /// Esquema + host (+ puerto) canónicos. `null` = no configurado.
  final Uri? canonicalOrigin;

  /// Para el texto leído por el escáner: si no es una URI, es No aprobada.
  ParsedDeepLink parseText(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || raw.trim().isEmpty) return const ParsedDeepLink.unapproved();
    return parse(uri);
  }

  ParsedDeepLink parse(Uri uri) {
    final origin = canonicalOrigin;
    if (origin == null) return const ParsedDeepLink.unapproved();
    if (uri.scheme != origin.scheme || uri.host != origin.host || uri.port != origin.port) {
      return const ParsedDeepLink.unapproved();
    }
    if (uri.hasQuery || uri.hasFragment) return const ParsedDeepLink.unapproved();

    final segments = uri.pathSegments;

    // Seguimiento: `/tracking` o `/tracking/{código}` → `/tracking`, sin el código.
    if (segments.isNotEmpty && segments.first == 'tracking' && segments.length <= 2) {
      return const ParsedDeepLink(route: AppRoutes.tracking, parameters: {}, category: RouteCategory.public);
    }

    if (segments.length != 2) return const ParsedDeepLink.unapproved();
    final value = segments[1];
    if (!AppRoutes.isValidParam(value)) return const ParsedDeepLink.unapproved();

    switch (segments[0]) {
      case 'c':
        return ParsedDeepLink(
          route: AppRoutes.campaignPath(value),
          parameters: {'publicCode': value},
          category: RouteCategory.public,
        );
      case 'assets':
        return ParsedDeepLink(
          route: AppRoutes.assetPath(value),
          parameters: {'assetRef': value},
          category: RouteCategory.authenticated,
        );
    }
    return const ParsedDeepLink.unapproved();
  }
}
