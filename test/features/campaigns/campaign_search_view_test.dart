import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/features/campaigns/domain/campaign_search.dart';
import 'package:paxfide_mobile/features/campaigns/presentation/campaign_search_view.dart';

class _FakeSearch implements CampaignSearch {
  final queries = <CampaignQuery>[];

  @override
  Future<List<CampaignSummary>> search(CampaignQuery query) async {
    queries.add(query);
    return [
      if ('abrigo'.contains(query.text.toLowerCase()))
        const CampaignSummary(
          publicCode: 'PUB1',
          title: 'Abrigo',
          organizationName: 'Fundación Demo',
          status: 'OPEN',
          endDate: '',
        ),
    ];
  }
}

Widget _app(CampaignSearch s, ValueChanged<String> onOpen) => MaterialApp(
  home: Scaffold(
    body: CampaignSearchView(search: s, onOpen: onOpen),
  ),
);

void main() {
  testWidgets('M-10: busca, filtra y ordena solo a través de CampaignSearch', (tester) async {
    final s = _FakeSearch();
    String? opened;
    await tester.pumpWidget(_app(s, (c) => opened = c));
    await tester.pumpAndSettle();
    expect(s.queries.single.openOnly, isTrue);

    await tester.tap(find.byKey(const Key('campaigns.sort.newest')));
    await tester.pumpAndSettle();
    expect(s.queries.last.sort, CampaignSort.newest);

    await tester.enterText(find.byKey(const Key('campaigns.search')), 'zzz');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(s.queries.last.text, 'zzz');
    expect(find.text('No encontramos convocatorias con esa búsqueda.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('campaigns.search')), 'abr');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('campaigns.item.PUB1')));
    expect(opened, 'PUB1');
  });

  testWidgets('M-10: sin backend de búsqueda → mensaje claro', (tester) async {
    await tester.pumpWidget(_app(const UnavailableCampaignSearch(), (_) {}));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('campaigns.unavailable')), findsOneWidget);
  });
}
