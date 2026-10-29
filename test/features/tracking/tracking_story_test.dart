import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/features/tracking/data/tracking_api.dart';
import 'package:paxfide_mobile/features/tracking/domain/tracking_story.dart';
import 'package:paxfide_mobile/features/tracking/presentation/tracking_story_view.dart';
import 'package:paxfide_mobile/shared/motion/pax_motion.dart';
import 'package:paxfide_mobile/shared/theme/pax_theme.dart';

LogisticsItem lot(String ref, {String? parent, String status = 'REGISTERED', String type = 'BLANKET'}) => LogisticsItem(
  assetRef: ref,
  lifecycleStatus: status,
  assetType: type,
  unitOfMeasure: 'UNITS',
  quantity: '6',
  locationZone: '',
  custodianCategory: 'LOCAL_ALLY',
  parentAssetRef: parent,
);

HistoryEntry step(String type) => HistoryEntry(
  eventType: type,
  timestamp: '2026-10-07T10:00:00Z',
  locationZone: 'Zona norte',
  custodianCategory: 'LOCAL_ALLY',
  status: 'X',
);

void main() {
  List<String> refs(List<TreeNode<LogisticsItem>> n) => [for (final x in n) x.item.assetRef];

  test('árbol: sublotes bajo su lote; un padre ausente, propio o en ciclo hace de raíz', () {
    final items = [
      lot('A'),
      lot('B', parent: 'A'),
      lot('C', parent: 'B'),
      lot('D', parent: 'NO'),
      lot('E', parent: 'E'),
      lot('F', parent: 'G'),
      lot('G', parent: 'F'),
    ];
    final roots = buildAssetTree<LogisticsItem>(items, ref: (i) => i.assetRef, parent: (i) => i.parentAssetRef);
    expect(refs(roots), ['A', 'D', 'E', 'F', 'G']);
    expect(refs(roots.first.children), ['B']);
    expect(refs(roots.first.children.first.children), ['C']);
  });

  test('el camión solo si el último evento es un despacho; etiquetas de los eventos', () {
    expect(showsTruck(['ASSET_REGISTERED', 'ASSET_DISPATCHED']), isTrue);
    expect(showsTruck(['ASSET_DISPATCHED', 'ASSET_RECEIVED']), isFalse);
    expect(showsTruck([]), isFalse);
    expect(eventLabel('ASSET_SPLIT_COMPENSATED'), 'División revertida');
    expect(eventLabel('NUEVO'), 'NUEVO');
  });

  Future<void> pump(WidgetTester tester, Widget w) async {
    PaxMotion.ambient = false;
    addTearDown(() => PaxMotion.ambient = true);
    await tester.pumpWidget(
      MaterialApp(
        theme: PaxTheme.light,
        home: Scaffold(
          body: ListView(padding: const EdgeInsets.all(16), children: [w]),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  const payment = PaymentFacts(firstClearedAt: '2026-10-01T10:00:00Z', amount: 6000000, currency: 'COP');

  testWidgets('árbol: Donada, lote con su sublote y camión si va en camino', (tester) async {
    await pump(
      tester,
      TrackingTree(
        items: [
          lot('A'),
          lot('B', parent: 'A', type: 'KIT'),
        ],
        payment: payment,
        histories: {
          'A': HistoryReady([step('ASSET_REGISTERED'), step('ASSET_SPLIT')]),
          'B': HistoryReady([step('ASSET_REGISTERED'), step('ASSET_DISPATCHED')]),
        },
        onRetry: (_) {},
      ),
    );
    expect(find.text('Donada'), findsOneWidget);
    expect(find.text('SUBLOTE'), findsOneWidget);
    expect(find.byKey(const Key('tracking.truck')), findsOneWidget);
    await tester.tap(find.byKey(const Key('tracking.root')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tracking.detail.payment')), findsOneWidget);
    expect(find.text('60 000,00 COP'), findsWidgets);
  });

  testWidgets('árbol: un recorrido que falla se puede reintentar', (tester) async {
    String? retried;
    await pump(
      tester,
      TrackingTree(
        items: [lot('A')],
        payment: payment,
        histories: {'A': const HistoryFailed()},
        onRetry: (r) => retried = r,
      ),
    );
    await tester.tap(find.text('Reintentar'));
    expect(retried, 'A');
  });

  testWidgets('serpiente: una estación por paso más el pago, pestañas por lote y el camión', (tester) async {
    await pump(
      tester,
      SnakeRoute(
        items: [
          lot('A'),
          lot('B', type: 'KIT'),
        ],
        payment: payment,
        histories: {
          'A': HistoryReady([step('ASSET_REGISTERED'), step('ASSET_DISPATCHED')]),
          'B': HistoryReady([step('ASSET_REGISTERED')]),
        },
      ),
    );
    expect(find.text('Pago confirmado'), findsOneWidget);
    expect(find.text('Despachado'), findsOneWidget);
    expect(find.textContaining('3 estaciones'), findsOneWidget);
    expect(find.byKey(const Key('tracking.snake.truck')), findsOneWidget);
    await tester.tap(find.byKey(const Key('tracking.snake.tab.1')));
    await tester.pumpAndSettle();
    expect(find.textContaining('2 estaciones'), findsOneWidget);
    await tester.tap(find.byKey(const Key('tracking.station.0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tracking.detail.step')), findsOneWidget);
  });
}
