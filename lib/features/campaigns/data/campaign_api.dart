import '../../../core/errors/app_exceptions.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/credential_mode.dart';

/// Resuelve una ruta relativa de medios de la API contra el esquema, host y puerto de [apiBaseUrl].
/// Solo acepta rutas que empiecen por `/api/v1/public/`.
/// Devuelve null si la ruta es null o no empieza por `/api/v1/public/`, si es externa o si [apiBaseUrl] es null o inválido.
/// No añade códigos de rastreo en la URL.
Uri? resolveApiMediaUrl(Uri? apiBaseUrl, String? relativePath) {
  if (apiBaseUrl == null || relativePath == null) return null;
  final trimmed = relativePath.trim();
  if (!trimmed.startsWith('/api/v1/public/')) return null;
  if (trimmed.startsWith('//')) return null;
  final parsed = Uri.tryParse(trimmed);
  if (parsed == null || parsed.hasScheme || parsed.hasAuthority) return null;
  if (apiBaseUrl.scheme.isEmpty || apiBaseUrl.host.isEmpty) return null;
  return Uri(
    scheme: apiBaseUrl.scheme,
    host: apiBaseUrl.host,
    port: apiBaseUrl.hasPort ? apiBaseUrl.port : null,
    path: parsed.path,
  );
}

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
    this.organizationVerified = false,
    this.organizationLogoUrl,
    this.coverImageUrl,
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
  final bool organizationVerified;
  final String? organizationLogoUrl;
  final String? coverImageUrl;
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

/// Elemento del listado público de convocatorias (`GET /public/campaigns`).
class CampaignSummary {
  const CampaignSummary({
    required this.publicCode,
    required this.title,
    required this.organizationName,
    required this.status,
    required this.endDate,
    this.startDate = '',
    this.currency,
    this.targetAmount,
    this.clearedAmount,
    this.organizationVerified = false,
    this.organizationLogoUrl,
    this.coverImageUrl,
  });
  final String publicCode;
  final String title;
  final String organizationName;
  final String status;
  final String endDate;
  final String startDate;
  final String? currency;
  final String? targetAmount;
  final String? clearedAmount;
  final bool organizationVerified;
  final String? organizationLogoUrl;
  final String? coverImageUrl;
}

class CampaignApi {
  const CampaignApi(this._api);
  final ApiClient _api;

  /// `GET /public/campaigns` (P2.6): una página del listado público (sin filtros; `?cursor=` para la siguiente).
  Future<(List<CampaignSummary>, String?)> discover({String? cursor}) async {
    final j = (await _api.get(
      '/public/campaigns',
      queryParams: {'cursor': ?cursor},
      credentialMode: CredentialMode.none,
    )).requireData();
    final items = j['items'];
    if (items is! List) throw const MalformedResponseException();
    return (
      [
        for (final i in items)
          if (i is Map && i['publicCode'] is String && i['title'] is String)
            CampaignSummary(
              publicCode: i['publicCode'] as String,
              title: i['title'] as String,
              organizationName: _opt(i, 'organizationName') ?? '',
              status: _opt(i, 'status') ?? '',
              startDate: _opt(i, 'startDate') ?? '',
              endDate: _opt(i, 'endDate') ?? '',
              currency: _opt(i, 'currency'),
              targetAmount: _opt(i, 'targetAmount'),
              clearedAmount: _opt(i, 'clearedAmount'),
              organizationVerified: i['organizationVerified'] is bool ? i['organizationVerified'] as bool : false,
              organizationLogoUrl: _opt(i, 'organizationLogoUrl'),
              coverImageUrl: _opt(i, 'coverImageUrl'),
            ),
      ],
      _opt(j, 'nextCursor'),
    );
  }

  static String _path(String code) => '/public/campaigns/${Uri.encodeComponent(code)}';

  static String? _opt(Map j, String k) => j[k] is String ? j[k] as String : null;
  static List<String> _list(Object? v) => v is List ? [for (final x in v) '$x'] : const [];

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
      organizationVerified: j['organizationVerified'] is bool ? j['organizationVerified'] as bool : false,
      organizationLogoUrl: _opt(j, 'organizationLogoUrl'),
      coverImageUrl: _opt(j, 'coverImageUrl'),
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
