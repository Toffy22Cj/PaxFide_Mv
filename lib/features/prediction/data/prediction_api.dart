import '../../../core/errors/app_exceptions.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/credential_mode.dart';

/// `GET /organizations/{organizationId}/campaigns/{campaignRef}/prediction` (P3; ADR-044 Enmienda 1). Solo lectura.
/// Es una **estimación** (`kind: ESTIMATE`), no un hecho. Las fracciones vienen entre 0 y 1.
class Prediction {
  const Prediction({
    required this.kind,
    required this.modelVersion,
    required this.warning,
    required this.available,
    this.unavailableReason,
    this.unavailableText,
    this.probabilityReachTarget,
    this.estimatedFinalPctOfTarget,
    this.pctTimeElapsed,
    this.warnings = const [],
    required this.asOf,
  });

  final String kind;
  final String modelVersion;
  final String warning;
  final bool available;
  final String? unavailableReason;
  final String? unavailableText;
  final double? probabilityReachTarget;
  final double? estimatedFinalPctOfTarget;
  final double? pctTimeElapsed;
  final List<String> warnings;
  final String asOf;

  static double? _d(Object? v) => v is num ? v.toDouble() : null;

  static Prediction fromJson(Map<String, dynamic> j) {
    if (j['kind'] is! String || j['available'] is! bool || j['modelVersion'] is! String) {
      throw const MalformedResponseException();
    }
    return Prediction(
      kind: j['kind'] as String,
      modelVersion: j['modelVersion'] as String,
      warning: '${j['warning'] ?? ''}',
      available: j['available'] as bool,
      unavailableReason: j['unavailableReason'] as String?,
      unavailableText: j['unavailableText'] as String?,
      probabilityReachTarget: _d(j['probabilityReachTarget']),
      estimatedFinalPctOfTarget: _d(j['estimatedFinalPctOfTarget']),
      pctTimeElapsed: _d(j['pctTimeElapsed']),
      warnings: j['warnings'] is List ? [for (final w in j['warnings'] as List) '$w'] : const [],
      asOf: '${j['asOf'] ?? ''}',
    );
  }
}

/// Convocatoria elegible para la predicción (de `GET /organizations/{id}/campaigns` o `GET /me/campaigns`).
class CampaignChoice {
  const CampaignChoice({required this.campaignRef, required this.title, required this.status});
  final String campaignRef;
  final String title;
  final String status;

  static List<CampaignChoice> listFrom(Map<String, dynamic> j) {
    final items = j['items'];
    if (items is! List) throw const MalformedResponseException();
    return [
      for (final i in items)
        if (i is Map && i['campaignRef'] is String && i['title'] is String)
          CampaignChoice(
            campaignRef: i['campaignRef'] as String,
            title: i['title'] as String,
            status: '${i['status']}',
          ),
    ];
  }
}

class PredictionApi {
  const PredictionApi(this._api);
  final ApiClient _api;

  /// Listado del panel: solo `ADMINISTRATOR` (referencia-api-v1 §3). 403 para cualquier otro rol.
  Future<List<CampaignChoice>> organizationCampaigns(String organizationId) async {
    final r = await _api.get(
      '/organizations/${Uri.encodeComponent(organizationId)}/campaigns',
      credentialMode: CredentialMode.jwt,
    );
    return CampaignChoice.listFrom(r.requireData());
  }

  /// Convocatorias asignadas a quien llama (§3.4), también las cerradas (DD-72).
  Future<List<CampaignChoice>> myCampaigns() async {
    final r = await _api.get('/me/campaigns', credentialMode: CredentialMode.jwt);
    return CampaignChoice.listFrom(r.requireData());
  }

  /// 403 uniforme: sin permiso, otra organización o convocatoria inexistente.
  Future<Prediction> get(String organizationId, String campaignRef) async {
    final r = await _api.get(
      '/organizations/${Uri.encodeComponent(organizationId)}/campaigns/${Uri.encodeComponent(campaignRef)}/prediction',
      credentialMode: CredentialMode.jwt,
    );
    return Prediction.fromJson(r.requireData());
  }
}
