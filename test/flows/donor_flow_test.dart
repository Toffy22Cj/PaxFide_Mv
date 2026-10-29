import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/app/app_routes.dart';
import 'package:paxfide_mobile/core/network/api_response.dart';
import 'package:paxfide_mobile/core/network/credential_mode.dart';
import 'package:paxfide_mobile/features/auth/domain/session_state.dart';

import 'package:paxfide_mobile/features/tracking/presentation/tracking_screen.dart';

import '../support/app_harness.dart';
import '../support/fakes.dart';

const trackingBody = ApiResponse(
  statusCode: 200,
  data: {
    'financialSnapshot': {
      'currency': 'COP',
      'originalAmount': 6000000,
      'clearedAmount': 6000000,
      'pendingAllocationAmount': 0,
      'confirmedAllocationAmount': 5000000,
      'refundedAmount': 0,
    },
    'campaignRef': 'interno-no-mostrar',
    'logistics': [
      {
        'assetRef': 'A-1',
        'lifecycleStatus': 'DELIVERED',
        'assetType': 'BLANKET',
        'unitOfMeasure': 'UNITS',
        'quantity': '6',
        'locationZone': 'Zona norte',
        'custodianCategory': 'LOCAL_ALLY',
      },
    ],
    'status': 'EN_PROCESO',
  },
);

void main() {
  Future<AppHarness> openTracking(WidgetTester tester) async {
    final h = AppHarness();
    await h.start(tester);
    h.services.router.push(AppRoutes.tracking);
    await tester.pumpAndSettle();
    return h;
  }

  testWidgets('seguimiento: el código va SOLO en Authorization (modo tracking), nunca en la ruta', (tester) async {
    final h = await openTracking(tester);
    h.api.routes['GET /donations/tracking'] = (_) => trackingBody;
    h.api.routes['GET /donations/tracking/narrative'] = (_) => const ApiResponse(
      statusCode: 200,
      data: {'status': 'AVAILABLE', 'content': 'Relato.', 'source': 'LLM_GENERATED'},
    );
    await tester.enterText(find.byKey(const Key('tracking.code')), 'CODIGO-SECRETO');
    await tester.tap(find.byKey(const Key('tracking.submit')));
    await tester.pumpAndSettle();

    final call = h.api.calls.firstWhere((c) => c.path == '/donations/tracking');
    expect(call.headers['Authorization'], 'Bearer CODIGO-SECRETO');
    expect(call.credentialMode, CredentialMode.tracking);
    for (final c in h.api.calls) {
      expect(c.path, isNot(contains('CODIGO-SECRETO')));
    }
    expect(h.location, AppRoutes.tracking);
    expect(h.services.router.stack.join(), isNot(contains('CODIGO-SECRETO')));
    expect(h.secure.values.values.join(), isNot(contains('CODIGO-SECRETO')));

    // Hechos reales y relato separados; sin ids internos.
    expect(find.text('Historia de tu donación'), findsOneWidget);
    await tester.scrollUntilVisible(find.byKey(const Key('tracking.figure.Asignación confirmada')), 300);
    expect(find.text('Hechos registrados'), findsOneWidget);
    // Unidades mínimas ISO 4217 (COP, exponente 2): 6000000 → 60 000,00 COP.
    String figure(String label) => tester.widget<Text>(find.byKey(Key('tracking.figure.$label'))).data!;
    expect(figure('Donado'), '60 000,00 COP');
    expect(figure('Asignación confirmada'), '50 000,00 COP');
    expect(find.text('BLANKET · 6 UNITS'), findsOneWidget);
    await tester.scrollUntilVisible(find.byKey(const Key('tracking.narrative')), 300);
    expect(find.text('Relato.'), findsOneWidget);
    expect(find.textContaining('generado con IA'), findsOneWidget);
    expect(find.textContaining('interno-no-mostrar'), findsNothing);
    // Integridad (M-18): sin lotes sellados no se afirma nada.
    expect(
      find.descendant(
        of: find.byKey(const Key('tracking.integrity'), skipOffstage: false),
        matching: find.text('Todavía no hay registros sellados', skipOffstage: false),
      ),
      findsOneWidget,
    );
    expect(
      h.api.calls.firstWhere((c) => c.path == '/donations/tracking/integrity').headers['Authorization'],
      'Bearer CODIGO-SECRETO',
    );
    expect(find.textContaining('erificada'), findsNothing);
    expect(find.textContaining('A-1'), findsNothing);
  });

  testWidgets('M-19: "Pegar" trae el código del portapapeles al campo', (tester) async {
    final h = await openTracking(tester);
    h.api.routes['GET /donations/tracking'] = (_) => trackingBody;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') return {'text': '  CODIGO-PEGADO \n'};
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.tap(find.byKey(const Key('tracking.paste')));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byKey(const Key('tracking.code'))).controller!.text, 'CODIGO-PEGADO');
  });

  testWidgets('código inválido (404) → un único mensaje y la sesión no cambia', (tester) async {
    final h = AppHarness();
    h.saveToken('jwt');
    await h.start(tester, beforeSession: () async => h.api.enqueue(meResponse()));
    h.services.router.push(AppRoutes.tracking);
    await tester.pumpAndSettle();
    h.api.routes['GET /donations/tracking'] = (_) => const ApiResponse(statusCode: 404);
    await tester.enterText(find.byKey(const Key('tracking.code')), 'MAL');
    await tester.tap(find.byKey(const Key('tracking.submit')));
    await tester.pumpAndSettle();
    expect(find.text('Código no válido o expirado.'), findsOneWidget);
    expect(h.services.session.state.status, SessionStatus.authenticated);
    expect(h.secure.values['paxfide.session.jwt'], 'jwt');
  });

  testWidgets('negativa: el 401 de seguimiento nunca modifica la sesión', (tester) async {
    final h = AppHarness();
    h.saveToken('jwt');
    await h.start(tester, beforeSession: () async => h.api.enqueue(meResponse()));
    h.services.router.push(AppRoutes.tracking);
    await tester.pumpAndSettle();
    h.api.routes['GET /donations/tracking'] = (_) => const ApiResponse(statusCode: 401);
    await tester.enterText(find.byKey(const Key('tracking.code')), 'MAL');
    await tester.tap(find.byKey(const Key('tracking.submit')));
    await tester.pumpAndSettle();
    expect(find.text('Código no válido o expirado.'), findsOneWidget);
    expect(h.services.session.state.status, SessionStatus.authenticated);
    expect(h.secure.values['paxfide.session.jwt'], 'jwt');
  });

  testWidgets('narrativa PENDING → "Actualizar" manual, sin polling', (tester) async {
    final h = await openTracking(tester);
    var narrativeCalls = 0;
    h.api.routes['GET /donations/tracking'] = (_) => trackingBody;
    h.api.routes['GET /donations/tracking/narrative'] = (_) {
      narrativeCalls++;
      return narrativeCalls == 1
          ? const ApiResponse(statusCode: 200, data: {'status': 'PENDING'})
          : const ApiResponse(
              statusCode: 200,
              data: {'status': 'AVAILABLE', 'content': 'Listo.', 'source': 'FALLBACK_TEMPLATE'},
            );
    };
    await tester.enterText(find.byKey(const Key('tracking.code')), 'C');
    await tester.tap(find.byKey(const Key('tracking.submit')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const Key('tracking.narrative')), 300);
    expect(find.text('El relato todavía se está preparando.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 30));
    expect(narrativeCalls, 1, reason: 'sin polling');
    await tester.ensureVisible(find.byKey(const Key('tracking.narrative.refresh'), skipOffstage: false));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tracking.narrative.refresh')));
    await tester.pumpAndSettle();
    expect(narrativeCalls, 2);
    expect(find.text('Listo.'), findsOneWidget);
    expect(find.textContaining('plantilla'), findsOneWidget);
  });

  testWidgets('historial de un bien: GET con el código en la cabecera', (tester) async {
    final h = await openTracking(tester);
    h.api.routes['GET /donations/tracking'] = (_) => trackingBody;
    h.api.routes['GET /donations/tracking/narrative'] = (_) =>
        const ApiResponse(statusCode: 200, data: {'status': 'PENDING'});
    h.api.routes['GET /donations/tracking/assets/A-1/history'] = (_) => const ApiResponse(
      statusCode: 200,
      data: {
        'history': [
          {
            'eventType': 'ASSET_DELIVERED',
            'timestamp': '2026-10-07T10:00:00Z',
            'locationZone': 'Zona norte',
            'custodianCategory': 'LOCAL_ALLY',
            'status': 'DELIVERED',
          },
        ],
      },
    );
    await tester.enterText(find.byKey(const Key('tracking.code')), 'C');
    await tester.tap(find.byKey(const Key('tracking.submit')));
    await tester.pumpAndSettle();
    // Los recorridos se piden todos al abrir y se ven en el árbol, sin tener que entrar en cada lote.
    final call = h.api.calls.firstWhere((c) => c.path.endsWith('/history'));
    expect(call.headers['Authorization'], 'Bearer C');
    expect(find.byKey(const Key('tracking.lot.0.steps')), findsOneWidget);
    expect(
      find.descendant(of: find.byKey(const Key('tracking.lot.0.steps')), matching: find.text('Entregado')),
      findsOneWidget,
    );
    expect(find.text(formatEventTime('2026-10-07T10:00:00Z')), findsOneWidget);
    expect(find.text('Zona norte'), findsOneWidget);
    expect(find.text('Aliado local'), findsOneWidget);
  });

  testWidgets('mis donaciones: lista real, sin intentId ni código de seguimiento', (tester) async {
    final h = AppHarness();
    h.saveToken('jwt');
    await h.start(tester, beforeSession: () async => h.api.enqueue(meResponse(roles: const [])));
    h.api.routes['GET /account/donations'] = (_) => const ApiResponse(
      statusCode: 200,
      data: {
        'items': [
          {
            'intentId': 'intent-interno',
            'campaignTitle': 'Abrigo para el invierno',
            'amount': '4000000',
            'currency': 'COP',
            'status': 'CONFIRMED',
            'trackingCode': 'CODIGO-DE-LA-CUENTA',
          },
        ],
      },
    );
    h.services.router.go(AppRoutes.donations);
    await tester.pumpAndSettle();
    expect(find.text('Abrigo para el invierno'), findsOneWidget);
    expect(find.byKey(const Key('donation.amount.0')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('donation.amount.0'))).data, '40 000,00 COP');
    expect(find.text('Pago confirmado'), findsOneWidget);
    expect(find.textContaining('intent-interno'), findsNothing);
    expect(find.textContaining('CODIGO-DE-LA-CUENTA'), findsNothing);
    expect(h.api.calls.last.credentialMode, CredentialMode.jwt);
  });

  testWidgets('M-16: detalle de la donación y "Ver el recorrido" con el código de la cuenta, sin guardarlo', (
    tester,
  ) async {
    final h = AppHarness();
    h.saveToken('jwt');
    await h.start(tester, beforeSession: () async => h.api.enqueue(meResponse(roles: const [])));
    h.api.routes['GET /account/donations'] = (_) => const ApiResponse(
      statusCode: 200,
      data: {
        'items': [
          {
            'campaignTitle': 'Abrigo para el invierno',
            'amount': '4000000',
            'currency': 'COP',
            'status': 'CONFIRMED',
            'trackingCode': 'CODIGO-DE-LA-CUENTA',
          },
          {'campaignTitle': 'Mercados', 'amount': '100000', 'currency': 'COP', 'status': 'PENDING'},
        ],
      },
    );
    h.api.routes['GET /donations/tracking'] = (_) => trackingBody;
    h.api.routes['GET /donations/tracking/narrative'] = (_) =>
        const ApiResponse(statusCode: 200, data: {'status': 'PENDING'});
    h.services.router.go(AppRoutes.donations);
    await tester.pumpAndSettle();

    // M-15: resumen y filtros.
    expect(find.byKey(const Key('donations.summary')), findsOneWidget);
    expect(find.text('2 donaciones · 1 con pago confirmado'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('donations.filter.pending')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('donations.filter.pending')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('donation.0')), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('donations.filter.problem')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('donations.filter.problem')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('donations.filter.empty')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('donations.filter.pending')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('donations.filter.pending')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('donation.1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('donation.noRoute')), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('donations.filter.all')));

    await tester.pump();

    await tester.tap(find.byKey(const Key('donations.filter.all')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('donation.0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('donation.route')));
    await tester.pumpAndSettle();
    final call = h.api.calls.firstWhere((c) => c.path == '/donations/tracking');
    expect(call.headers['Authorization'], 'Bearer CODIGO-DE-LA-CUENTA');
    expect(find.text('Historia de tu donación'), findsOneWidget);
    expect(h.services.router.stack.join(), isNot(contains('CODIGO-DE-LA-CUENTA')));
    expect(h.secure.values.values.join(), isNot(contains('CODIGO-DE-LA-CUENTA')));
  });

  testWidgets('mis donaciones vacía → estado vacío', (tester) async {
    final h = AppHarness();
    h.saveToken('jwt');
    await h.start(tester, beforeSession: () async => h.api.enqueue(meResponse(roles: const [])));
    h.api.routes['GET /account/donations'] = (_) => const ApiResponse(statusCode: 200, data: {'items': []});
    h.services.router.go(AppRoutes.donations);
    await tester.pumpAndSettle();
    expect(find.text('Todavía no hay donaciones hechas con esta cuenta.'), findsOneWidget);
  });

  testWidgets('convocatoria pública: datos, hechos separados del relato, QR; sin sesión', (tester) async {
    final h = AppHarness();
    h.api.routes['GET /public/campaigns/PUB1'] = (_) => const ApiResponse(
      statusCode: 200,
      data: {
        'organizationName': 'Fundación Demo',
        'title': 'Abrigo para el invierno',
        'status': 'OPEN',
        'startDate': '2026-10-07T00:00:00Z',
        'endDate': '2026-12-07T00:00:00Z',
        'acceptedDonationTypes': ['MONETARY'],
        'currency': 'COP',
        'targetAmount': '50000000',
        'clearedAmount': '10000000',
      },
    );
    h.api.routes['GET /public/campaigns/PUB1/narrative'] = (_) => const ApiResponse(
      statusCode: 200,
      data: {
        'status': 'UNAVAILABLE',
        'content': 'Narrativa no disponible',
        'facts': {
          'status': 'OPEN',
          'currency': 'COP',
          'clearedAmount': '10000000',
          'unitsDelivered': '6',
          'distinctRecipients': 2,
        },
      },
    );
    await h.start(tester);
    await h.services.router.openDeepLink(h.services.deepLinkParser.parse(Uri.parse('$testOrigin/c/PUB1')));
    await tester.pumpAndSettle();
    expect(find.text('Abrigo para el invierno'), findsOneWidget);
    expect(find.text('de 500 000,00 COP'), findsOneWidget);
    expect(find.text('Recaudado y acreditado'), findsOneWidget);
    expect(find.text('100 000,00 COP'), findsNWidgets(2), reason: 'recaudado y el hecho «Acreditado»');
    expect(find.text('Meta 20 %'), findsOneWidget);
    expect(find.text('Unidades entregadas'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
    expect(find.text('Narrativa no disponible'), findsOneWidget);
    expect(
      h.api.calls.where((c) => c.path.startsWith('/public/')).every((c) => c.credentialMode == CredentialMode.none),
      isTrue,
    );
    await tester.tap(find.byKey(const Key('campaign.qr')));
    await tester.pumpAndSettle();
    expect(find.text('$testOrigin/c/PUB1'), findsOneWidget);
  });

  testWidgets('convocatoria inexistente → 404 como estado de pantalla', (tester) async {
    final h = AppHarness();
    h.api.routes['GET /public/campaigns/NO'] = (_) => const ApiResponse(statusCode: 404);
    await h.start(tester);
    await h.services.router.openDeepLink(h.services.deepLinkParser.parse(Uri.parse('$testOrigin/c/NO')));
    await tester.pumpAndSettle();
    expect(find.text('No encontramos esta convocatoria.'), findsOneWidget);
    expect(find.byKey(const Key('campaign.qr')), findsNothing);
  });

  testWidgets('mis donaciones: campaignTitle ausente (rama defensiva del backend) → "Convocatoria no disponible"', (
    tester,
  ) async {
    final h = AppHarness();
    h.saveToken('jwt');
    await h.start(tester, beforeSession: () async => h.api.enqueue(meResponse(roles: const [])));
    h.api.routes['GET /account/donations'] = (_) => const ApiResponse(
      statusCode: 200,
      data: {
        'items': [
          {'intentId': 'i', 'campaignTitle': null, 'amount': '100000', 'currency': 'COP', 'status': 'PENDING'},
        ],
      },
    );
    h.services.router.go(AppRoutes.donations);
    await tester.pumpAndSettle();
    expect(find.text('Convocatoria no disponible'), findsOneWidget);
    expect(find.text('1 000,00 COP'), findsOneWidget);
  });

  testWidgets('M-07: insignia de organización verificada solo con organizationVerified == true', (tester) async {
    for (final (status, shown) in [(true, true), (false, false), (null, false)]) {
      final h = AppHarness();
      h.api.routes['GET /public/campaigns/PUB1'] = (_) => ApiResponse(
        statusCode: 200,
        data: {
          'organizationName': 'Fundación Demo',
          'title': 'Abrigo',
          'status': 'OPEN',
          'startDate': '2026-10-01T00:00:00Z',
          'endDate': '2026-12-01T00:00:00Z',
          'organizationVerified': ?status,
        },
      );
      h.api.routes['GET /public/campaigns/PUB1/narrative'] = (_) =>
          const ApiResponse(statusCode: 202, data: {'status': 'PENDING'});
      await h.start(tester);
      await h.services.router.openDeepLink(h.services.deepLinkParser.parse(Uri.parse('$testOrigin/c/PUB1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('campaign.verified')), shown ? findsOneWidget : findsNothing, reason: '$status');
    }
  });

  group('M-18: seguimiento verificable', () {
    final hash = 'a' * 64;
    final root = 'b' * 64;

    Future<AppHarness> submitted(
      WidgetTester tester, {
      required Object Function(RecordedCall) integrity,
      Object Function(RecordedCall)? history,
    }) async {
      final h = await openTracking(tester);
      if (history != null) h.api.routes['GET /donations/tracking/assets/A-1/history'] = history;
      h.api.routes['GET /donations/tracking'] = (_) => trackingBody;
      h.api.routes['GET /donations/tracking/narrative'] = (_) =>
          const ApiResponse(statusCode: 200, data: {'status': 'PENDING'});
      h.api.routes['GET /donations/tracking/integrity'] = integrity;
      await tester.enterText(find.byKey(const Key('tracking.code')), 'C');
      await tester.tap(find.byKey(const Key('tracking.submit')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.byKey(const Key('tracking.integrity')), 300);
      await tester.pumpAndSettle();
      return h;
    }

    Map<String, Object?> batch(String result, {String? reason, bool? affects}) => {
      'anchorStatus': result == 'MATCH' ? 'ANCHORED' : 'SUBMITTED',
      'merkleRoot': root,
      'transactionHash': '0x${'c' * 64}',
      'network': 'ganache-local',
      'anchoredAt': '2026-10-27T09:00:00Z',
      'eventsOfThisDonation': 3,
      'verification': {'result': result, 'reason': ?reason, 'reasonText': ?reason, 'affectsThisDonation': ?affects},
    };

    testWidgets('todo sellado y coincide → "sellado y verificado", con el detalle del lote', (tester) async {
      await submitted(
        tester,
        integrity: (_) => ApiResponse(
          statusCode: 200,
          data: {
            'batches': [batch('MATCH')],
            'unanchoredEvents': 0,
            'checkedAt': '2026-10-28T12:00:00Z',
          },
        ),
      );
      expect(find.text('Registro sellado y verificado'), findsOneWidget);
      await tester.tap(find.byKey(const Key('tracking.integrity')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('verification.batch.0')), findsOneWidget);
      expect(find.text('Coincide'), findsOneWidget);
      expect(find.text('ganache-local'), findsOneWidget);
      expect(find.text('bbbbbbbb…bbbbbb'), findsOneWidget);
    });

    testWidgets('una diferencia que afecta a la donación manda sobre lo demás', (tester) async {
      await submitted(
        tester,
        integrity: (_) => ApiResponse(
          statusCode: 200,
          data: {
            'batches': [batch('MATCH'), batch('MISMATCH', reason: 'ROOT_MISMATCH', affects: true)],
            'unanchoredEvents': 0,
            'checkedAt': '2026-10-28T12:00:00Z',
          },
        ),
      );
      expect(find.text('Hay una diferencia en el registro: se está revisando'), findsOneWidget);
    });

    testWidgets('si no se puede comprobar, lo dice y deja reintentar sin tocar el resto', (tester) async {
      var calls = 0;
      await submitted(
        tester,
        integrity: (_) {
          calls++;
          return calls == 1
              ? const ApiResponse(statusCode: 503)
              : const ApiResponse(
                  statusCode: 200,
                  data: {'batches': <Object>[], 'unanchoredEvents': 1, 'checkedAt': '2026-10-28T12:00:00Z'},
                );
        },
      );
      expect(find.text('No se pudo comprobar ahora'), findsOneWidget);
      expect(find.byKey(const Key('tracking.narrative')), findsOneWidget, reason: 'el resto del seguimiento sigue');
      await tester.tap(find.byKey(const Key('tracking.integrity.retry')));
      await tester.pumpAndSettle();
      expect(find.text('Todavía no hay registros sellados'), findsOneWidget);
    });

    testWidgets('cada paso muestra su sello y su huella; la entrega, si tiene evidencia', (tester) async {
      await submitted(
        tester,
        integrity: (_) =>
            const ApiResponse(statusCode: 200, data: {'batches': <Object>[], 'unanchoredEvents': 0, 'checkedAt': ''}),
        history: (_) => ApiResponse(
          statusCode: 200,
          data: {
            'history': [
              {
                'eventType': 'ASSET_REGISTERED',
                'timestamp': '2026-10-01T10:00:00Z',
                'custodianCategory': 'LOCAL_ALLY',
                'status': 'REGISTERED',
                'anchorStatus': 'ANCHORED',
                'eventHash': hash,
                'anchorProof': {
                  'merkleRoot': root,
                  'leafIndex': 0,
                  'path': <Object>[],
                  'transactionHash': '0x1',
                  'network': 'ganache-local',
                  'anchoredAt': '2026-10-02T10:00:00Z',
                },
              },
              {
                'eventType': 'ASSET_DELIVERED',
                'timestamp': '2026-10-07T10:00:00Z',
                'custodianCategory': 'LOCAL_ALLY',
                'status': 'DELIVERED',
                'anchorStatus': 'IN_BATCH',
                'eventHash': 'no-es-hex',
                'evidenceRegistered': true,
                'evidenceRef': 'sha256:${'d' * 64}',
              },
            ],
          },
        ),
      );
      // El detalle de cada paso se abre en una hoja inferior.
      Future<void> open(int step) async {
        await tester.scrollUntilVisible(
          find.byKey(Key('tracking.step.0.$step')),
          -200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(Key('tracking.step.0.$step')));
        await tester.pumpAndSettle();
      }

      await open(0);
      expect(
        find.descendant(
          of: find.byKey(const Key('tracking.step.0.seal')),
          matching: find.text('Anclado en blockchain'),
        ),
        findsOneWidget,
      );
      expect(find.text('aaaaaaaa…aaaaaa'), findsOneWidget);
      expect(find.byKey(const Key('tracking.step.0.proof')), findsOneWidget);
      Navigator.of(tester.element(find.byKey(const Key('tracking.detail.step')))).pop();
      await tester.pumpAndSettle();
      await open(1);
      expect(
        find.descendant(
          of: find.byKey(const Key('tracking.step.1.seal')),
          matching: find.text('En el próximo anclaje'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('tracking.step.1.hash')),
        findsNothing,
        reason: 'una huella mal formada no se muestra',
      );
      expect(find.byKey(const Key('tracking.step.1.evidence')), findsOneWidget);
    });
  });
}
