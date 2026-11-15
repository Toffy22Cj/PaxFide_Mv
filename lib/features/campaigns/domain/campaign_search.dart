import '../data/campaign_api.dart';

export '../data/campaign_api.dart' show CampaignSummary;

/// M-10: búsqueda, filtro y orden de convocatorias. La pantalla solo conoce esta interfaz. Hoy se resuelve en el
/// teléfono sobre el listado público que ya existe; cuando la enmienda de ADR-041 traiga búsqueda en el backend, basta
/// con otra implementación.
enum CampaignSort {
  endingSoon('Terminan pronto'),
  newest('Más recientes'),
  closestToGoal('Más cerca de la meta');

  const CampaignSort(this.label);
  final String label;
}

class CampaignQuery {
  const CampaignQuery({this.text = '', this.openOnly = true, this.sort = CampaignSort.endingSoon});
  final String text;
  final bool openOnly;
  final CampaignSort sort;

  CampaignQuery copyWith({String? text, bool? openOnly, CampaignSort? sort}) =>
      CampaignQuery(text: text ?? this.text, openOnly: openOnly ?? this.openOnly, sort: sort ?? this.sort);
}

/// No hay búsqueda en el backend todavía.
class CampaignSearchUnavailable implements Exception {
  const CampaignSearchUnavailable();
}

abstract interface class CampaignSearch {
  Future<List<CampaignSummary>> search(CampaignQuery query);
}

/// Implementación hasta que exista el contrato: siempre "no disponible" (ver PENDIENTES_ADONIS.md).
class UnavailableCampaignSearch implements CampaignSearch {
  const UnavailableCampaignSearch();

  @override
  Future<List<CampaignSummary>> search(CampaignQuery query) => Future.error(const CampaignSearchUnavailable());
}
