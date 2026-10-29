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
    this.createdAt,
    this.organizationName,
    this.paymentMethod,
    this.publicCode,
  });
  final String campaignTitle;
  final String amount;
  final String currency;
  final String status;
  final String? trackingCode;

  /// Falta en intenciones anteriores a la Enmienda 5 de ADR-037.
  final String? createdAt;
  final String? organizationName;

  /// `GATEWAY`, `BANK_TRANSFER` o `CASH`.
  final String? paymentMethod;

  /// Solo si la convocatoria es pública al leer (una `PRIVATE_LINK` nunca lo trae, ADR-041 §2.7).
  final String? publicCode;
}

/// Nombre del medio de pago; un literal desconocido se muestra tal cual.
String paymentMethodLabel(String v) => switch (v) {
  'GATEWAY' => 'Pasarela de pago',
  'BANK_TRANSFER' => 'Transferencia bancaria',
  'CASH' => 'Efectivo',
  _ => v,
};

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
            createdAt: _opt(i['createdAt']),
            organizationName: _opt(i['organizationName']),
            paymentMethod: _opt(i['paymentMethod']),
            publicCode: _opt(i['publicCode']),
          ),
    ];
  }
}

String? _opt(Object? v) => v is String && v.isNotEmpty ? v : null;
