import '../../../core/errors/app_exceptions.dart';
import '../data/campaign_api.dart';
import 'campaign_progress.dart';
import 'campaign_search.dart';

/// [CampaignSearch] sobre el listado público que ya existe (`GET /public/campaigns`, sin filtros): trae hasta
/// [maxPages] páginas y busca, filtra y ordena en el teléfono. No cambia ningún contrato.
class PublicCampaignSearch implements CampaignSearch {
  PublicCampaignSearch(this._api, {this.maxPages = 5});
  final CampaignApi _api;
  final int maxPages;

  Future<List<CampaignSummary>> _all() async {
    final all = <CampaignSummary>[];
    String? cursor;
    for (var i = 0; i < maxPages; i++) {
      final (items, next) = await _api.discover(cursor: cursor);
      all.addAll(items);
      if (next == null) break;
      cursor = next;
    }
    return all;
  }

  @override
  Future<List<CampaignSummary>> search(CampaignQuery query) async {
    final List<CampaignSummary> all;
    try {
      all = await _all();
    } on NotFoundException {
      throw const CampaignSearchUnavailable();
    }
    final text = _fold(query.text);
    final out = all.where((c) {
      if (query.openOnly && c.status != 'OPEN') return false;
      if (text.isEmpty) return true;
      return _fold(c.title).contains(text) || _fold(c.organizationName).contains(text);
    }).toList();
    double reached(CampaignSummary c) =>
        CampaignProgress.of(
          target: int.tryParse(c.targetAmount ?? ''),
          cleared: int.tryParse(c.clearedAmount ?? ''),
          endDate: c.endDate,
        ).fraction ??
        -1;
    switch (query.sort) {
      case CampaignSort.endingSoon:
        out.sort((a, b) => a.endDate.compareTo(b.endDate));
      case CampaignSort.newest:
        out.sort((a, b) => b.startDate.compareTo(a.startDate));
      case CampaignSort.closestToGoal:
        out.sort((a, b) => reached(b).compareTo(reached(a)));
    }
    return out;
  }

  /// Minúsculas y sin tildes, para que "utiles" encuentre "Útiles".
  static String _fold(String s) {
    const from = 'áéíóúüñ';
    const to = 'aeiouun';
    final lower = s.toLowerCase().trim();
    final b = StringBuffer();
    for (final ch in lower.split('')) {
      final i = from.indexOf(ch);
      b.write(i < 0 ? ch : to[i]);
    }
    return b.toString();
  }
}
