import '../../core/errors/app_exceptions.dart';
import '../../core/network/api_client.dart';
import '../../core/network/credential_mode.dart';

/// Un municipio del catálogo DIVIPOLA del backend (ficha R-7 §6; enmienda 2 de ADR-029).
class Municipality {
  const Municipality({required this.code, required this.name, required this.departmentName});
  final String code;
  final String name;
  final String departmentName;

  /// El texto de la zona tal como lo sella el backend (`SealedZone.of`): «MUNICIPIO, DEPARTAMENTO», o solo el municipio
  /// si los dos nombres son iguales (Bogotá).
  String get zoneName => name == departmentName ? name : '$name, $departmentName';
}

/// `GET /public/locations`: pública, cacheable un día. Se pide una vez por apertura de la app.
class LocationCatalogApi {
  LocationCatalogApi(this._api);
  final ApiClient _api;
  Future<List<Municipality>>? _cache;

  /// Todos los municipios, ordenados por la zona. Si falla, la siguiente llamada lo vuelve a pedir.
  Future<List<Municipality>> municipalities() {
    final pending = _cache ??= _load();
    pending.catchError((Object _) {
      _cache = null;
      return const <Municipality>[];
    });
    return pending;
  }

  Future<List<Municipality>> _load() async {
    final j = (await _api.get('/public/locations', credentialMode: CredentialMode.none)).requireData();
    final departments = j['departments'];
    if (departments is! List) throw const MalformedResponseException();
    final out = <Municipality>[];
    for (final d in departments) {
      if (d is! Map || d['name'] is! String || d['municipalities'] is! List) continue;
      for (final m in d['municipalities'] as List) {
        if (m is Map && m['code'] is String && m['name'] is String) {
          out.add(
            Municipality(code: m['code'] as String, name: m['name'] as String, departmentName: d['name'] as String),
          );
        }
      }
    }
    if (out.isEmpty) throw const MalformedResponseException();
    out.sort((a, b) => a.zoneName.compareTo(b.zoneName));
    return out;
  }
}
