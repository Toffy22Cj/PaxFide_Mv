import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/features/campaigns/domain/campaign_search.dart';
import 'package:paxfide_mobile/features/campaigns/presentation/campaign_summary_card.dart';
import 'package:paxfide_mobile/shared/theme/pax_theme.dart';
import 'package:paxfide_mobile/shared/widgets/pax_ui.dart';

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
  testWidgets('variante 01: monto «X de Y (N %)», barra y «Cierra el …»', (tester) async {
    var opened = 0;
    await pump(
      tester,
      CampaignSummaryCard(
        c(target: '100000', cleared: '62000'),
        onTap: () => opened++,
      ),
    );
    expect(find.text('620,00 COP de 1 000,00 COP (62 %)'), findsOneWidget);
    expect(find.byType(SlimProgress), findsOneWidget);
    expect(find.text('Cierra el 31 de diciembre de 2099'), findsOneWidget);
    expect(find.text('F'), findsOneWidget); // la inicial de «Fundación Demo»
    await tester.tap(find.text('Abrigo'));
    expect(opened, 1);
  });

  testWidgets('sin meta en dinero no hay barra ni montos', (tester) async {
    await pump(tester, CampaignSummaryCard(c(), onTap: () {}));
    expect(find.byType(SlimProgress), findsNothing);
    expect(find.byKey(const Key('campaign.amounts')), findsNothing);
    expect(find.byKey(const Key('campaign.closes')), findsOneWidget);
  });

  testWidgets('esqueleto: sin texto visible, anunciado como carga', (tester) async {
    await pump(tester, const CampaignSkeletonCard());
    expect(find.byType(Text), findsNothing);
    expect(find.bySemanticsLabel('Cargando convocatoria'), findsOneWidget);
  });

  group('CampaignSummaryCard portada, logo y verificación', () {
    final base = Uri.parse('https://api.paxfide.org');

    testWidgets('muestra insignia solo con organizationVerified == true', (tester) async {
      await pump(
        tester,
        CampaignSummaryCard(
          CampaignSummary(
            publicCode: 'PUB1',
            title: 'Campaña Verificada',
            organizationName: 'Fundación Demo',
            status: 'OPEN',
            endDate: '2099-12-31',
            organizationVerified: true,
          ),
          onTap: () {},
          apiBaseUrl: base,
        ),
      );
      expect(find.byKey(const Key('campaign.verified')), findsOneWidget);
      expect(find.text('Verificada'), findsOneWidget);

      await pump(
        tester,
        CampaignSummaryCard(
          CampaignSummary(
            publicCode: 'PUB2',
            title: 'Campaña No Verificada',
            organizationName: 'Fundación Demo',
            status: 'OPEN',
            endDate: '2099-12-31',
            organizationVerified: false,
          ),
          onTap: () {},
          apiBaseUrl: base,
        ),
      );
      expect(find.byKey(const Key('campaign.verified')), findsNothing);
    });

    testWidgets('sin portada no se pide imagen por red', (tester) async {
      await pump(
        tester,
        CampaignSummaryCard(
          CampaignSummary(
            publicCode: 'PUB1',
            title: 'Campaña Sin Portada',
            organizationName: 'Fundación Demo',
            status: 'OPEN',
            endDate: '2099-12-31',
            coverImageUrl: null,
          ),
          onTap: () {},
          apiBaseUrl: base,
        ),
      );
      expect(find.byType(CampaignCoverImage), findsNothing);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('con portada válida muestra AspectRatio 16:9 con Image.network', (tester) async {
      await pump(
        tester,
        CampaignSummaryCard(
          CampaignSummary(
            publicCode: 'PUB1',
            title: 'Campaña Con Portada',
            organizationName: 'Fundación Demo',
            status: 'OPEN',
            endDate: '2099-12-31',
            coverImageUrl: '/api/v1/public/campaigns/PUB1/cover',
          ),
          onTap: () {},
          apiBaseUrl: base,
        ),
      );
      expect(find.byType(CampaignCoverImage), findsOneWidget);
      final aspect = tester.widget<AspectRatio>(
        find.descendant(of: find.byType(CampaignCoverImage), matching: find.byType(AspectRatio)),
      );
      expect(aspect.aspectRatio, 16 / 9);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('si el logo no tiene URL o falla muestra las iniciales', (tester) async {
      await pump(
        tester,
        CampaignSummaryCard(
          CampaignSummary(
            publicCode: 'PUB1',
            title: 'Campaña Sin Logo',
            organizationName: 'Fundación Demo',
            status: 'OPEN',
            endDate: '2099-12-31',
            organizationLogoUrl: null,
          ),
          onTap: () {},
          apiBaseUrl: base,
        ),
      );
      expect(find.byKey(const Key('organization.initials')), findsOneWidget);
      expect(find.text('F'), findsOneWidget);
    });

    testWidgets('pantalla de teléfono (411 x 891) con texto al 200% no desborda', (tester) async {
      tester.view.physicalSize = const Size(411 * 2, 891 * 2);
      tester.view.devicePixelRatio = 2.0;
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });

      await pump(
        tester,
        CampaignSummaryCard(
          CampaignSummary(
            publicCode: 'PUB1',
            title: 'Campaña con un título bastante largo para probar desbordes con texto grande',
            organizationName: 'Organización de Ayuda Comunitaria Muy Larga',
            status: 'OPEN',
            endDate: '2099-12-31',
            targetAmount: '100000',
            clearedAmount: '62000',
            organizationVerified: true,
            coverImageUrl: '/api/v1/public/campaigns/PUB1/cover',
            organizationLogoUrl: '/api/v1/public/campaigns/PUB1/logo',
          ),
          onTap: () {},
          apiBaseUrl: base,
        ),
        theme: PaxTheme.dark,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
