import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/core/errors/app_exceptions.dart';
import 'package:paxfide_mobile/core/network/credential_mode.dart';
import 'package:paxfide_mobile/core/offline/outbox_status.dart';
import 'package:paxfide_mobile/features/auth/data/login_gateway.dart';
import 'package:paxfide_mobile/features/auth/data/me_gateway.dart';

import '../support/app_harness.dart';
import '../support/fakes.dart';

const _code = 'PUB1';

Map<String, dynamic> _campaign({String status = 'OPEN'}) => {
      'organizationName': 'Fundación Demo',
      'title': 'Abrigo para el invierno',
      'status': status,
      'startDate': '2026-10-08T00:00:00Z',
      'endDate': '2026-11-20T00:00:00Z',
      'acceptedDonationTypes': ['MONETARY'],
      'acceptedPaymentMethods': ['GATEWAY'],
      'currency': 'COP',
      'targetAmount': '2000000000',
      'clearedAmount': '100000000',
    };

Map<String, dynamic> _asset(String status) => {
      'assetRef': 'AS-1',
      'lifecycleStatus': status,
      'currentCustodianRef': 'bodega',
      'currentLocation': 'centro',
      'quantity': '10.0000',
      'unitOfMeasure': 'UNITS',
    };

void main() {
  group('convocatorias y donar', () {
    testWidgets('la home lista las convocatorias públicas y abre el detalle', (tester) async {
      final h = Harness(token: 't');
      h.api.routes['GET /public/campaigns'] = (_) => ok({
            'items': [
              {
                'publicCode': _code,
                'title': 'Abrigo para el invierno',
                'status': 'OPEN',
                'endDate': '2026-11-20T00:00:00Z',
                'acceptedDonationTypes': ['MONETARY'],
                'currency': 'COP',
                'targetAmount': '2000000000',
                'clearedAmount': '100000000',
              },
            ],
          });
      h.api.routes['GET /public/campaigns/$_code'] = (_) => ok(_campaign());
      h.api.routes['GET /public/campaigns/$_code/narrative'] =
          (_) => ok({'status': 'PENDING', 'content': null, 'source': null, 'facts': null}, 202);
      await h.pump(tester);
      expect(find.text('\$1.000.000 COP de \$20.000.000 COP'), findsOneWidget);

      await tester.tap(find.byKey(const Key('campaign-$_code')));
      await tester.pumpAndSettle();
      expect(currentRoute(tester), '/c/$_code');
      expect(find.byKey(const Key('campaign-detail')), findsOneWidget);
      expect(find.text('Estamos preparando la historia de esta causa.'), findsOneWidget);
      expect(find.byKey(const Key('donate-open')), findsOneWidget);
    });

    testWidgets('donar: importe en pesos → unidades mínimas, Command-Id y JWT con sesión', (tester) async {
      final h = Harness(token: 't');
      h.api.routes['GET /public/campaigns/$_code'] = (_) => ok(_campaign());
      h.api.routes['GET /public/campaigns/$_code/narrative'] = (_) => status(404);
      h.api.routes['POST /public/campaigns/$_code/donation-intents'] =
          (_) => ok({'intentId': 'I-1', 'statusToken': 'tok', 'paymentRedirectUrl': '/demo/checkout/S1'}, 201);
      h.api.routes['GET /public/donation-intents/I-1'] = (_) => ok({'status': 'CONFIRMED', 'trackingCode': 'TRK'});
      await h.pump(tester, initialRoute: '/c/$_code');

      await tester.tap(find.byKey(const Key('donate-open')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('donate-amount')), '1500,5');
      await tester.pump();
      expect(find.text('Vas a donar \$1.500,50 COP.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('donate-submit')));
      await tester.pumpAndSettle();

      final post = h.api.calls.singleWhere((c) => c.method == 'POST');
      expect(post.body, {'amount': '150050', 'currency': 'COP', 'paymentMethod': 'GATEWAY'});
      expect(post.headers['Command-Id'], matches(RegExp(r'^[0-9a-f-]{36}$')));
      expect(post.credentialMode, CredentialMode.jwt);
      expect(find.byKey(const Key('donate-checkout')), findsOneWidget);

      await tester.tap(find.byKey(const Key('donate-refresh')));
      await tester.pumpAndSettle();
      final query = h.api.calls.last;
      expect(query.headers['Intent-Token'], 'tok');
      expect(query.path, '/public/donation-intents/I-1');
      expect(find.byKey(const Key('donate-tracking-code')), findsOneWidget);
    });

    testWidgets('donar: un fallo ambiguo reintenta con el MISMO Command-Id', (tester) async {
      final h = Harness(token: 't');
      h.api.routes['GET /public/campaigns/$_code'] = (_) => ok(_campaign());
      h.api.routes['GET /public/campaigns/$_code/narrative'] = (_) => status(404);
      await h.pump(tester, initialRoute: '/c/$_code');
      await tester.tap(find.byKey(const Key('donate-open')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('donate-amount')), '1000');
      h.api.enqueue(const NetworkTimeoutException());
      await tester.tap(find.byKey(const Key('donate-submit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('donate-ambiguous')), findsOneWidget);

      h.api.enqueue(ok({'intentId': 'I-1', 'statusToken': 'tok'}, 201));
      await tester.tap(find.byKey(const Key('donate-submit')));
      await tester.pumpAndSettle();
      final posts = h.api.calls.where((c) => c.method == 'POST').toList();
      expect(posts, hasLength(2));
      expect(posts[0].headers['Command-Id'], posts[1].headers['Command-Id']);
    });

    testWidgets('NEGATIVA: una convocatoria cerrada no ofrece donar', (tester) async {
      final h = Harness();
      h.api.routes['GET /public/campaigns/$_code'] = (_) => ok(_campaign(status: 'CLOSED'));
      h.api.routes['GET /public/campaigns/$_code/narrative'] = (_) => status(404);
      await h.pump(tester, initialRoute: '/c/$_code');
      expect(find.byKey(const Key('campaign-detail')), findsOneWidget);
      expect(find.byKey(const Key('donate-open')), findsNothing);
    });
  });

  group('seguimiento', () {
    void trackingRoutes(Harness h) {
      h.api.routes['GET /donations/tracking'] = (_) => ok({
            'status': 'ACTIVA',
            'financialSnapshot': {
              'currency': 'COP',
              'originalAmount': 40000000,
              'clearedAmount': 40000000,
              'pendingAllocationAmount': 0,
              'confirmedAllocationAmount': 0,
              'refundedAmount': 0,
            },
            'logistics': <Object>[],
          });
      h.api.routes['GET /donations/tracking/narrative'] = (_) => ok({'status': 'AVAILABLE', 'content': 'Relato', 'source': 'FALLBACK_TEMPLATE'});
      h.api.routes['GET /donations/tracking/integrity'] = (_) => ok({
            'batches': [
              {
                'anchorStatus': 'ANCHORED',
                'merkleRoot': 'abc',
                'transactionHash': '0x1',
                'network': 'ganache-local',
                'confirmedBlockNumber': 2,
                'eventsOfThisDonation': 1,
                'verification': {'result': 'MATCH'},
              },
            ],
            'unanchoredEvents': 0,
            'checkedAt': '2026-10-08T00:00:00Z',
          });
    }

    testWidgets('código válido: dinero, relato e integridad; el código solo va en Authorization', (tester) async {
      final h = Harness();
      trackingRoutes(h);
      await h.pump(tester, initialRoute: '/tracking');
      await tester.enterText(find.byKey(const Key('tracking-code')), 'SECRETO');
      await tester.tap(find.byKey(const Key('tracking-submit')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('tracking-content')), findsOneWidget);
      expect(find.text('Registro protegido'), findsOneWidget);
      expect(find.text('Relato'), findsOneWidget);
      for (final c in h.api.calls) {
        expect(c.credentialMode, CredentialMode.tracking);
        expect(c.headers['Authorization'], 'Bearer SECRETO');
        expect(c.path, isNot(contains('SECRETO')));
      }
      expect(currentRoute(tester), '/tracking');
    });

    testWidgets('código inválido: un único mensaje y la sesión no cambia', (tester) async {
      final h = Harness(token: 't');
      h.api.routes['GET /donations/tracking'] = (_) => status(401);
      await h.pump(tester, initialRoute: '/tracking');
      final before = h.session.value;
      await tester.enterText(find.byKey(const Key('tracking-code')), 'MALO');
      await tester.tap(find.byKey(const Key('tracking-submit')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Ese código no es válido'), findsOneWidget);
      expect(h.session.value, before);
      expect(h.tokenStore.clears, 0);
    });
  });

  group('operador y Outbox', () {
    testWidgets('despachar: entrada PENDING guardada antes de enviar; 2xx → se retira', (tester) async {
      final h = Harness(token: 't', meResult: const MeSucceeded(fieldOperator));
      var dispatched = false;
      h.api.routes['GET /physical-assets/AS-1'] = (_) => ok(_asset(dispatched ? 'DISPATCHED' : 'REGISTERED'));
      h.api.routes['POST /physical-assets/AS-1/dispatch'] = (call) {
        expect(h.outboxStore.items.values.single.status, OutboxStatus.inFlight);
        dispatched = true;
        return ok({'assetRef': 'AS-1', 'status': 'DISPATCHED'});
      };
      await h.pump(tester, initialRoute: '/assets/AS-1');
      await tester.tap(find.byKey(const Key('asset-action')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('form-carrierRef')), 'transportista-1');
      await tester.tap(find.byKey(const Key('form-submit')));
      await tester.pumpAndSettle();

      final post = h.api.calls.singleWhere((c) => c.method == 'POST');
      expect(post.body, {'carrierRef': 'transportista-1'});
      expect(post.headers['Command-Id'], isNotNull);
      expect(h.outboxStore.savedIds, hasLength(1));
      expect(h.outboxStore.items, isEmpty);
      expect(find.text('En camino'), findsWidgets);
    });

    testWidgets('timeout → AMBIGUOUS persistido; "Verificar estado" lo confirma sin reenviar', (tester) async {
      final h = Harness(token: 't', meResult: const MeSucceeded(fieldOperator));
      var observed = 'REGISTERED';
      h.api.routes['GET /physical-assets/AS-1'] = (_) => ok(_asset(observed));
      h.api.routes['POST /physical-assets/AS-1/dispatch'] = (_) {
        observed = 'DISPATCHED'; // el servidor la aplicó, pero la respuesta se pierde
        throw const NetworkTimeoutException();
      };
      await h.pump(tester, initialRoute: '/assets/AS-1');
      await tester.tap(find.byKey(const Key('asset-action')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('form-carrierRef')), 'transportista-1');
      await tester.tap(find.byKey(const Key('form-submit')));
      await tester.pumpAndSettle();

      final entry = h.outboxStore.items.values.single;
      expect(entry.status, OutboxStatus.ambiguous);
      expect(entry.accountId, fieldOperator.accountId);
      expect(find.byKey(Key('outbox-entry-${entry.commandId}')), findsOneWidget);
      expect(find.byKey(const Key('asset-action')), findsNothing);

      await tester.tap(find.byKey(Key('outbox-verify-${entry.commandId}')));
      await tester.pumpAndSettle();
      expect(h.outboxStore.items, isEmpty);
      expect(h.api.calls.where((c) => c.method == 'POST'), hasLength(1));
    });

    testWidgets('NEGATIVA: un donante no ve acciones sobre el activo', (tester) async {
      final h = Harness(token: 't');
      h.api.routes['GET /physical-assets/AS-1'] = (_) => ok(_asset('REGISTERED'));
      await h.pump(tester, initialRoute: '/assets/AS-1');
      expect(find.byKey(const Key('asset-detail')), findsOneWidget);
      expect(find.byKey(const Key('asset-action')), findsNothing);
    });

    testWidgets('403 del activo es estado de pantalla, nunca redirect', (tester) async {
      final h = Harness(token: 't', meResult: const MeSucceeded(fieldOperator));
      h.api.routes['GET /physical-assets/AS-1'] = (_) => status(403);
      await h.pump(tester, initialRoute: '/assets/AS-1');
      expect(find.byKey(const Key('asset-forbidden')), findsOneWidget);
      expect(currentRoute(tester), '/assets/AS-1');
    });

    testWidgets('/operator lista los activos de la organización de /me', (tester) async {
      final h = Harness(token: 't', meResult: const MeSucceeded(fieldOperator));
      h.api.routes['GET /organizations/org-1/physical-assets'] = (_) => ok({
            'items': [_asset('DISPATCHED')..remove('currentLocation')],
          });
      await h.pump(tester, initialRoute: '/operator');
      expect(find.byKey(const Key('operator-asset-AS-1')), findsOneWidget);
      expect(find.textContaining('En camino'), findsOneWidget);
    });
  });

  group('escáner y deep links', () {
    testWidgets('enlace pegado de un activo sin sesión: login y, tras entrar, abre el activo (R2)', (tester) async {
      final h = Harness(
        loginResult: const LoginSucceeded('jwt'),
        meResult: const MeSucceeded(fieldOperator),
        publicOrigin: Uri.parse('http://localhost:3000'),
      );
      h.api.routes['GET /physical-assets/AS-1'] = (_) => ok(_asset('REGISTERED'));
      await h.pump(tester);
      await tester.tap(find.byKey(const Key('login-scan')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('scanner-paste')), 'http://localhost:3000/assets/AS-1');
      await tester.tap(find.byKey(const Key('scanner-paste-open')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('login-submit')), findsOneWidget);
      expect(h.services.pendingIntents.hasPending, isTrue);

      await fillLogin(tester);
      expect(currentRoute(tester), '/assets/AS-1');
      expect(find.byKey(const Key('asset-detail')), findsOneWidget);
      expect(h.services.pendingIntents.hasPending, isFalse);
    });

    testWidgets('NEGATIVA: un login fallido descarta la intención (DDM-12)', (tester) async {
      final h = Harness(loginResult: const LoginRejected(), publicOrigin: Uri.parse('http://localhost:3000'));
      await h.pump(tester);
      await tester.tap(find.byKey(const Key('login-scan')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('scanner-paste')), 'http://localhost:3000/assets/AS-1');
      await tester.tap(find.byKey(const Key('scanner-paste-open')));
      await tester.pumpAndSettle();
      await fillLogin(tester);
      expect(h.services.pendingIntents.hasPending, isFalse);
    });

    testWidgets('NEGATIVA: un enlace de otro host no navega', (tester) async {
      final h = Harness(publicOrigin: Uri.parse('https://paxfide.example'));
      await h.pump(tester);
      await tester.tap(find.byKey(const Key('login-scan')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('scanner-paste')), 'https://evil.example/assets/AS-1');
      await tester.tap(find.byKey(const Key('scanner-paste-open')));
      await tester.pumpAndSettle();
      expect(currentRoute(tester), '/login');
      expect(find.textContaining('no es de PaxFide'), findsOneWidget);
    });
  });

  group('registro', () {
    testWidgets('crear cuenta → POST /auth/register sin Command-Id → ir al login', (tester) async {
      final h = Harness();
      h.api.routes['POST /auth/register'] = (_) => ok({'accountId': 'A', 'status': 'ACTIVE'}, 201);
      await h.pump(tester, initialRoute: '/register');
      await tester.enterText(find.byKey(const Key('register-email')), 'ana@correo.co');
      await tester.enterText(find.byKey(const Key('register-password')), 'una-clave-larga');
      await tester.enterText(find.byKey(const Key('register-confirm')), 'una-clave-larga');
      await tester.tap(find.byKey(const Key('register-submit')));
      await tester.pumpAndSettle();
      final call = h.api.calls.single;
      expect(call.body, {'email': 'ana@correo.co', 'password': 'una-clave-larga'});
      expect(call.headers.containsKey('Command-Id'), isFalse);
      expect(find.byKey(const Key('register-done')), findsOneWidget);
    });

    testWidgets('correo repetido (409): mensaje propio', (tester) async {
      final h = Harness();
      h.api.routes['POST /auth/register'] = (_) => status(409);
      await h.pump(tester, initialRoute: '/register');
      await tester.enterText(find.byKey(const Key('register-email')), 'ana@correo.co');
      await tester.enterText(find.byKey(const Key('register-password')), 'una-clave-larga');
      await tester.enterText(find.byKey(const Key('register-confirm')), 'una-clave-larga');
      await tester.tap(find.byKey(const Key('register-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Ya existe una cuenta con ese correo.'), findsOneWidget);
    });
  });

  group('predicción', () {
    testWidgets('ADMINISTRATOR: elige convocatoria del listado y ve la estimación con su etiqueta', (tester) async {
      final h = Harness(token: 't', meResult: const MeSucceeded(administrator));
      h.api.routes['GET /organizations/org-1/campaigns'] = (_) => ok({
            'items': [
              {'campaignRef': 'C1', 'title': 'Abrigo', 'status': 'OPEN'},
            ],
          });
      h.api.routes['GET /organizations/org-1/campaigns/C1/prediction'] = (_) => ok({
            'kind': 'ESTIMATE',
            'modelVersion': 'v1',
            'warning': 'Estimación',
            'available': true,
            'probabilityReachTarget': 0.42,
            'estimatedFinalPctOfTarget': 0.8,
            'pctTimeElapsed': 0.3,
            'asOf': '2026-10-08T00:00:00Z',
          });
      h.api.routes['GET /organizations/org-1/campaigns/C1/prediction/history'] = (_) => ok({
            'available': true,
            'cuts': [
              {'t': 0.15, 'cutAt': '2026-10-10T00:00:00Z', 'available': false, 'unavailableText': 'Aún no llega'},
            ],
            'warnings': <String>[],
          });
      await h.pump(tester, initialRoute: '/prediction');
      await tester.tap(find.byKey(const Key('prediction-choice-C1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('prediction-verdict')), findsOneWidget);
      expect(find.text('42 %'), findsOneWidget);
      expect(find.text('Podría alcanzar la meta'), findsOneWidget);
      expect(find.textContaining('cerca del 80 % de la meta'), findsOneWidget);
      // Ningún tecnicismo para el usuario.
      expect(find.textContaining('modelo'), findsNothing);
      expect(find.textContaining('sintétic'), findsNothing);
      // Sin cortes con cifra, no se muestra el historial.
      expect(find.byKey(const Key('prediction-history')), findsNothing);
    });

    testWidgets('al empezar la causa: explica en palabras sencillas desde cuándo habrá estimación', (tester) async {
      final h = Harness(token: 't', meResult: const MeSucceeded(administrator));
      final start = DateTime.now().toUtc().subtract(const Duration(days: 1));
      final end = start.add(const Duration(days: 40));
      h.api.routes['GET /organizations/org-1/campaigns'] = (_) => ok({
            'items': [
              {'campaignRef': 'C1', 'publicCode': 'PUB1', 'title': 'Abrigo', 'status': 'OPEN'},
            ],
          });
      h.api.routes['GET /organizations/org-1/campaigns/C1/prediction'] = (_) => ok({
            'kind': 'ESTIMATE',
            'modelVersion': 'v1',
            'warning': 'x',
            'available': false,
            'unavailableReason': 'OUTSIDE_TRAINED_RANGE',
            'unavailableText': 'texto técnico del backend',
            'asOf': '2026-10-08T00:00:00Z',
          });
      h.api.routes['GET /organizations/org-1/campaigns/C1/prediction/history'] = (_) => status(500);
      h.api.routes['GET /public/campaigns/PUB1'] = (_) => ok({
            ..._campaign(),
            'startDate': start.toIso8601String(),
            'endDate': end.toIso8601String(),
          });
      await h.pump(tester, initialRoute: '/prediction');
      await tester.tap(find.byKey(const Key('prediction-choice-C1')));
      await tester.pumpAndSettle();
      expect(find.text('Todavía es pronto para estimar'), findsOneWidget);
      expect(find.textContaining('Podremos estimar a partir del'), findsOneWidget);
      expect(find.textContaining('texto técnico'), findsNothing);
      expect(find.text('Lo recaudado hasta hoy'), findsOneWidget);
      expect(find.text('Tiempo de la causa'), findsOneWidget);
    });

    testWidgets('NEGATIVA: un donante no ve la predicción', (tester) async {
      final h = Harness(token: 't');
      await h.pump(tester, initialRoute: '/prediction');
      expect(find.byKey(const Key('prediction-forbidden')), findsOneWidget);
      expect(h.api.calls.where((c) => c.path.contains('prediction')), isEmpty);
    });
  });
}
