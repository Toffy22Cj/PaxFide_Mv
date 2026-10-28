import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/core/errors/app_exceptions.dart';
import 'package:paxfide_mobile/core/network/api_response.dart';
import 'package:paxfide_mobile/features/donations/data/account_impact_api.dart';
import 'package:paxfide_mobile/features/donations/domain/impact.dart';
import 'package:paxfide_mobile/features/donations/presentation/impact_card.dart';

import '../../support/fakes.dart';

class _Source implements ImpactSource {
  const _Source(this.value);
  final Future<MyImpact?> Function() value;

  @override
  Future<MyImpact?> myImpact() => value();
}

Widget _app(ImpactSource s) => MaterialApp(
  home: Scaffold(body: ImpactCard(source: s)),
);

const _impact = {
  'donationsCount': 3,
  'totals': [
    {'currency': 'COP', 'amount': '25000000'},
  ],
  'campaignsSupported': 2,
  'deliveredUnits': [
    {'unitOfMeasure': 'kg', 'quantity': '120.5000'},
    {'unitOfMeasure': 'UNITS', 'quantity': '40.0000'},
  ],
  'truncated': false,
};

void main() {
  test('AccountImpactApi lee la respuesta del backend', () async {
    final api = FakeApiClient()..enqueue(const ApiResponse(statusCode: 200, data: _impact));
    final i = await AccountImpactApi(api).fetch();
    expect(api.calls.single.path, '/account/impact');
    expect(i.donationsCount, 3);
    expect(i.campaignsSupported, 2);
    expect(i.totals.single.amount, '25000000');
    expect(i.deliveredUnits.map((u) => u.unitOfMeasure), ['kg', 'UNITS']);
    expect(i.truncated, isFalse);
  });

  test('AccountImpactApi: sin las listas es una respuesta inesperada', () async {
    final api = FakeApiClient()
      ..enqueue(const ApiResponse(statusCode: 200, data: {'donationsCount': 1, 'campaignsSupported': 1}));
    expect(AccountImpactApi(api).fetch(), throwsA(isA<MalformedResponseException>()));
  });

  test('ApiImpactSource: una cuenta que nunca donó no tiene panel', () async {
    final api = FakeApiClient()
      ..enqueue(
        const ApiResponse(
          statusCode: 200,
          data: {'donationsCount': 0, 'totals': [], 'campaignsSupported': 0, 'deliveredUnits': [], 'truncated': false},
        ),
      );
    expect(await ApiImpactSource(AccountImpactApi(api)).myImpact(), isNull);
  });

  testWidgets('M-21: con datos muestra resumen, total y barras por unidad', (tester) async {
    final api = FakeApiClient()..enqueue(const ApiResponse(statusCode: 200, data: _impact));
    await tester.pumpWidget(_app(ApiImpactSource(AccountImpactApi(api))));
    await tester.pumpAndSettle();
    expect(find.text('3 donaciones confirmadas · 2 convocatorias apoyadas'), findsOneWidget);
    expect(find.text('Donado: 250 000,00 COP'), findsOneWidget);
    expect(find.text('Entregado en las convocatorias que apoyaste'), findsOneWidget);
    expect(find.text('kg: 120,5'), findsOneWidget);
    expect(find.text('UNITS: 40'), findsOneWidget);
    expect(find.byKey(const Key('impact.truncated')), findsNothing);
  });

  testWidgets('M-21: con más de 100 donaciones lo avisa', (tester) async {
    await tester.pumpWidget(
      _app(
        _Source(
          () async => const AccountImpactDto(
            donationsCount: 100,
            totals: [],
            campaignsSupported: 4,
            deliveredUnits: [],
            truncated: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('impact.truncated')), findsOneWidget);
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
