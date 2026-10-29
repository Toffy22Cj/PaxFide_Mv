import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/app/home_screen.dart';
import 'package:paxfide_mobile/core/network/api_response.dart';
import 'package:paxfide_mobile/features/campaigns/domain/campaign_search.dart';

import '../support/app_harness.dart';

final _list = find.byType(Scrollable).first;

Future<AppHarness> _donor(WidgetTester tester, {void Function(AppHarness h)? setup}) async {
  final h = AppHarness();
  setup?.call(h);
  h.saveToken('jwt');
  await h.start(tester, beforeSession: () async => h.api.enqueue(meResponse(roles: const [])));
  return h;
}

CampaignSummary _c(String status, String end) =>
    CampaignSummary(publicCode: 'P', title: 'T', organizationName: 'O', status: status, endDate: end);

void main() {
  test('saludo por la hora y «cierra pronto» en 7 días o menos', () {
    expect(greetingFor(8), 'Buenos días');
    expect(greetingFor(15), 'Buenas tardes');
    expect(greetingFor(21), 'Buenas noches');
    final now = DateTime.utc(2026, 10, 29);
    expect(isClosingSoon(_c('OPEN', '2026-11-03T00:00:00Z'), now), isTrue);
    expect(isClosingSoon(_c('OPEN', '2026-11-30T00:00:00Z'), now), isFalse);
    expect(isClosingSoon(_c('CLOSED', '2026-11-01T00:00:00Z'), now), isFalse);
    expect(isClosingSoon(_c('OPEN', '2026-10-01T00:00:00Z'), now), isFalse);
  });

  testWidgets('sin nombre: aviso «Completa tu perfil», que se puede ocultar', (tester) async {
    await _donor(tester);
    expect(find.byKey(const Key('home.profileNudge')), findsOneWidget);
    await tester.tap(find.byKey(const Key('home.profileNudge.hide')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home.profileNudge')), findsNothing);
  });

  testWidgets('con nombre: el saludo lo lleva y el avatar las iniciales', (tester) async {
    await _donor(
      tester,
      setup: (h) =>
          h.api.routes['GET /account/profile'] = (_) =>
              const ApiResponse(statusCode: 200, data: {'email': 'ana@demo', 'givenName': 'Ana', 'familyName': 'Ríos'}),
    );
    expect(find.textContaining(', Ana'), findsOneWidget);
    expect(find.text('AR'), findsOneWidget);
    expect(find.byKey(const Key('home.profileNudge')), findsNothing);
  });

  testWidgets('Seguir una donación: sin código avisa; con código abre el seguimiento sin ponerlo en la ruta', (
    tester,
  ) async {
    final h = await _donor(tester);
    await tester.tap(find.byKey(const Key('home.track.submit')));
    await tester.pumpAndSettle();
    expect(find.text('Este campo es obligatorio.'), findsOneWidget);
    h.api.routes['GET /donations/tracking'] = (_) => const ApiResponse(statusCode: 404, data: {});
    await tester.enterText(find.byKey(const Key('home.track.code')), 'TRK-123');
    await tester.tap(find.byKey(const Key('home.track.submit')));
    await tester.pumpAndSettle();
    expect(h.location, '/home');
    expect(h.api.calls.any((c) => c.path.startsWith('/donations/tracking')), isTrue);
  });

  testWidgets('Tus donaciones: hasta 3, con fecha, organización y medio de pago', (tester) async {
    await _donor(
      tester,
      setup: (h) => h.api.routes['GET /account/donations'] = (_) => ApiResponse(
        statusCode: 200,
        data: {
          'items': [
            for (var i = 0; i < 5; i++)
              {
                'campaignTitle': 'Abrigo $i',
                'amount': '5000000',
                'currency': 'COP',
                'status': 'CONFIRMED',
                'createdAt': '2026-10-01T12:00:00Z',
                'organizationName': 'Fundación Demo',
                'paymentMethod': 'GATEWAY',
                'publicCode': 'PUB$i',
              },
          ],
        },
      ),
    );
    await tester.scrollUntilVisible(find.byKey(const Key('home.donation.2')), 200, scrollable: _list);
    expect(find.byKey(const Key('home.donation.3')), findsNothing);
    expect(find.textContaining('Fundación Demo · Pasarela de pago'), findsWidgets);
    expect(find.text('Ver convocatoria'), findsWidgets);
  });

  testWidgets('«Cierran pronto» cuando alguna cierra en 7 días o menos', (tester) async {
    final soon = DateTime.now().toUtc().add(const Duration(days: 3)).toIso8601String();
    await _donor(
      tester,
      setup: (h) => h.api.routes['GET /public/campaigns'] = (_) => ApiResponse(
        statusCode: 200,
        data: {
          'items': [
            {'publicCode': 'A', 'title': 'Lejana', 'organizationName': 'O', 'status': 'OPEN', 'endDate': '2099-01-01'},
            {'publicCode': 'B', 'title': 'Próxima', 'organizationName': 'O', 'status': 'OPEN', 'endDate': soon},
          ],
        },
      ),
    );
    await tester.scrollUntilVisible(find.byKey(const Key('home.campaign.B')), 200, scrollable: _list);
    expect(find.text('Cierran pronto'), findsOneWidget);
    expect(find.byKey(const Key('home.campaign.A')), findsNothing);
  });
}
