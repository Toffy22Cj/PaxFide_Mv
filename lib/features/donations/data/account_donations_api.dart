import '../../../core/errors/app_exceptions.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/credential_mode.dart';

/// Elemento de `GET /account/donations`. Se descarta `intentId` (id interno). El `trackingCode` (secreto) solo vive
/// en memoria mientras dura la sesión, para "Ver el recorrido" (M-16, decisión 3): nunca se guarda ni se registra.
class AccountDonation {
  const AccountDonation({
    required this.campaignTitle,
    required this.amount,
    required this.currency,
    required this.status,
    this.trackingCode,
  });
  final String campaignTitle;
  final String amount;
  final String currency;
  final String status;
  final String? trackingCode;
}

class AccountDonationsApi {
  const AccountDonationsApi(this._api);
  final ApiClient _api;

  /// Una página de hasta 100 (DD-21), sin cursor.
  Future<List<AccountDonation>> list() async {
    final j = (await _api.get('/account/donations', credentialMode: CredentialMode.jwt)).requireData();
    final items = j['items'];
    if (items is! List) throw const MalformedResponseException();
    return [
      for (final i in items)
        if (i is Map)
          AccountDonation(
            // `campaignTitle?` solo falta si la convocatoria no se encuentra (rama defensiva del backend).
            campaignTitle: i['campaignTitle'] is String ? i['campaignTitle'] as String : '',
            amount: '${i['amount'] ?? ''}',
            currency: '${i['currency'] ?? ''}',
            status: '${i['status'] ?? ''}',
            trackingCode: i['trackingCode'] is String && (i['trackingCode'] as String).isNotEmpty
                ? i['trackingCode'] as String
                : null,
          ),
    ];
  }
}
