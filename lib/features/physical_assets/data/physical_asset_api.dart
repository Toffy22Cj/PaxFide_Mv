import '../../../core/errors/app_exceptions.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/network/credential_mode.dart';

/// `GET /physical-assets/{assetRef}` (matriz §4b). Sin `donorRef`, fondos ni genealogía: no vienen.
///
/// Solo `assetRef` y `lifecycleStatus` son obligatorios en el cliente: el backend omite los nulos y, por ejemplo,
/// un activo `DISPATCHED` no trae `currentLocation` (comprobado contra el backend real; S-05).
class PhysicalAssetDto {
  const PhysicalAssetDto({
    required this.assetRef,
    required this.lifecycleStatus,
    this.currentCustodianRef,
    this.currentLocation,
    this.quantity,
    this.unitOfMeasure,
    this.campaignRef,
  });

  final String assetRef;
  final String lifecycleStatus;
  final String? currentCustodianRef;
  final String? currentLocation;
  final String? quantity;
  final String? unitOfMeasure;
  final String? campaignRef;

  static PhysicalAssetDto fromJson(Map<String, dynamic> j) {
    String req(String k) {
      final v = j[k];
      if (v is! String) throw const MalformedResponseException();
      return v;
    }

    String? opt(String k) => j[k] is String ? j[k] as String : null;

    return PhysicalAssetDto(
      assetRef: req('assetRef'),
      lifecycleStatus: req('lifecycleStatus'),
      currentCustodianRef: opt('currentCustodianRef'),
      currentLocation: opt('currentLocation'),
      quantity: opt('quantity'),
      unitOfMeasure: opt('unitOfMeasure'),
      campaignRef: opt('campaignRef'),
    );
  }
}

class PhysicalAssetApi {
  const PhysicalAssetApi(this._api);

  final ApiClient _api;

  static String assetPath(String assetRef) => '/physical-assets/${Uri.encodeComponent(assetRef)}';

  /// 403 también para un activo inexistente o de otra organización (DD-01): no se distinguen.
  Future<PhysicalAssetDto> get(String assetRef) async {
    final r = await _api.get(assetPath(assetRef), credentialMode: CredentialMode.jwt);
    return PhysicalAssetDto.fromJson(r.requireData());
  }

  /// Envía un comando con su `Command-Id`. Devuelve la respuesta HTTP tal cual; los fallos de transporte se lanzan.
  Future<ApiResponse> postCommand({
    required String path,
    required Map<String, dynamic> body,
    required String commandId,
    Future<void> Function()? beforeSend,
  }) => _api.post(
    path,
    body: body,
    headers: {'Command-Id': commandId},
    credentialMode: CredentialMode.jwt,
    beforeSend: beforeSend,
  );
}
