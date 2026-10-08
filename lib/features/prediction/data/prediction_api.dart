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

class PredictionApi {
  const PredictionApi(this._api);
  final ApiClient _api;

  /// 403 uniforme: sin permiso, otra organización o convocatoria inexistente.
  Future<Prediction> get(String organizationId, String campaignRef) async {
    final r = await _api.get(
      '/organizations/${Uri.encodeComponent(organizationId)}/campaigns/${Uri.encodeComponent(campaignRef)}/prediction',
      credentialMode: CredentialMode.jwt,
    );
    return Prediction.fromJson(r.requireData());
  }
}
