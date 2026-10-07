import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/app/app_routes.dart';
import 'package:paxfide_mobile/core/network/api_response.dart';
import 'package:paxfide_mobile/core/network/credential_mode.dart';
import 'package:paxfide_mobile/features/auth/domain/session_state.dart';

import '../support/app_harness.dart';

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
    expect(find.text('Hechos registrados'), findsOneWidget);
    expect(find.text('Donado: 6000000 COP'), findsOneWidget);
    expect(find.text('BLANKET · 6 UNITS'), findsOneWidget);
    expect(find.text('Relato.'), findsOneWidget);
    expect(find.textContaining('generado con IA'), findsOneWidget);
    expect(find.textContaining('interno-no-mostrar'), findsNothing);
    expect(find.textContaining('A-1'), findsNothing);
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
    expect(find.text('El relato todavía se está preparando.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 30));
    expect(narrativeCalls, 1, reason: 'sin polling');
    await tester.ensureVisible(find.byKey(const Key('tracking.narrative.refresh')));
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
    await tester.tap(find.text('BLANKET · 6 UNITS'));
    await tester.pumpAndSettle();
    final call = h.api.calls.firstWhere((c) => c.path.endsWith('/history'));
    expect(call.headers['Authorization'], 'Bearer C');
    expect(find.textContaining('2026-10-07T10:00:00Z'), findsOneWidget);
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
    expect(find.text('4000000 COP'), findsOneWidget);
    expect(find.text('Pago confirmado'), findsOneWidget);
    expect(find.textContaining('intent-interno'), findsNothing);
    expect(find.textContaining('CODIGO-DE-LA-CUENTA'), findsNothing);
    expect(h.api.calls.last.credentialMode, CredentialMode.jwt);
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
    expect(find.text('Meta: 50000000 COP'), findsOneWidget);
    expect(find.text('Recaudado y acreditado: 10000000 COP'), findsOneWidget);
    expect(find.text('Unidades entregadas: 6'), findsOneWidget);
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
}
