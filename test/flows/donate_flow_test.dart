import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/core/errors/app_exceptions.dart';
import 'package:paxfide_mobile/core/network/api_response.dart';
import 'package:paxfide_mobile/core/network/credential_mode.dart';
import 'package:paxfide_mobile/features/donations/domain/donation_flow.dart';

import '../support/app_harness.dart';

ApiResponse campaign({String status = 'OPEN', List<String> methods = const ['GATEWAY'], String? currency = 'COP'}) =>
    ApiResponse(
      statusCode: 200,
      data: {
        'organizationName': 'Fundación Demo',
        'title': 'Abrigo',
        'status': status,
        'startDate': '2026-10-01T00:00:00Z',
        'endDate': '2026-12-01T00:00:00Z',
        'acceptedDonationTypes': ['MONETARY'],
        'acceptedPaymentMethods': methods,
        'currency': ?currency,
      },
    );

const createPath = 'POST /public/campaigns/PUB1/donation-intents';
const created = ApiResponse(
  statusCode: 201,
  data: {'intentId': 'int-1', 'statusToken': 'TOKEN-SECRETO', 'paymentRedirectUrl': '/demo/checkout/sim_abc'},
);

void main() {
  Future<AppHarness> openCampaign(WidgetTester tester, {ApiResponse? c, bool loggedIn = false}) async {
    final h = AppHarness();
    h.api.routes['GET /public/campaigns/PUB1'] = (_) => c ?? campaign();
    if (loggedIn) h.saveToken('jwt');
    await h.start(tester, beforeSession: () async => loggedIn ? h.api.enqueue(meResponse(roles: const [])) : null);
    await h.services.router.openDeepLink(h.services.deepLinkParser.parse(Uri.parse('$testOrigin/c/PUB1')));
    await tester.pumpAndSettle();
    return h;
  }

  Future<void> donate(WidgetTester tester, String amount) async {
    await tester.ensureVisible(find.byKey(const Key('donate.open')));
    await tester.tap(find.byKey(const Key('donate.open')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('donate.amount')), amount);
    await tester.tap(find.byKey(const Key('donate.submit')));
    await tester.pumpAndSettle();
  }

  Iterable<dynamic> creates(AppHarness h) =>
      h.api.calls.where((c) => c.method == 'POST' && c.path == '/public/campaigns/PUB1/donation-intents');

  test('importe: dígitos en unidades enteras, sin signo ni decimales', () {
    expect(isValidAmount('4000000'), isTrue);
    for (final bad in ['', '0', '-5', '1.5', '1e3', ' 10', '0010']) {
      expect(isValidAmount(bad), isFalse, reason: bad);
    }
  });

  testWidgets('"Donar" solo con convocatoria abierta, dinero, moneda y pasarela', (tester) async {
    for (final c in [campaign(status: 'CLOSED'), campaign(methods: const []), campaign(currency: null)]) {
      await openCampaign(tester, c: c);
      expect(find.byKey(const Key('donate.open')), findsNothing);
    }
    await openCampaign(tester);
    expect(find.byKey(const Key('donate.open')), findsOneWidget);
  });

  testWidgets('sin sesión: CV-11 sin JWT y con Command-Id; consulta manual con Intent-Token; nada se guarda', (
    tester,
  ) async {
    final h = await openCampaign(tester);
    h.api.routes[createPath] = (_) => created;
    var statusCalls = 0;
    h.api.routes['GET /public/donation-intents/int-1'] = (_) {
      statusCalls++;
      return statusCalls == 1
          ? const ApiResponse(statusCode: 200, data: {'status': 'PENDING'})
          : const ApiResponse(statusCode: 200, data: {'status': 'CONFIRMED', 'trackingCode': 'CODIGO-NUEVO'});
    };
    await donate(tester, '4000000');

    final post = creates(h).single;
    expect(post.credentialMode, CredentialMode.none);
    expect(post.body, {'amount': '4000000', 'currency': 'COP', 'paymentMethod': 'GATEWAY'});
    expect(post.headers['Command-Id'], matches(RegExp(r'^[0-9a-f-]{36}$')));
    expect(find.text('$testOrigin/demo/checkout/sim_abc'), findsOneWidget);
    expect(find.byKey(const Key('donate.simulated')), findsOneWidget);

    await tester.pump(const Duration(seconds: 30));
    expect(statusCalls, 0, reason: 'sin polling: la consulta es manual');

    await tester.tap(find.byKey(const Key('donate.refresh')));
    await tester.pumpAndSettle();
    expect(find.text('Estado: Pago pendiente'), findsOneWidget);
    final get = h.api.calls.lastWhere((c) => c.path == '/public/donation-intents/int-1');
    expect(get.headers['Intent-Token'], 'TOKEN-SECRETO');
    expect(get.credentialMode, CredentialMode.none);
    expect(get.path, isNot(contains('TOKEN')));

    await tester.tap(find.byKey(const Key('donate.refresh')));
    await tester.pumpAndSettle();
    expect(find.text('CODIGO-NUEVO'), findsOneWidget);

    // Ni el Intent-Token ni el código llegan a ningún almacén, ruta o URL.
    final stored = h.secure.values.values.join();
    expect(stored, isNot(contains('TOKEN-SECRETO')));
    expect(stored, isNot(contains('CODIGO-NUEVO')));
    expect(h.services.router.stack.join(), isNot(contains('TOKEN')));
    for (final c in h.api.calls) {
      expect(c.path, isNot(contains('TOKEN-SECRETO')));
    }
  });

  testWidgets('con sesión: la donación va con el JWT (queda ligada a la cuenta)', (tester) async {
    final h = await openCampaign(tester, loggedIn: true);
    h.api.routes[createPath] = (_) => created;
    await donate(tester, '1000');
    expect(creates(h).single.credentialMode, CredentialMode.jwt);
  });

  testWidgets('timeout → "no pudimos confirmar"; Reintentar usa el mismo Command-Id', (tester) async {
    final h = await openCampaign(tester);
    var n = 0;
    h.api.routes[createPath] = (_) => n++ == 0 ? const NetworkTimeoutException() : created;
    await donate(tester, '1000');
    expect(find.byKey(const Key('donate.ambiguous')), findsOneWidget);
    expect(creates(h).length, 1, reason: 'nunca reintenta solo');
    await tester.tap(find.byKey(const Key('donate.submit')));
    await tester.pumpAndSettle();
    final ids = creates(h).map((c) => c.headers['Command-Id']).toList();
    expect(ids, hasLength(2));
    expect(ids[0], ids[1]);
    expect(find.byKey(const Key('donate.checkout')), findsOneWidget);
  });

  testWidgets('409 → rechazada; un nuevo intento usa otro Command-Id', (tester) async {
    final h = await openCampaign(tester);
    var n = 0;
    h.api.routes[createPath] = (_) => n++ == 0 ? const ApiResponse(statusCode: 409) : created;
    await donate(tester, '1000');
    expect(find.byKey(const Key('donate.rejected')), findsOneWidget);
    await tester.tap(find.byKey(const Key('donate.submit')));
    await tester.pumpAndSettle();
    final ids = creates(h).map((c) => c.headers['Command-Id']).toList();
    expect(ids[0], isNot(ids[1]));
  });

  testWidgets('importe inválido → no se envía nada', (tester) async {
    final h = await openCampaign(tester);
    await donate(tester, '10,5');
    expect(creates(h), isEmpty);
    expect(find.textContaining('unidades enteras'), findsOneWidget);
  });
}
