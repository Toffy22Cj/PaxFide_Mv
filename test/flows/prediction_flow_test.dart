import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/app/app_routes.dart';
import 'package:paxfide_mobile/core/network/api_response.dart';
import 'package:paxfide_mobile/core/network/credential_mode.dart';
import 'package:paxfide_mobile/features/prediction/presentation/prediction_screen.dart';

import '../support/app_harness.dart';

const path = '/organizations/org-1/campaigns/camp-9/prediction';

void main() {
  Future<AppHarness> open(WidgetTester tester, List<String> roles) async {
    final h = AppHarness();
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
}
