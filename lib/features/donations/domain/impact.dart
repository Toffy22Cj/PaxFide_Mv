/// M-21: "Mi impacto": qué se logró con las donaciones de la cuenta (bienes entregados por convocatoria). El backend
/// todavía no lo expone (ver PENDIENTES_ADONIS.md); la pantalla solo conoce [ImpactSource].
class CampaignImpact {
  const CampaignImpact({required this.campaignTitle, required this.unitsDelivered});
  final String campaignTitle;
  final int unitsDelivered;
}

class MyImpact {
  const MyImpact({required this.unitsDelivered, required this.distinctRecipients, required this.byCampaign});
  final int unitsDelivered;
  final int distinctRecipients;
  final List<CampaignImpact> byCampaign;
}

abstract interface class ImpactSource {
  /// null si no hay datos de impacto disponibles para la cuenta.
  Future<MyImpact?> myImpact();
}

/// Hasta que exista el endpoint: sin datos, y el panel no se muestra (nunca se inventan cifras).
class UnavailableImpactSource implements ImpactSource {
  const UnavailableImpactSource();

  @override
  Future<MyImpact?> myImpact() async => null;
}
