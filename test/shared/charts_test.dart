import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/core/storage/secure_key_value_store.dart';
import 'package:paxfide_mobile/features/auth/domain/principal.dart';
import 'package:paxfide_mobile/features/physical_assets/data/physical_asset_api.dart';
import 'package:paxfide_mobile/features/physical_assets/presentation/assets_charts.dart';
import 'package:paxfide_mobile/features/prediction/data/prediction_api.dart';
import 'package:paxfide_mobile/features/prediction/presentation/prediction_charts.dart';
import 'package:paxfide_mobile/shared/charts/chart_data.dart';
import 'package:paxfide_mobile/shared/charts/chart_panel.dart';
import 'package:paxfide_mobile/shared/charts/chart_preference_store.dart';
import 'package:paxfide_mobile/shared/charts/charts.dart';

import '../support/fakes.dart';

// Datos de PRUEBA tomados de las respuestas reales del escenario `demo-historico` del backend (paso 2); recortados,
// nunca inventados para el gráfico.
const _assets = [
  PhysicalAssetDto(assetRef: 'a1', lifecycleStatus: 'DELIVERED', assetType: 'SCHOOL_KIT'),
  PhysicalAssetDto(assetRef: 'a2', lifecycleStatus: 'DISPATCHED', assetType: 'FOOD_KIT'),
  PhysicalAssetDto(assetRef: 'a3', lifecycleStatus: 'RECEIVED', assetType: 'HYGIENE_KIT'),
  PhysicalAssetDto(assetRef: 'a4', lifecycleStatus: 'REGISTERED', assetType: 'BLANKET'),
  PhysicalAssetDto(assetRef: 'a5', lifecycleStatus: 'REGISTERED', assetType: 'BLANKET'),
  PhysicalAssetDto(assetRef: 'a6', lifecycleStatus: 'DELIVERED', assetType: 'BLANKET'),
];

// «[Demo] Cuarenta por ciento»: dos cortes con cifra y el del 50 % sin ella (FUTURE_CUT)
final _history = PredictionHistory.fromJson({
  'kind': 'ESTIMATE',
  'available': true,
  'warnings': ['modelo entrenado con datos sintéticos'],
  'cuts': [
    {
      't': 0.5,
      'available': false,
      'unavailableReason': 'FUTURE_CUT',
      'unavailableText': 'Este corte aún no ha llegado',
    },
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
  ],
});

const _empty = CategoryChartData(categories: [], series: [], format: _fmt, unit: 'x');
String _fmt(double v) => '$v';

Principal _p(List<String> roles, [String account = 'acc-1']) =>
    Principal(accountId: account, organizationId: 'org-1', roles: roles.toSet());

Future<void> _pump(WidgetTester tester, Widget child, {Brightness brightness = Brightness.light}) async {
  tester.view.physicalSize = const Size(390 * 3, 2400 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(colorSchemeSeed: const Color(0xFF1B5141), brightness: brightness),
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

String _semantics(WidgetTester tester, String key) => tester.getSemantics(find.byKey(Key(key))).label;

/// Almacén que falla siempre (modo privado, almacenamiento bloqueado).
class _BrokenStore implements SecureKeyValueStore {
  @override
  Future<String?> read(String key) => Future.error(StateError('bloqueado'));
  @override
  Future<void> write(String key, String value) => Future.error(StateError('bloqueado'));
  @override
  Future<void> delete(String key) => Future.error(StateError('bloqueado'));
}

void main() {
  group('datos', () {
    test('ejes redondos, acumulados y totales sin inventar', () {
      expect(niceMax(0), 1);
      expect(niceMax(73), 100);
      expect(niceMax(3751196301), 5000000000);
      expect(cumulative([null, 2, null, 3]), [null, 2, 2, 5]);
      // Conteos: marcas enteras (nunca «2,5 lotes»); importes y porcentajes, tope redondo
      expect(axisTop([4, 1, 2]), 4);
      expect(ticks(axisTop([10, 3])), [0, 3, 6, 9, 12]);
      expect(axisTop([12.5, 7]), 20);
    });

    test('lotes: se cuentan lotes por estado y tipo', () {
      expect(assetsByState(_assets).series.single.values, [2, 1, 1, 2]);
      final st = assetsStateByType(_assets);
      expect(st.categories, ['Registrado', 'Despachado', 'Recibido', 'Entregado']);
      expect(assetsStateByType(_assets, byType: true).series.map((s) => s.key), [
        'REGISTERED',
        'DISPATCHED',
        'RECEIVED',
        'DELIVERED',
      ]);
    });

    test('historial: ordena los cortes y un corte sin cifra queda vacío (null), nunca se rellena', () {
      expect(_history.cuts.map((c) => c.t), [0.15, 0.25, 0.5]);
      final d = cutsData(_history.cuts);
      expect(d.series[0].values[2], isNull);
      expect(d.series[1].values[2], isNull);
      expect(d.series[1].nature, SeriesNature.estimate);
      final prob = probabilityData(_history.cuts).series.single.values;
      expect(prob[0], closeTo(12, 1e-9));
      expect(prob[1], closeTo(7, 1e-9));
      expect(prob[2], isNull);
    });
  });

  group('cada tipo con datos y vacío', () {
    final data = assetsByState(_assets);
    final types = <String, Widget Function(CategoryChartData)>{
      'vbars': (d) => VerticalBarsChart(data: d, testKey: 't'),
      'hbars': (d) => HorizontalBarsChart(data: d, testKey: 't'),
      'line': (d) => LineChartView(data: d, testKey: 't'),
      'area': (d) => LineChartView(data: d, testKey: 't', area: true),
      'donut': (d) => DonutChart(data: d, testKey: 't'),
      'stacked': (d) => StackedBarsChart(data: d, testKey: 't'),
      'combo': (d) => ComboBarsLineChart(data: d, testKey: 't'),
    };
    for (final MapEntry(key: name, value: build) in types.entries) {
      testWidgets('$name: el lector de pantalla lee las cifras y la tabla tiene los mismos datos', (tester) async {
        await _pump(tester, build(data));
        expect(_semantics(tester, 't.chart'), contains('2 lotes'));
        await tester.tap(find.text('Ver los datos'));
        await tester.pumpAndSettle();
        final table = find.byKey(const Key('t.table'));
        expect(find.descendant(of: table, matching: find.text('Registrado')), findsWidgets);
        expect(find.descendant(of: table, matching: find.text('2 lotes')), findsWidgets);
      });
      testWidgets('$name: sin datos, un aviso y ningún dibujo', (tester) async {
        await _pump(tester, build(_empty));
        expect(find.byKey(const Key('t.empty')), findsOneWidget);
        expect(find.byKey(const Key('t.chart')), findsNothing);
      });
      testWidgets('$name: se dibuja también en oscuro', (tester) async {
        await _pump(tester, build(data), brightness: Brightness.dark);
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('t.chart')), findsOneWidget);
      });
    }

    testWidgets('cifras clave y progreso, con datos y vacíos', (tester) async {
      await _pump(
        tester,
        Column(
          children: [
            const KpiTilesChart(testKey: 'k', tiles: [('Lotes', '6')]),
            ProgressChart(label: 'Entregados', part: 2, total: 6, format: (v) => '${v.round()}', testKey: 'p'),
          ],
        ),
      );
      expect(find.byKey(const Key('k.tile')), findsOneWidget);
      expect(_semantics(tester, 'p.chart'), 'Entregados: 2 de 6 (33 %)');
      await _pump(
        tester,
        Column(
          children: [
            const KpiTilesChart(testKey: 'k', tiles: []),
            ProgressChart(label: 'Entregados', part: 0, total: 0, format: (v) => '$v', testKey: 'p'),
          ],
        ),
      );
      expect(find.byKey(const Key('k.empty')), findsOneWidget);
      expect(find.byKey(const Key('p.empty')), findsOneWidget);
    });
  });

  group('selector por rol y preferencia', () {
    List<ChartOption> opts(String p) => [
      ChartOption('a', '$p A', (_) => Text('$p-a')),
      ChartOption('b', '$p B', (_) => Text('$p-b')),
    ];

    testWidgets('con permiso: simple y avanzado a la vez; la elección se guarda por cuenta y sigue al volver', (
      tester,
    ) async {
      final mem = InMemorySecureKeyValueStore();
      final store = ChartPreferenceStore(mem);
      Widget panel() => ChartPanel(
        panel: ChartPanelId.assets,
        simple: opts('s'),
        advanced: opts('v'),
        canChoose: true,
        store: store,
        accountId: 'acc-1',
      );
      await _pump(tester, panel());
      expect(find.text('s-a'), findsOneWidget);
      expect(find.text('v-a'), findsOneWidget);
      await tester.tap(find.byKey(const Key('charts.assets.simple.select')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('s B').last);
      await tester.pumpAndSettle();
      expect(find.text('s-b'), findsOneWidget);
      expect(mem.values.keys, [ChartPreferenceStore.keyFor('acc-1', ChartPanelId.assets)]);
      expect(mem.values.keys.single, isNot(contains('@')));
      // Vuelve a abrirse la pantalla
      await tester.pumpWidget(const SizedBox());
      await _pump(tester, panel());
      expect(find.text('s-b'), findsOneWidget);
      expect(find.text('v-a'), findsOneWidget);
    });

    testWidgets('sin permiso: ningún selector y siempre los predeterminados, aunque haya una elección guardada', (
      tester,
    ) async {
      final mem = InMemorySecureKeyValueStore()
        ..values[ChartPreferenceStore.keyFor('acc-1', ChartPanelId.assets)] = '{"simple":"b","advanced":"b"}';
      await _pump(
        tester,
        ChartPanel(
          panel: ChartPanelId.assets,
          simple: opts('s'),
          advanced: opts('v'),
          canChoose: false,
          store: ChartPreferenceStore(mem),
          accountId: 'acc-1',
        ),
      );
      expect(find.byType(DropdownButton<String>), findsNothing);
      expect(find.text('s-a'), findsOneWidget);
      expect(find.text('s-b'), findsNothing);
    });

    testWidgets('un almacenamiento roto no rompe nada: predeterminados y se puede cambiar el tipo', (tester) async {
      await _pump(
        tester,
        ChartPanel(
          panel: ChartPanelId.prediction,
          simple: opts('s'),
          advanced: opts('v'),
          canChoose: true,
          store: ChartPreferenceStore(_BrokenStore()),
          accountId: 'acc-1',
        ),
      );
      expect(find.text('s-a'), findsOneWidget);
      await tester.tap(find.byKey(const Key('charts.prediction.simple.select')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('s B').last);
      await tester.pumpAndSettle();
      expect(find.text('s-b'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('la clave lleva el accountId opaco; dos cuentas en el mismo teléfono no comparten la elección', () async {
      expect(ChartPreferenceStore.keyFor('acc-1', ChartPanelId.assets), 'paxfide.charts.v1.acc-1.assets');
      final store = ChartPreferenceStore(InMemorySecureKeyValueStore());
      await store.write('acc-1', ChartPanelId.assets, const ChartChoice(simple: 'b'));
      final other = await store.read('acc-2', ChartPanelId.assets, simple: ['a', 'b'], advanced: ['a', 'b']);
      expect(other.simple, isNull);
    });

    test('un valor guardado que ya no existe se ignora', () async {
      final mem = InMemorySecureKeyValueStore()
        ..values[ChartPreferenceStore.keyFor('acc-1', ChartPanelId.assets)] = '{"simple":"no-existe","advanced":"b"}';
      final c = await ChartPreferenceStore(mem)
          .read('acc-1', ChartPanelId.assets, simple: ['a', 'b'], advanced: ['a', 'b']);
      expect(c.simple, isNull);
      expect(c.advanced, 'b');
    });

    test('quién elige: lotes ADMINISTRATOR y EMPLOYEE; predicción ADMINISTRATOR y REPRESENTATIVE', () {
      expect(canChooseAssetCharts({'ADMINISTRATOR'}), isTrue);
      expect(canChooseAssetCharts({'EMPLOYEE'}), isTrue);
      expect(canChooseAssetCharts({'REPRESENTATIVE'}), isFalse);
      expect(canChoosePredictionCharts({'ADMINISTRATOR'}), isTrue);
      expect(canChoosePredictionCharts({'REPRESENTATIVE'}), isTrue);
      expect(canChoosePredictionCharts({'EMPLOYEE'}), isFalse);
    });
  });

  group('paneles', () {
    testWidgets('lotes: EMPLOYEE elige; un REPRESENTATIVE no tendría selector (aserción negativa)', (tester) async {
      final store = ChartPreferenceStore(InMemorySecureKeyValueStore());
      await _pump(tester, AssetsChartsPanel(items: _assets, principal: _p(['EMPLOYEE']), store: store));
      expect(find.byKey(const Key('charts.assets.simple.vbars')), findsOneWidget);
      expect(find.byKey(const Key('charts.assets.advanced.stateByType')), findsOneWidget);
      expect(find.byKey(const Key('charts.assets.simple.select')), findsOneWidget);
      await _pump(tester, AssetsChartsPanel(items: _assets, principal: _p(['REPRESENTATIVE'], 'acc-2'), store: store));
      expect(find.byType(DropdownButton<String>), findsNothing);
    });

    testWidgets('predicción: por defecto, probabilidad por corte y el combinado; el corte sin cifra no se rellena', (
      tester,
    ) async {
      final store = ChartPreferenceStore(InMemorySecureKeyValueStore());
      await _pump(tester, PredictionChartsPanel(cuts: _history.cuts, principal: _p(['REPRESENTATIVE']), store: store));
      expect(_semantics(tester, 'prediction.probBars.chart'), contains('50 % del tiempo sin dato'));
      expect(_semantics(tester, 'prediction.cuts.chart'), contains('Final estimado en el corte: 15 % del tiempo 80 %'));
      expect(find.byKey(const Key('charts.prediction.simple.select')), findsOneWidget);
    });
  });
}
