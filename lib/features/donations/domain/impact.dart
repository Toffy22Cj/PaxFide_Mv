import '../data/account_impact_api.dart';

export '../data/account_impact_api.dart' show AccountImpactDto, DeliveredUnits, ImpactTotal;

/// M-21: "Mi impacto": qué se logró con las donaciones confirmadas de la cuenta. La pantalla solo conoce
/// [ImpactSource].
typedef MyImpact = AccountImpactDto;

abstract interface class ImpactSource {
  /// null si no hay datos de impacto disponibles para la cuenta.
  Future<MyImpact?> myImpact();
}

/// `GET /account/impact`. Una cuenta que nunca donó recibe ceros: se trata como sin datos.
class ApiImpactSource implements ImpactSource {
  const ApiImpactSource(this._api);
  final AccountImpactApi _api;

  @override
  Future<MyImpact?> myImpact() async {
    final i = await _api.fetch();
    return i.donationsCount == 0 ? null : i;
  }
}

/// Sin fuente de datos: el panel no se muestra (nunca se inventan cifras).
class UnavailableImpactSource implements ImpactSource {
  const UnavailableImpactSource();

  @override
  Future<MyImpact?> myImpact() async => null;
}
