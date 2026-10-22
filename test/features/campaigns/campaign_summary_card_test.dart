import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/features/campaigns/domain/campaign_search.dart';
import 'package:paxfide_mobile/features/campaigns/presentation/campaign_summary_card.dart';
import 'package:paxfide_mobile/shared/theme/pax_theme.dart';

CampaignSummary c({String status = 'OPEN', String? target, String? cleared, String end = '2099-12-31'}) =>
    CampaignSummary(
      publicCode: 'PUB1',
      title: 'Abrigo',
      organizationName: 'Fundación Demo',
      status: status,
      endDate: end,
      currency: 'COP',
      targetAmount: target,
      clearedAmount: cleared,
    );

Future<void> pump(WidgetTester tester, Widget w, {ThemeData? theme}) => tester.pumpWidget(
  MaterialApp(
    theme: theme ?? PaxTheme.light,
    home: Scaffold(body: ListView(children: [w])),
  ),
);

void main() {
  testWidgets('variante 15: con meta, el porcentaje es la cifra y se ven recaudado y meta', (tester) async {
    var opened = 0;
    await pump(
      tester,
      CampaignFigureCard(
        c(target: '100000', cleared: '62000'),
        onOpen: () => opened++,
      ),
    );
    expect(tester.widget<Text>(find.byKey(const Key('campaign.figure'))).data, '62 %');
    expect(find.text('de la meta'), findsOneWidget);
    expect(find.textContaining('620,00 COP de 1 000,00 COP'), findsOneWidget);
    expect(find.byKey(const Key('campaign.reached')), findsNothing);
    await tester.tap(find.text('Ver detalles'));
    expect(opened, 1);
  });

  testWidgets('sin meta en dinero, meta alcanzada y cerrada', (tester) async {
    await pump(tester, CampaignFigureCard(c(), onOpen: () {}));
    expect(find.text('Sin meta en dinero'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('campaign.figure'))).data, startsWith('Quedan'));

    await pump(
      tester,
      CampaignFigureCard(
        c(target: '1000', cleared: '1500'),
        onOpen: () {},
      ),
    );
    expect(find.byKey(const Key('campaign.reached')), findsOneWidget);

    await pump(
      tester,
      CampaignFigureCard(
        c(status: 'CLOSED', end: '2020-01-01'),
        onOpen: () {},
      ),
    );
    expect(find.byKey(const Key('campaign.closed')), findsOneWidget);
  });

  testWidgets('esqueleto: sin texto visible, anunciado como carga; y sin desbordes en oscuro con texto grande', (
    tester,
  ) async {
    await pump(tester, const CampaignSkeletonCard());
    expect(find.byType(Text), findsNothing);
    expect(find.bySemanticsLabel('Cargando convocatoria'), findsOneWidget);

    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pump(
      tester,
      CampaignFigureCard(
        c(target: '100000', cleared: '62000'),
        onOpen: () {},
      ),
      theme: PaxTheme.dark,
    );
    expect(tester.takeException(), isNull);
  });
}
