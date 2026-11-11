/// Configuración de compilación (`--dart-define`). Sin valores por defecto: nada de hosts inventados.
///
/// - `PAXFIDE_API_BASE_URL`: base de la API, p. ej. `http://10.0.2.2:8080/api/v1` (emulador Android contra el
///   backend local del `runbook-demo-local.md`).
/// - `PAXFIDE_PUBLIC_BASE_URL`: origen canónico de los enlaces y QR, igual que la web (DDM-03). Sin él, el escáner
///   no aprueba ningún enlace y no se generan QR.
/// - `PAXFIDE_GOOGLE_SERVER_CLIENT_ID`: ID de cliente web de Google para «Entrar con Google» (ADR-050 D9).
/// - `PAXFIDE_MAP_TILE_URL`: plantilla de las teselas del mapa del recorrido (ADR del mapa, D4), con `{z}`, `{x}` y `{y}`,
///   p. ej. `https://tile.openstreetmap.org/{z}/{x}/{y}.png` en desarrollo. Sin ella, el mapa no se muestra.
///   Producción necesita un proveedor de teselas: las públicas de OpenStreetMap no admiten ese tráfico.
class AppConfig {
  const AppConfig({required this.apiBaseUrl, required this.publicOrigin, this.mapTileUrl, this.googleServerClientId});

  factory AppConfig.fromEnvironment() => AppConfig(
    apiBaseUrl: _parse(const String.fromEnvironment('PAXFIDE_API_BASE_URL')),
    publicOrigin: _origin(_parse(const String.fromEnvironment('PAXFIDE_PUBLIC_BASE_URL'))),
    mapTileUrl: tileTemplate(const String.fromEnvironment('PAXFIDE_MAP_TILE_URL')),
    googleServerClientId: googleClientId(
      const String.fromEnvironment('PAXFIDE_GOOGLE_SERVER_CLIENT_ID', defaultValue: defaultGoogleServerClientId),
    ),
  );

  /// ID de cliente OAuth **web** de Google Cloud (ADR-050 D9): el `serverClientId` con que la app pide el `idToken`.
  /// Sin él, «Entrar con Google» no aparece. No es un secreto, pero no va en el repositorio.
  final String? googleServerClientId;

  /// ID de cliente web de PaxFide en Google Cloud: no es un secreto (va dentro del APK). Se cambia con
  /// `PAXFIDE_GOOGLE_SERVER_CLIENT_ID`.
  static const defaultGoogleServerClientId = '333718585935-533ra859o9kio4vc8huvbmi1rnk4b5gf.apps.googleusercontent.com';

  /// Forma de un ID de cliente de Google (`…​.apps.googleusercontent.com`); si no, ninguno.
  static String? googleClientId(String raw) {
    final t = raw.trim();
    return RegExp(r'^[0-9]+-[a-z0-9]+\.apps\.googleusercontent\.com$').hasMatch(t) ? t : null;
  }

  final Uri? apiBaseUrl;
  final Uri? publicOrigin;

  /// Plantilla de las teselas del mapa, ya validada; `null` = sin mapa.
  final String? mapTileUrl;

  /// `http(s)` con host y las tres variables `{z}`, `{x}` y `{y}`; si no, ninguna (nunca una inventada).
  static String? tileTemplate(String raw) {
    final t = raw.trim();
    if (!t.contains('{z}') || !t.contains('{x}') || !t.contains('{y}')) return null;
    final uri = Uri.tryParse(t.replaceAll(RegExp(r'\{[a-z]\}'), '0'));
    if (uri == null || !(uri.scheme == 'https' || uri.scheme == 'http') || uri.host.isEmpty) return null;
    return t;
  }

  static Uri? _parse(String raw) {
    if (raw.trim().isEmpty) return null;
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || !(uri.scheme == 'https' || uri.scheme == 'http') || uri.host.isEmpty) return null;
    return uri;
  }

  /// Solo esquema, host y puerto.
  static Uri? _origin(Uri? uri) =>
      uri == null ? null : Uri(scheme: uri.scheme, host: uri.host, port: uri.hasPort ? uri.port : null);

  static Uri? originOf(String raw) => _origin(_parse(raw));
}
