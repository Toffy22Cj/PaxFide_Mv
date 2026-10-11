import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/core/network/credential_mode.dart';
import 'package:paxfide_mobile/features/campaigns/data/campaign_api.dart';
import 'package:paxfide_mobile/features/campaigns/presentation/donation_stats_card.dart';

import '../../support/app_harness.dart';
import '../../support/fakes.dart';

const _code = 'CV-ABCDEFGHJK';

Map<String, dynamic> _campaign({String status = 'OPEN', String cleared = '600000', String? currency = 'COP'}) => {
      'organizationName': 'Fundación Demo',
      'title': 'Abrigo para el invierno',
      'status': status,
      'startDate': '2026-10-01T00:00:00Z',
      'endDate': '2026-11-20T00:00:00Z',
      'acceptedDonationTypes': ['MONETARY'],
      'acceptedPaymentMethods': ['GATEWAY'],
      'currency': ?currency,
      'targetAmount': ?(currency == null ? null : '2000000'),
      'clearedAmount': ?(currency == null ? null : cleared),
    };

Map<String, dynamic> _stats({
  String total = '600000',
  int donations = 6,
  List<Map<String, dynamic>>? periods,
}) =>
    {
      'currency': 'COP',
      'targetAmount': '2000000',
      'totalAmount': total,
      'donations': donations,
      'minDonationsPerPeriod': 3,
      'timeZone': 'America/Bogota',
      'periods': periods ??
          [
            {'from': '2026-10-01', 'to': '2026-10-01', 'amount': '200000', 'donations': 3},
            {'from': '2026-10-03', 'to': '2026-10-05', 'amount': '400000', 'donations': 3},
          ],
      'asOf': '2026-10-11T00:00:00Z',
    };

Future<Harness> _open(WidgetTester tester, {Map<String, dynamic>? campaign, Map<String, dynamic>? stats}) async {
  final h = Harness();
  h.api.routes['GET /public/campaigns/$_code'] = (_) => ok(campaign ?? _campaign());
  h.api.routes['GET /public/campaigns/$_code/narrative'] = (_) => status(404);
  h.api.routes['GET /public/campaigns/$_code/donation-stats'] = (_) => ok(stats ?? _stats());
  await h.pump(tester, initialRoute: '/c/$_code', size: const Size(400, 1400));
  return h;
}

String _detail(WidgetTester tester) =>
    tester.widget<Text>(find.descendant(of: find.byKey(const Key('donation-stats-detail')), matching: find.byType(Text))).data!;

void main() {
  group('API', () {
    test('lee la estadística pública sin credenciales', () async {
      final api = FakeApiClient();
      api.routes['GET /public/campaigns/$_code/donation-stats'] = (_) => ok(_stats());
      final s = await CampaignApi(api).donationStats(_code);
      expect(api.calls.single.credentialMode, CredentialMode.none);
      expect(s.totalAmount, 600000);
      expect(s.targetAmount, 2000000);
      expect(s.donations, 6);
      expect(s.periods.map((p) => '${p.from}..${p.to}:${p.amount}/${p.donations}'),
          ['2026-10-01..2026-10-01:200000/3', '2026-10-03..2026-10-05:400000/3']);
    });

    test('etiquetas de periodo en palabras', () {
      expect(periodLabel(const DonationPeriod(from: '2026-10-01', to: '2026-10-01', amount: 1, donations: 3)),
          'El 1 de octubre');
      expect(periodLabel(const DonationPeriod(from: '2026-10-03', to: '2026-10-05', amount: 1, donations: 3)),
          'Del 3 al 5 de octubre');
      expect(periodLabel(const DonationPeriod(from: '2026-10-30', to: '2026-11-02', amount: 1, donations: 3)),
          'Del 30 de octubre al 2 de noviembre');
    });
  });

  group('detalle de la causa', () {
    testWidgets('muestra el total, el gráfico y el último periodo en palabras', (tester) async {
      await _open(tester);
      expect(find.byKey(const Key('donation-stats')), findsOneWidget);
      expect(find.byKey(const Key('donation-chart')), findsOneWidget);
      expect(find.text('6'), findsOneWidget);
      expect(_detail(tester),
          'Del 3 al 5 de octubre llegaron \$4.000 COP en 3 donaciones. Hasta ese día se habían reunido \$6.000 COP.');
      expect(find.text('Se actualiza solo mientras tienes esta pantalla abierta.'), findsOneWidget);
    });

    testWidgets('tocar el gráfico elige otro periodo', (tester) async {
      await _open(tester);
      final chart = tester.getRect(find.byKey(const Key('donation-chart')));
      await tester.tapAt(Offset(chart.left + chart.width * 0.2, chart.center.dy));
      await tester.pumpAndSettle();
      expect(_detail(tester),
          'El 1 de octubre llegaron \$2.000 COP en 3 donaciones. Hasta ese día se habían reunido \$2.000 COP.');
    });

    testWidgets('los datos también se pueden ver como lista', (tester) async {
      await _open(tester);
      await tester.tap(find.text('Ver los datos'));
      await tester.pumpAndSettle();
      expect(find.text('El 1 de octubre'), findsOneWidget);
      expect(find.text('\$2.000 COP · 3 donaciones'), findsOneWidget);
    });

    testWidgets('con pocas donaciones explica por qué todavía no hay gráfico', (tester) async {
      await _open(tester, stats: _stats(total: '50000', donations: 2, periods: const []));
      expect(find.byKey(const Key('donation-chart')), findsNothing);
      expect(find.textContaining('nadie puede ver cuánto dio una sola persona'), findsOneWidget);
    });

    testWidgets('sin donaciones lo dice en palabras sencillas', (tester) async {
      await _open(tester, stats: _stats(total: '0', donations: 0, periods: const []));
      expect(find.textContaining('Todavía no hay donaciones'), findsOneWidget);
    });

    testWidgets('se actualiza sola: llega una donación y cambian el gráfico y lo recaudado', (tester) async {
      final h = await _open(tester);
      expect(find.textContaining('\$6.000 COP de \$20.000 COP'), findsOneWidget);

      h.api.routes['GET /public/campaigns/$_code'] = (_) => ok(_campaign(cleared: '700000'));
      h.api.routes['GET /public/campaigns/$_code/donation-stats'] = (_) => ok(_stats(total: '700000', donations: 7,
              periods: [
                {'from': '2026-10-01', 'to': '2026-10-01', 'amount': '200000', 'donations': 3},
                {'from': '2026-10-03', 'to': '2026-10-11', 'amount': '500000', 'donations': 4},
              ]));
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();

      expect(find.text('7'), findsOneWidget);
      expect(_detail(tester), contains('\$5.000 COP en 4 donaciones'));
      expect(find.textContaining('\$7.000 COP de \$20.000 COP'), findsOneWidget);
    });

    testWidgets('el botón de actualizar vuelve a consultar', (tester) async {
      final h = await _open(tester);
      final before = h.api.calls.where((c) => c.path.endsWith('/donation-stats')).length;
      await tester.tap(find.byKey(const Key('donation-stats-refresh')));
      await tester.pumpAndSettle();
      expect(h.api.calls.where((c) => c.path.endsWith('/donation-stats')).length, before + 1);
    });

    testWidgets('si falla la actualización, se quedan los últimos datos', (tester) async {
      final h = await _open(tester);
      h.api.routes['GET /public/campaigns/$_code/donation-stats'] = (_) => status(500);
      await tester.tap(find.byKey(const Key('donation-stats-refresh')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('donation-chart')), findsOneWidget);
      expect(find.text('No pudimos actualizar. Mostramos los últimos datos.'), findsOneWidget);
    });

    testWidgets('una causa terminada no se actualiza sola', (tester) async {
      final h = await _open(tester, campaign: _campaign(status: 'CLOSED'));
      final before = h.api.calls.length;
      await tester.pump(const Duration(seconds: 61));
      await tester.pumpAndSettle();
      expect(h.api.calls.length, before);
      expect(find.text('Se actualiza solo mientras tienes esta pantalla abierta.'), findsNothing);
    });

    testWidgets('una causa sin donaciones en dinero no muestra el gráfico', (tester) async {
      await _open(tester, campaign: _campaign(currency: null));
      expect(find.byKey(const Key('donation-stats')), findsNothing);
    });

    testWidgets('NEGATIVA: el gráfico no muestra datos de quien donó', (tester) async {
      await _open(tester);
      for (final banned in ['donorRef', 'intentId', 'acc-', '@']) {
        expect(find.textContaining(banned), findsNothing);
      }
    });
  });
}
