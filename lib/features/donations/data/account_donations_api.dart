import '../../../core/errors/app_exceptions.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/credential_mode.dart';

/// Elemento de `GET /account/donations`. Se descartan `intentId` (id interno) y `trackingCode` (secreto): la app
/// no los muestra ni los guarda (DDM-25).
class AccountDonation {
  const AccountDonation({
    required this.campaignTitle,
    required this.amount,
    required this.currency,
    required this.status,
  });
  final String campaignTitle;
  final String amount;
  final String currency;
  final String status;
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
            campaignTitle: '${i['campaignTitle'] ?? ''}',
            amount: '${i['amount'] ?? ''}',
            currency: '${i['currency'] ?? ''}',
            status: '${i['status'] ?? ''}',
          ),
    ];
  }
}
