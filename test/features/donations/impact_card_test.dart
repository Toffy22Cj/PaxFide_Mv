import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/features/donations/domain/impact.dart';
import 'package:paxfide_mobile/features/donations/presentation/impact_card.dart';

class _Source implements ImpactSource {
  const _Source(this.value);
  final Future<MyImpact?> Function() value;

  @override
  Future<MyImpact?> myImpact() => value();
}

Widget _app(ImpactSource s) => MaterialApp(
  home: Scaffold(body: ImpactCard(source: s)),
);

void main() {
  testWidgets('M-21: con datos muestra totales y barras por convocatoria', (tester) async {
    await tester.pumpWidget(
      _app(
        _Source(
          () async => const MyImpact(
            unitsDelivered: 12,
            distinctRecipients: 1,
            byCampaign: [CampaignImpact(campaignTitle: 'Abrigo', unitsDelivered: 12)],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('12 bienes entregados · 1 persona ayudada'), findsOneWidget);
    expect(find.text('Abrigo: 12 entregados'), findsOneWidget);
  });

  testWidgets('M-21: sin datos o con error no se muestra nada', (tester) async {
    await tester.pumpWidget(_app(const UnavailableImpactSource()));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('impact')), findsNothing);
    await tester.pumpWidget(_app(_Source(() => Future.error(Exception('x')))));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('impact')), findsNothing);
  });
}
