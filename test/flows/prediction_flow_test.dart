import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/app/app_routes.dart';
import 'package:paxfide_mobile/core/network/api_response.dart';
import 'package:paxfide_mobile/core/network/credential_mode.dart';
import 'package:paxfide_mobile/features/prediction/presentation/prediction_screen.dart';

import '../support/app_harness.dart';

const path = '/organizations/org-1/campaigns/camp-9/prediction';

void main() {
  Future<AppHarness> open(WidgetTester tester, List<String> roles, {bool withList = false}) async {
    final h = AppHarness();
    if (!withList) {
      // Sin listado: la app ofrece escribir la referencia como último recurso.
      h.api.routes['GET /organizations/org-1/campaigns'] = (_) => const ApiResponse(statusCode: 403);
      h.api.routes['GET /me/campaigns'] = (_) => const ApiResponse(statusCode: 200, data: {'items': []});
    }
    h.saveToken('jwt');
    await h.start(tester, beforeSession: () async => h.api.enqueue(meResponse(roles: roles)));
    h.services.router.go(AppRoutes.prediction);
    await tester.pumpAndSettle();
    return h;
  }

  Future<void> query(WidgetTester tester) async {
    await tester.enterText(find.byKey(const Key('prediction.campaignRef')), 'camp-9');
    await tester.tap(find.byKey(const Key('prediction.submit')));
    await tester.pumpAndSettle();
  }

  for (final role in ['ADMINISTRATOR', 'REPRESENTATIVE']) {
    testWidgets('$role: consulta con la organización de /me y muestra la estimación con su etiqueta', (tester) async {
      final h = await open(tester, [role]);
      h.api.routes['GET $path'] = (_) => const ApiResponse(
        statusCode: 200,
        data: {
          'kind': 'ESTIMATE',
          'modelVersion': 'p3-v1',
          'warning': 'modelo entrenado con datos sintéticos',
          'available': true,
          'probabilityReachTarget': 0.8523,
          'estimatedFinalPctOfTarget': 1.0412,
          'pctTimeElapsed': 0.25,
          'warnings': ['modelo entrenado con datos sintéticos'],
          'asOf': '2026-10-07T23:00:00Z',
        },
      );
      await query(tester);
      final call = h.api.calls.last;
      expect(call.path, path);
      expect(call.credentialMode, CredentialMode.jwt);
      expect(find.text(predictionLabel), findsOneWidget);
      expect(find.text('Probabilidad estimada de alcanzar la meta: 85.2 %'), findsOneWidget);
      expect(find.text('Porcentaje final estimado de la meta: 104.1 %'), findsOneWidget);
      expect(find.text('Tiempo transcurrido de la convocatoria: 25.0 %'), findsOneWidget);
      // Solo lo que devuelve el backend: nada de bandas de confianza.
      expect(find.textContaining('confianza'), findsNothing);
      // Gráfico histórico: el backend no lo expone todavía → "No disponible", sin cortes inventados.
      expect(
        find.descendant(
          of: find.byKey(const Key('prediction.history'), skipOffstage: false),
          matching: find.text('No disponible', skipOffstage: false),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('95'), findsNothing);
      // La etiqueta va antes que cualquier cifra.
      final labelY = tester.getTopLeft(find.byKey(const Key('prediction.label'))).dy;
      final figureY = tester.getTopLeft(find.textContaining('Probabilidad estimada')).dy;
      expect(labelY, lessThan(figureY));
    });
  }

  testWidgets('sin estimación (available: false) → el texto del backend, con la etiqueta', (tester) async {
    final h = await open(tester, ['ADMINISTRATOR']);
    h.api.routes['GET $path'] = (_) => const ApiResponse(
      statusCode: 200,
      data: {
        'kind': 'ESTIMATE',
        'modelVersion': 'p3-v1',
        'warning': 'modelo entrenado con datos sintéticos',
        'available': false,
        'unavailableReason': 'STRICT_POLICY_EXCLUDED',
        'unavailableText': 'La política STRICT rechaza el exceso sobre la meta; el modelo no se entrenó con ella',
        'warnings': ['modelo entrenado con datos sintéticos'],
        'asOf': '2026-10-07T23:00:00Z',
      },
    );
    await query(tester);
    expect(find.text(predictionLabel), findsOneWidget);
    expect(find.textContaining('La política STRICT'), findsOneWidget);
    expect(find.textContaining('Probabilidad'), findsNothing);
  });

  testWidgets('403 (sin permiso, otra organización o inexistente) → estado de pantalla', (tester) async {
    final h = await open(tester, ['ADMINISTRATOR']);
    h.api.routes['GET $path'] = (_) => const ApiResponse(statusCode: 403);
    await query(tester);
    expect(find.text('No puedes ver la predicción de esa convocatoria (o no existe).'), findsOneWidget);
    expect(h.location, AppRoutes.prediction);
  });

  testWidgets('EMPLOYEE o donante → sin acceso, y no se consulta nada', (tester) async {
    final h = await open(tester, ['EMPLOYEE']);
    expect(find.text('Tu cuenta no tiene acceso a la predicción.'), findsOneWidget);
    expect(h.api.calls.where((c) => c.path.contains('/prediction')), isEmpty);
  });

  const listItem = {
    'campaignRef': 'camp-9',
    'publicCode': 'PUB9',
    'title': 'Abrigo para el invierno',
    'status': 'OPEN',
  };
  const available = ApiResponse(
    statusCode: 200,
    data: {
      'kind': 'ESTIMATE',
      'modelVersion': 'p3-v1',
      'warning': 'modelo entrenado con datos sintéticos',
      'available': true,
      'probabilityReachTarget': 0.5,
      'asOf': '2026-10-08T00:00:00Z',
    },
  );

  testWidgets('ADMINISTRATOR elige la convocatoria del listado de la organización (S-04), sin escribir nada', (
    tester,
  ) async {
    final h = AppHarness();
    h.api.routes['GET /organizations/org-1/campaigns'] = (_) => const ApiResponse(
      statusCode: 200,
      data: {
        'items': [
          {...listItem, 'visibility': 'PUBLIC', 'responsibles': [], 'assignedEmployeeCount': 0},
        ],
      },
    );
    h.api.routes['GET $path'] = (_) => available;
    h.saveToken('jwt');
    await h.start(tester, beforeSession: () async => h.api.enqueue(meResponse(roles: const ['ADMINISTRATOR'])));
    h.services.router.go(AppRoutes.prediction);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('prediction.campaignRef')), findsNothing, reason: 'con listado no se escribe');
    await tester.tap(find.text('Abrigo para el invierno'));
    await tester.pumpAndSettle();
    expect(h.api.calls.last.path, path);
    expect(find.text('Probabilidad estimada de alcanzar la meta: 50.0 %'), findsOneWidget);
    expect(h.api.calls.where((c) => c.path == '/me/campaigns'), isEmpty);
  });

  testWidgets('REPRESENTATIVE (sin listado de organización) usa sus convocatorias de GET /me/campaigns', (
    tester,
  ) async {
    final h = AppHarness();
    h.api.routes['GET /me/campaigns'] = (_) => const ApiResponse(
      statusCode: 200,
      data: {
        'items': [
          {...listItem, 'actingRole': 'REPRESENTATIVE', 'assignedAt': '2026-10-01T00:00:00Z'},
        ],
      },
    );
    h.api.routes['GET $path'] = (_) => available;
    h.saveToken('jwt');
    await h.start(tester, beforeSession: () async => h.api.enqueue(meResponse(roles: const ['REPRESENTATIVE'])));
    h.services.router.go(AppRoutes.prediction);
    await tester.pumpAndSettle();
    expect(h.api.calls.where((c) => c.path == '/organizations/org-1/campaigns'), isEmpty);
    await tester.tap(find.text('Abrigo para el invierno'));
    await tester.pumpAndSettle();
    expect(h.api.calls.last.path, path);
  });

  testWidgets('OUTSIDE_TRAINED_RANGE → el motivo, sin ninguna cifra (aunque llegaran)', (tester) async {
    final h = await open(tester, ['ADMINISTRATOR']);
    h.api.routes['GET $path'] = (_) => const ApiResponse(
      statusCode: 200,
      data: {
        'kind': 'ESTIMATE',
        'modelVersion': 'p3-v1',
        'warning': 'modelo entrenado con datos sintéticos',
        'available': false,
        'unavailableReason': 'OUTSIDE_TRAINED_RANGE',
        'unavailableText':
            'Fuera del rango del modelo: solo estima entre el 15 % y el 50 % del tiempo de la convocatoria',
        // Defensa: aunque el backend enviara cifras con este motivo, no se muestran.
        'probabilityReachTarget': 0.9,
        'pctTimeElapsed': 0.7,
        'asOf': '2026-10-08T00:00:00Z',
      },
    );
    await query(tester);
    expect(find.text(predictionLabel), findsOneWidget);
    expect(find.textContaining('Fuera del rango del modelo'), findsOneWidget);
    expect(find.textContaining('Probabilidad'), findsNothing);
    expect(find.textContaining('Tiempo transcurrido'), findsNothing);
    expect(find.textContaining('%)'), findsNothing);
  });
}
