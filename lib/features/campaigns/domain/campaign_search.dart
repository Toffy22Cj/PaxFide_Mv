/// M-10: búsqueda, filtro y orden de convocatorias. El listado público existe, pero la búsqueda y los filtros cambian
/// el contrato HTTP (enmienda de ADR-041, pendiente); la pantalla solo conoce esta interfaz.
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

class CampaignSummary {
  const CampaignSummary({
    required this.publicCode,
    required this.title,
    required this.organizationName,
    required this.status,
    required this.endDate,
  });
  final String publicCode;
  final String title;
  final String organizationName;
  final String status;
  final String endDate;
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
