import '../../../core/errors/app_exceptions.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/credential_mode.dart';

/// Un total por moneda, en unidades mínimas y como texto (nunca se suman monedas distintas).
class ImpactTotal {
  const ImpactTotal({required this.currency, required this.amount});
  final String currency;
  final String amount;
}

/// Unidades entregadas de una unidad de medida, como texto decimal.
class DeliveredUnits {
  const DeliveredUnits({required this.unitOfMeasure, required this.quantity});
  final String unitOfMeasure;
  final String quantity;
}

/// `GET /account/impact` (M-21; referencia-api-v1, nota del 2026-10-25). Solo cuenta las donaciones `CONFIRMED`.
/// [deliveredUnits] son las unidades entregadas **en las convocatorias que apoyó** la cuenta, no unidades atribuidas
/// a ella (P-M21-4). Con más de 100 donaciones solo cuentan las 100 más recientes ([truncated]).
class AccountImpactDto {
  const AccountImpactDto({
    required this.donationsCount,
    required this.totals,
    required this.campaignsSupported,
    required this.deliveredUnits,
    required this.truncated,
  });
  final int donationsCount;
  final List<ImpactTotal> totals;
  final int campaignsSupported;
  final List<DeliveredUnits> deliveredUnits;
  final bool truncated;
}

class AccountImpactApi {
  const AccountImpactApi(this._api);
  final ApiClient _api;

  static int _int(Object? v) => v is int ? v : (throw const MalformedResponseException());

  Future<AccountImpactDto> fetch() async {
    final j = (await _api.get('/account/impact', credentialMode: CredentialMode.jwt)).requireData();
    final totals = j['totals'];
    final units = j['deliveredUnits'];
    if (totals is! List || units is! List) throw const MalformedResponseException();
    return AccountImpactDto(
      donationsCount: _int(j['donationsCount']),
      campaignsSupported: _int(j['campaignsSupported']),
      truncated: j['truncated'] == true,
      totals: [
        for (final t in totals)
          if (t is Map && t['currency'] is String)
            ImpactTotal(currency: t['currency'] as String, amount: '${t['amount']}'),
      ],
      deliveredUnits: [
        for (final u in units)
          if (u is Map && u['unitOfMeasure'] is String)
            DeliveredUnits(unitOfMeasure: u['unitOfMeasure'] as String, quantity: '${u['quantity']}'),
      ],
    );
  }
}
