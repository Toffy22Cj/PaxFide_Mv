import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/app/app_routes.dart';
import 'package:paxfide_mobile/core/network/api_response.dart';
import 'package:paxfide_mobile/features/prediction/presentation/prediction_screen.dart';
import 'package:paxfide_mobile/shared/charts/chart_preference_store.dart';

import '../support/app_harness.dart';

/// Paso 3 en la app completa: Mi día con el estado de los lotes en gráficos, y la predicción con su historial.
void main() {
  const path = '/organizations/org-1/campaigns/camp-9/prediction';

  testWidgets(
    'EMPLOYEE: Mi día muestra el par de gráficos de lotes, con selector; la elección se guarda por accountId',
    (tester) async {
      final h = AppHarness();
      h.api.routes['GET /organizations/org-1/physical-assets'] = (_) => const ApiResponse(
        statusCode: 200,
        data: {
          'items': [
            {'assetRef': 'A-1', 'lifecycleStatus': 'REGISTERED', 'assetType': 'BLANKET'},
            {'assetRef': 'A-2', 'lifecycleStatus': 'DELIVERED', 'assetType': 'FOOD_KIT'},
          ],
        },
      );
      h.saveToken('jwt');
      await h.start(tester, beforeSession: () async => h.api.enqueue(meResponse(account: 'acc-emp')));
      h.services.router.go(AppRoutes.operator);
      await tester.pumpAndSettle();

      final select = find.byKey(const Key('charts.assets.simple.select'));
      await tester.scrollUntilVisible(select, 200);
      expect(find.byKey(const Key('charts.assets.simple.vbars')), findsOneWidget);
      expect(tester.getSemantics(find.byKey(const Key('assets.vbars.chart'))).label, contains('Entregado 1 lote'));

      await tester.tap(select);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dona').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('charts.assets.simple.donut')), findsOneWidget);
      final key = ChartPreferenceStore.keyFor('acc-emp', ChartPanelId.assets);
      expect(h.secure.values[key], '{"simple":"donut"}');
      expect(h.secure.values.keys.where((k) => k.startsWith('paxfide.charts.') && k.contains('@')), isEmpty);
    },
  );

  testWidgets(
    'REPRESENTATIVE: la predicción con su historial; la tarjeta conserva la advertencia y el corte sin cifra no se rellena',
    (tester) async {
      final h = AppHarness();
      h.api.routes['GET /organizations/org-1/campaigns'] = (_) => const ApiResponse(
        statusCode: 200,
        data: {
          'items': [
            {'campaignRef': 'camp-9', 'publicCode': 'PUB9', 'title': '[Demo] Cuarenta por ciento', 'status': 'OPEN'},
          ],
        },
      );
      h.api.routes['GET $path'] = (_) => const ApiResponse(
        statusCode: 200,
        data: {
          'kind': 'ESTIMATE',
          'modelVersion': 'baseline-0.3.0',
          'warning': 'modelo entrenado con datos sintéticos',
          'available': true,
          'probabilityReachTarget': 0.069,
          'estimatedFinalPctOfTarget': 0.8203,
          'pctTimeElapsed': 0.4,
          'warnings': ['modelo entrenado con datos sintéticos'],
          'asOf': '2026-11-16T07:51:59Z',
        },
      );
      h.api.routes['GET $path/history'] = (_) => const ApiResponse(
        statusCode: 200,
        data: {
          'kind': 'ESTIMATE',
          'available': true,
          'warnings': ['modelo entrenado con datos sintéticos', 'En los cortes pasados la tasa de fallos es 0'],
          'cuts': [
            {
              't': 0.15,
              'available': true,
              'probabilityReachTarget': 0.12,
              'estimatedFinalPctOfTarget': 0.8,
              'pctRaisedAtCut': 0.1577,
            },
            {
              't': 0.25,
              'available': true,
              'probabilityReachTarget': 0.07,
              'estimatedFinalPctOfTarget': 0.82,
              'pctRaisedAtCut': 0.2644,
            },
            {
              't': 0.5,
              'available': false,
              'unavailableReason': 'FUTURE_CUT',
              'unavailableText': 'Este corte aún no ha llegado',
            },
          ],
        },
      );
      h.saveToken('jwt');
      await h.start(tester, beforeSession: () async => h.api.enqueue(meResponse(roles: const ['REPRESENTATIVE'])));
      h.services.router.go(AppRoutes.prediction);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('prediction.choice.camp-9')));
      await tester.pumpAndSettle();

      expect(find.text(predictionLabel), findsOneWidget);
      expect(find.text('6,9 %'), findsOneWidget);
      await tester.scrollUntilVisible(find.byKey(const Key('charts.prediction.advanced.select')), 200);
      expect(find.byKey(const Key('prediction.history')), findsOneWidget);
      expect(find.text('En los cortes pasados la tasa de fallos es 0'), findsOneWidget);
      expect(
        tester.getSemantics(find.byKey(const Key('prediction.cuts.chart'))).label,
        contains('50 % del tiempo sin dato'),
      );
      expect(find.byKey(const Key('charts.prediction.simple.select')), findsOneWidget);
    },
  );
}
