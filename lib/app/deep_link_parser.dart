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

  /// Representa un enlace estructuralmente inválido o no reconocido (R5).
  const ParsedDeepLink.unapproved()
      : route = '',
        parameters = const {},
        category = RouteCategory.notApproved;
}

/// Único parser para enlaces externos y del escáner interno (ADR-043 D9 R1).
///
/// Invariante R3: Este parser no ejecuta comandos, no genera commandId
/// ni crea entradas en el Outbox.
class DeepLinkParser {
  const DeepLinkParser();

  ParsedDeepLink parse(Uri uri) {
    final pathSegments = uri.pathSegments;

    // Validación estructural básica: no vacío y longitud defensiva (D8, D9 R5)
    if (pathSegments.isEmpty) {
      return const ParsedDeepLink.unapproved();
    }

    // Caso 1: /c/:publicCode (Campaña pública)
    if (pathSegments.length == 2 && pathSegments[0] == 'c') {
      final code = pathSegments[1].trim();
      if (_isValidParam(code)) {
        return ParsedDeepLink(
          route: '/c/$code',
          parameters: {'publicCode': code},
          category: RouteCategory.public,
        );
      }
    }

    // Caso 2: /tracking/:trackingCode (Tracking público - credencial bearer)
    if (pathSegments.length == 2 && pathSegments[0] == 'tracking') {
      final tracking = pathSegments[1].trim();
      if (_isValidParam(tracking)) {
        return ParsedDeepLink(
          route: '/tracking/$tracking',
          parameters: {'trackingCode': tracking},
          category: RouteCategory.public,
        );
      }
    }

    // Caso 3: /assets/:assetRef (Asset operativo autenticado)
    if (pathSegments.length == 2 && pathSegments[0] == 'assets') {
      final assetRef = pathSegments[1].trim();
      if (_isValidParam(assetRef)) {
        return ParsedDeepLink(
          route: '/assets/$assetRef',
          parameters: {'assetRef': assetRef},
          category: RouteCategory.authenticated,
        );
      }
    }

    // Caso 4: Rutas fijas sin parámetros dinámicos
    final normalizedPath = '/${pathSegments.join('/')}';
    final category = AppRoutes.categorize(normalizedPath);
    if (category != RouteCategory.notApproved) {
      return ParsedDeepLink(
        route: normalizedPath,
        parameters: const {},
        category: category,
      );
    }

    // Cualquier otra ruta o parámetro no válido se trata como No Aprobada (R5)
    return const ParsedDeepLink.unapproved();
  }

  bool _isValidParam(String value) {
    return value.isNotEmpty && value.length <= 256;
  }
}