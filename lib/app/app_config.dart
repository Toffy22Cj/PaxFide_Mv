/// Configuración de compilación (`--dart-define`). Sin valores por defecto: nada de hosts inventados.
///
/// - `PAXFIDE_API_BASE_URL`: base de la API, p. ej. `http://10.0.2.2:8080/api/v1` (emulador Android contra el
///   backend local del `runbook-demo-local.md`).
/// - `PAXFIDE_PUBLIC_BASE_URL`: origen canónico de los enlaces y QR, igual que la web (DDM-03). Sin él, el escáner
///   no aprueba ningún enlace y no se generan QR.
class AppConfig {
  const AppConfig({required this.apiBaseUrl, required this.publicOrigin});

  factory AppConfig.fromEnvironment() => AppConfig(
    apiBaseUrl: _parse(const String.fromEnvironment('PAXFIDE_API_BASE_URL')),
    publicOrigin: _origin(_parse(const String.fromEnvironment('PAXFIDE_PUBLIC_BASE_URL'))),
  );

  final Uri? apiBaseUrl;
  final Uri? publicOrigin;

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
