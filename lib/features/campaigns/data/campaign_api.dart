import '../../../core/errors/app_exceptions.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/credential_mode.dart';

/// `GET /public/campaigns/{publicCode}` (CV-07). Importes como texto de dígitos.
class PublicCampaign {
  const PublicCampaign({
    required this.organizationName,
    required this.title,
    this.description,
    required this.status,
    required this.startDate,
    required this.endDate,
    required this.acceptedDonationTypes,
    required this.acceptedPaymentMethods,
    this.currency,
    this.targetAmount,
    this.clearedAmount,
  });
  final String organizationName;
  final String title;
  final String? description;
  final String status;
  final String startDate;
  final String endDate;
  final List<String> acceptedDonationTypes;
  final List<String> acceptedPaymentMethods;
  final String? currency;
  final String? targetAmount;
  final String? clearedAmount;
}

/// Hechos de la narrativa de convocatoria (B5, DD-39): son los datos verificables; la narrativa se apoya en ellos.
class CampaignFacts {
  const CampaignFacts({
    required this.status,
    this.currency,
    this.targetAmount,
    this.clearedAmount,
    required this.unitsDelivered,
    required this.distinctRecipients,
  });
  final String status;
  final String? currency;
  final String? targetAmount;
  final String? clearedAmount;
  final String unitsDelivered;
  final String distinctRecipients;
}

class CampaignNarrative {
  const CampaignNarrative({required this.status, this.content, this.source, this.facts});
  final String status; // AVAILABLE | PENDING | UNAVAILABLE
  final String? content;
  final String? source;
  final CampaignFacts? facts;
}

class CampaignApi {
  const CampaignApi(this._api);
  final ApiClient _api;

  static String _path(String code) => '/public/campaigns/${Uri.encodeComponent(code)}';

  static String? _opt(Map j, String k) => j[k] is String ? j[k] as String : null;
  static List<String> _list(Object? v) => v is List ? [for (final x in v) '$x'] : const [];

  Future<PublicCampaign> get(String publicCode) async {
    final j = (await _api.get(_path(publicCode), credentialMode: CredentialMode.none)).requireData();
    if (j['title'] is! String || j['status'] is! String) throw const MalformedResponseException();
    return PublicCampaign(
      organizationName: '${j['organizationName'] ?? ''}',
      title: j['title'] as String,
      description: _opt(j, 'description'),
      status: j['status'] as String,
      startDate: '${j['startDate'] ?? ''}',
      endDate: '${j['endDate'] ?? ''}',
      acceptedDonationTypes: _list(j['acceptedDonationTypes']),
      acceptedPaymentMethods: _list(j['acceptedPaymentMethods']),
      currency: _opt(j, 'currency'),
      targetAmount: _opt(j, 'targetAmount'),
      clearedAmount: _opt(j, 'clearedAmount'),
    );
  }

  /// 200 AVAILABLE/UNAVAILABLE o 202 PENDING, siempre con los hechos.
  Future<CampaignNarrative> narrative(String publicCode) async {
    final j = (await _api.get('${_path(publicCode)}/narrative', credentialMode: CredentialMode.none)).requireData();
    final f = j['facts'];
    return CampaignNarrative(
      status: '${j['status']}',
      content: _opt(j, 'content'),
      source: _opt(j, 'source'),
      facts: f is Map
          ? CampaignFacts(
              status: '${f['status'] ?? ''}',
              currency: _opt(f, 'currency'),
              targetAmount: _opt(f, 'targetAmount'),
              clearedAmount: _opt(f, 'clearedAmount'),
              unitsDelivered: '${f['unitsDelivered'] ?? ''}',
              distinctRecipients: '${f['distinctRecipients'] ?? ''}',
            )
          : null,
    );
  }
}
