import 'app_routes.dart';

/// URL de los QR: las mismas rutas canónicas que la web (matriz §4b) sobre el
/// origen configurado (DDM-03). Nunca hay QR de seguimiento: el código no va
/// en una URL (ADR-043 §0).
class PublicLinks {
  const PublicLinks(this.origin);

  final Uri? origin;

  bool get isConfigured => origin != null;

  Uri? _build(String path) => origin?.replace(path: path);

  Uri? asset(String assetRef) =>
      AppRoutes.isValidParam(assetRef) ? _build(AppRoutes.assetPath(Uri.encodeComponent(assetRef))) : null;

  Uri? campaign(String publicCode) =>
      AppRoutes.isValidParam(publicCode) ? _build(AppRoutes.campaignPath(Uri.encodeComponent(publicCode))) : null;
}
