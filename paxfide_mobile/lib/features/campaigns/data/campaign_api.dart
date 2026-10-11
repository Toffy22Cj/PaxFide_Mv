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

/// Elemento de `GET /public/campaigns`: solo convocatorias `PUBLIC` y `OPEN`.
class CampaignSummary {
  const CampaignSummary({
    required this.publicCode,
    required this.title,
    this.organizationName,
    required this.status,
    required this.acceptedDonationTypes,
    this.currency,
    this.targetAmount,
    this.clearedAmount,
    required this.endDate,
  });
  final String publicCode;
  final String title;
  final String? organizationName;
  final String status;
  final List<String> acceptedDonationTypes;
  final String? currency;
  final String? targetAmount;
  final String? clearedAmount;
  final String endDate;
}

/// Una página del descubrimiento; [nextCursor] es opaco (DD-58).
class CampaignPage {
  const CampaignPage(this.items, this.nextCursor);
  final List<CampaignSummary> items;
  final String? nextCursor;
}

/// Un periodo de la estadística pública: días `from`–`to` (fechas `AAAA-MM-DD`) con su monto y donaciones.
class DonationPeriod {
  const DonationPeriod({required this.from, required this.to, required this.amount, required this.donations});
  final String from;
  final String to;
  final int amount;
  final int donations;
}

/// `GET /public/campaigns/{publicCode}/donation-stats`: solo totales por periodo (cada uno con al menos
/// [minDonationsPerPeriod] donaciones), nunca donaciones sueltas. Importes en unidades mínimas.
class DonationStats {
  const DonationStats({
    this.currency,
    this.targetAmount,
    required this.totalAmount,
    required this.donations,
    required this.minDonationsPerPeriod,
    required this.periods,
  });
  final String? currency;
  final int? targetAmount;
  final int totalAmount;
  final int donations;
  final int minDonationsPerPeriod;
  final List<DonationPeriod> periods;
}

class CampaignApi {
  const CampaignApi(this._api);
  final ApiClient _api;

  static String _path(String code) => '/public/campaigns/${Uri.encodeComponent(code)}';

  static String? _opt(Map j, String k) => j[k] is String ? j[k] as String : null;
  static List<String> _list(Object? v) => v is List ? [for (final x in v) '$x'] : const [];

  /// `GET /public/campaigns`, 20 por página.
  Future<CampaignPage> list({String? cursor}) async {
    final j = (await _api.get(
      '/public/campaigns',
      queryParams: cursor == null ? null : {'cursor': cursor},
      credentialMode: CredentialMode.none,
    ))
        .requireData();
    final items = j['items'];
    if (items is! List) throw const MalformedResponseException();
    return CampaignPage(
      [
        for (final i in items)
          if (i is Map && i['publicCode'] is String && i['title'] is String)
            CampaignSummary(
              publicCode: i['publicCode'] as String,
              title: i['title'] as String,
              organizationName: _opt(i, 'organizationName'),
              status: '${i['status'] ?? ''}',
              acceptedDonationTypes: _list(i['acceptedDonationTypes']),
              currency: _opt(i, 'currency'),
              targetAmount: _opt(i, 'targetAmount'),
              clearedAmount: _opt(i, 'clearedAmount'),
              endDate: '${i['endDate'] ?? ''}',
            ),
      ],
      _opt(j, 'nextCursor'),
    );
  }

  Future<PublicCampaign> get(String publicCode) async {
    final j = (await _api.get(_path(publicCode), credentialMode: CredentialMode.none)).requireData();
    if (j['title'] is! String || j['status'] is! String) throw const MalformedResponseException();
    return PublicCampaign(
      organizationName: j['organizationName'] is String ? j['organizationName'] as String : '',
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

  /// Estadística pública de donaciones del detalle de la causa.
  Future<DonationStats> donationStats(String publicCode) async {
    final j = (await _api.get('${_path(publicCode)}/donation-stats', credentialMode: CredentialMode.none))
        .requireData();
    final total = int.tryParse('${j['totalAmount']}');
    final periods = j['periods'];
    if (total == null || periods is! List) throw const MalformedResponseException();
    return DonationStats(
      currency: _opt(j, 'currency'),
      targetAmount: int.tryParse('${j['targetAmount'] ?? ''}'),
      totalAmount: total,
      donations: j['donations'] is int ? j['donations'] as int : 0,
      minDonationsPerPeriod: j['minDonationsPerPeriod'] is int ? j['minDonationsPerPeriod'] as int : 3,
      periods: [
        for (final p in periods)
          if (p is Map && p['from'] is String && p['to'] is String && int.tryParse('${p['amount']}') != null)
            DonationPeriod(
              from: p['from'] as String,
              to: p['to'] as String,
              amount: int.parse('${p['amount']}'),
              donations: p['donations'] is int ? p['donations'] as int : 0,
            ),
      ],
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
