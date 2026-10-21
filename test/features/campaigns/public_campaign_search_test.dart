import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/core/network/api_response.dart';
import 'package:paxfide_mobile/features/campaigns/data/campaign_api.dart';
import 'package:paxfide_mobile/features/campaigns/domain/campaign_search.dart';
import 'package:paxfide_mobile/features/campaigns/domain/public_campaign_search.dart';

import '../../support/fakes.dart';

Map<String, Object> c(String code, String title, String status, String end) => {
  'publicCode': code,
  'title': title,
  'organizationName': 'Fundación',
  'status': status,
  'startDate': '2026-10-01',
  'endDate': end,
};

void main() {
  test('recorre las páginas con el cursor y busca, filtra y ordena en el teléfono', () async {
    final api = FakeApiClient();
    api.enqueue(
      ApiResponse(
        statusCode: 200,
        data: {
          'items': [c('A', 'Útiles escolares', 'OPEN', '2026-12-01'), c('B', 'Cerrada vieja', 'CLOSED', '2026-01-01')],
          'nextCursor': 'K1',
        },
      ),
    );
    api.enqueue(
      ApiResponse(
        statusCode: 200,
        data: {
          'items': [c('C', 'Abrigo Invierno', 'OPEN', '2026-11-01')],
        },
      ),
    );
    final search = PublicCampaignSearch(CampaignApi(api));
    final all = await search.search(const CampaignQuery());
    expect(all.map((x) => x.publicCode), ['C', 'A'], reason: 'solo abiertas; terminan pronto primero');
    expect(api.calls.map((x) => x.path).toSet(), {'/public/campaigns'});

    api.routes['GET /public/campaigns'] = (_) => ApiResponse(
      statusCode: 200,
      data: {
        'items': [c('A', 'Útiles escolares', 'OPEN', '2026-12-01')],
      },
    );
    expect((await search.search(const CampaignQuery(text: 'utiles'))).single.publicCode, 'A');
    expect(await search.search(const CampaignQuery(text: 'zzz')), isEmpty);
  });
}
