import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/core/network/credential_mode.dart';
import 'package:paxfide_mobile/features/auth/data/me_gateway.dart';
import 'package:paxfide_mobile/features/campaigns/data/campaign_api.dart';
import 'package:paxfide_mobile/features/campaigns/presentation/donation_stats_card.dart';
import 'package:paxfide_mobile/shared/money.dart';

import '../../support/app_harness.dart';
import '../../support/fakes.dart';

const _code = 'CV-ABCDEFGHJK';
const _ref = 'C1';
const _statsRoute = 'GET /organizations/org-1/campaigns/$_ref/donation-stats';

/// Fecha `AAAA-MM-DD` a [offset] días de hoy.
String _d(int offset) {
  final t = DateTime.now().add(Duration(days: offset));
  return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
}

DateTime _date(int offset) => DateTime.parse(_d(offset));

/// La causa empezó hace 9 días (hoy es el día 10) y dura 45.
Map<String, dynamic> _campaign({String status = 'OPEN', String cleared = '600000', String? currency = 'COP'}) {
  final start = DateTime.now().toUtc().subtract(const Duration(days: 9));
  return {
    'organizationName': 'Fundación Demo',
    'title': 'Abrigo para el invierno',
    'status': status,
    'startDate': start.toIso8601String(),
    'endDate': start.add(const Duration(days: 44)).toIso8601String(),
    'acceptedDonationTypes': ['MONETARY'],
    'acceptedPaymentMethods': ['GATEWAY'],
    'currency': ?currency,
    'targetAmount': ?(currency == null ? null : '1000000'),
    'clearedAmount': ?(currency == null ? null : cleared),
  };
}

Map<String, dynamic> _stats({String total = '600000', int donations = 4, List<Map<String, dynamic>>? days}) => {
      'currency': 'COP',
      'targetAmount': '1000000',
      'totalAmount': total,
      'donations': donations,
      'timeZone': 'America/Bogota',
      'days': days ??
          [
            {'date': _d(-9), 'amount': '200000', 'donations': 3},
            {'date': _d(-2), 'amount': '400000', 'donations': 1},
          ],
      'asOf': '2026-10-11T00:00:00Z',
    };

/// El administrador abre Predicción y elige la causa: ahí está el gráfico.
Future<Harness> _open(WidgetTester tester, {Map<String, dynamic>? campaign, Map<String, dynamic>? stats}) async {
  final h = Harness(token: 't', meResult: const MeSucceeded(administrator));
  h.api.routes['GET /organizations/org-1/campaigns'] = (_) => ok({
        'items': [
          {'campaignRef': _ref, 'publicCode': _code, 'title': 'Abrigo para el invierno', 'status': 'OPEN'},
        ],
      });
  h.api.routes['GET /organizations/org-1/campaigns/$_ref/prediction'] = (_) => ok({
        'kind': 'ESTIMATE',
        'modelVersion': 'v1',
        'warning': 'x',
        'available': false,
        'unavailableReason': 'OUTSIDE_TRAINED_RANGE',
        'asOf': '2026-10-11T00:00:00Z',
      });
  h.api.routes['GET /organizations/org-1/campaigns/$_ref/prediction/history'] = (_) => status(500);
  h.api.routes['GET /public/campaigns/$_code'] = (_) => ok(campaign ?? _campaign());
  h.api.routes[_statsRoute] = (_) => ok(stats ?? _stats());
  await h.pump(tester, initialRoute: '/prediction', size: const Size(400, 2400));
  await tester.tap(find.byKey(const Key('prediction-choice-$_ref')));
  await tester.pumpAndSettle();
  return h;
}

String _textOf(WidgetTester tester, Key key) => tester
    .widgetList<Text>(find.descendant(of: find.byKey(key), matching: find.byType(Text)))
    .map((t) => t.data)
    .join(' | ');

void main() {
  group('datos y formatos', () {
    test('lee la estadística por día de la organización, con sesión', () async {
      final api = FakeApiClient();
      api.routes[_statsRoute] = (_) => ok(_stats());
      final s = await CampaignApi(api).donationStats('org-1', _ref);
      expect(api.calls.single.credentialMode, CredentialMode.jwt);
      expect(s.totalAmount, 600000);
      expect(s.targetAmount, 1000000);
      expect(s.donations, 4);
      expect(s.days.map((d) => '${d.date}:${d.amount}/${d.donations}'), ['${_d(-9)}:200000/3', '${_d(-2)}:400000/1']);
    });

    test('la serie tiene todos los días de la causa, también los que no tuvieron donaciones', () {
      final stats = DonationStats(currency: 'COP', targetAmount: 1000000, totalAmount: 600000, donations: 4, days: [
        DonationDay(date: _d(-9), amount: 200000, donations: 3),
        DonationDay(date: _d(-2), amount: 400000, donations: 1),
      ]);
      final c = _campaign();
      final s = DailySeries.of(stats, startDate: c['startDate'] as String, endDate: c['endDate'] as String);
      expect(s.length, 10);
      expect(s.amounts, [200000, 0, 0, 0, 0, 0, 0, 400000, 0, 0]);
      expect(s.cumulative.last, 600000);
      expect(s.cumulative[6], 200000);
      expect(s.bestDay, 7);
      expect(s.lastWithDonations, 7);
    });

    test('formatos cortos y porcentajes', () {
      expect(formatCompact(140000000, 'COP'), '\$1,4 M');
      expect(formatCompact(50000000, 'COP'), '\$500 mil');
      expect(formatCompact(2000000000, 'COP'), '\$20 M');
      expect(formatCompact(0, 'COP'), '\$0');
      expect(percentText(0.07), '7 %');
      expect(percentText(0.004), 'menos de 1 %');
      expect(roundToWholeUnits(46666667, 'COP'), 46666700);
      expect(niceScale(1400000).max, 1500000);
      expect(niceScale(1400000).step, 500000);
    });
  });

  group('sección Predicción (administrador)', () {
    testWidgets('muestra las cifras clave', (tester) async {
      await _open(tester);
      expect(_textOf(tester, const Key('stat-total')), contains('\$6.000 COP'));
      expect(_textOf(tester, const Key('stat-percent')), '60 % | de la meta');
      expect(_textOf(tester, const Key('stat-donations')), '4 | donaciones');
      expect(_textOf(tester, const Key('stat-average')), '\$1.500 COP | promedio por donación');
      expect(_textOf(tester, const Key('stat-best')), '${shortDay(_date(-2))} | mejor día: \$4.000 COP');
      expect(_textOf(tester, const Key('stat-day')), 'Día 10 de 45 | quedan 35 días');
    });

    testWidgets('dibuja los dos gráficos y explica el último día con donaciones', (tester) async {
      await _open(tester);
      expect(find.byKey(const Key('donation-chart')), findsOneWidget);
      expect(find.byKey(const Key('donation-daily-chart')), findsOneWidget);
      expect(_textOf(tester, const Key('donation-stats-detail')),
          'El ${longDay(_date(-2))} llegaron \$4.000 COP en 1 donación. Total reunido hasta ese día: \$6.000 COP '
          '(60 % de la meta).');
    });

    testWidgets('tocar un día sin donaciones lo dice y da el total hasta ese día', (tester) async {
      await _open(tester);
      final r = tester.getRect(find.byKey(const Key('donation-daily-chart')));
      final plot = r.width - DonationCharts.gutter;
      // día 5 de 10 (índice 4)
      await tester.tapAt(Offset(r.left + DonationCharts.gutter + plot * 0.45, r.center.dy));
      await tester.pumpAndSettle();
      expect(_textOf(tester, const Key('donation-stats-detail')),
          'El ${longDay(_date(-5))} no llegaron donaciones. Total reunido hasta ese día: \$2.000 COP (20 % de la meta).');
    });

    testWidgets('una sola donación ya muestra el gráfico', (tester) async {
      await _open(tester,
          stats: _stats(total: '50000', donations: 1, days: [{'date': _d(0), 'amount': '50000', 'donations': 1}]));
      expect(find.byKey(const Key('donation-chart')), findsOneWidget);
      expect(_textOf(tester, const Key('donation-stats-detail')), contains('llegaron \$500 COP en 1 donación'));
    });

    testWidgets('si la meta queda muy por encima, lo dice en texto en lugar de aplastar la línea', (tester) async {
      await _open(tester,
          stats: _stats(total: '70000', donations: 3, days: [{'date': _d(0), 'amount': '70000', 'donations': 3}]));
      expect(find.text('La meta es \$10.000 COP; va en el 7 %.'), findsOneWidget);
    });

    testWidgets('con la meta cerca, no hace falta la nota', (tester) async {
      await _open(tester);
      expect(find.byKey(const Key('donation-goal-note')), findsNothing);
    });

    testWidgets('los datos también se pueden ver día por día', (tester) async {
      await _open(tester);
      await tester.tap(find.text('Ver los datos día por día'));
      await tester.pumpAndSettle();
      expect(find.text(longDay(_date(-9))), findsOneWidget);
      expect(find.text('\$2.000 COP · 3 donaciones'), findsOneWidget);
      expect(find.text('\$4.000 COP · 1 donación'), findsOneWidget);
    });

    testWidgets('sin donaciones lo dice en palabras sencillas', (tester) async {
      await _open(tester, stats: _stats(total: '0', donations: 0, days: const []));
      expect(find.textContaining('Todavía no hay donaciones'), findsOneWidget);
      expect(find.byKey(const Key('donation-chart')), findsNothing);
    });

    testWidgets('se actualiza sola: llega una donación y cambia el gráfico', (tester) async {
      final h = await _open(tester);

      h.api.routes[_statsRoute] = (_) => ok(_stats(total: '700000', donations: 5, days: [
            {'date': _d(-9), 'amount': '200000', 'donations': 3},
            {'date': _d(-2), 'amount': '400000', 'donations': 1},
            {'date': _d(0), 'amount': '100000', 'donations': 1},
          ]));
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();

      expect(_textOf(tester, const Key('stat-donations')), '5 | donaciones');
      expect(_textOf(tester, const Key('donation-stats-detail')), contains('llegaron \$1.000 COP en 1 donación'));
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
      h.api.routes[_statsRoute] = (_) => status(500);
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

  group('NEGATIVA: el detalle público de la causa no tiene el gráfico', () {
    Future<Harness> openPublic(WidgetTester tester, Harness h) async {
      h.api.routes['GET /public/campaigns/$_code'] = (_) => ok(_campaign());
      h.api.routes['GET /public/campaigns/$_code/narrative'] = (_) => status(404);
      await h.pump(tester, initialRoute: '/c/$_code', size: const Size(400, 1800));
      return h;
    }

    testWidgets('un donante no ve el gráfico ni se consulta', (tester) async {
      final h = await openPublic(tester, Harness(token: 't', meResult: const MeSucceeded(donor)));
      expect(find.text('Abrigo para el invierno'), findsWidgets);
      expect(find.byKey(const Key('donation-stats')), findsNothing);
      expect(h.api.calls.where((c) => c.path.endsWith('/donation-stats')), isEmpty);
    });

    testWidgets('sin sesión tampoco', (tester) async {
      final h = await openPublic(tester, Harness());
      expect(find.byKey(const Key('donation-stats')), findsNothing);
      expect(h.api.calls.where((c) => c.path.endsWith('/donation-stats')), isEmpty);
    });
  });
}
