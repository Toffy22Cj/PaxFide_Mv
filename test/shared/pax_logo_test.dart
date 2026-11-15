import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/shared/widgets/pax_logo.dart';

void main() {
  test('el emblema está declarado en pubspec y existe en el bundle', () async {
    final data = await rootBundle.load(PaxLogo.asset);
    expect(data.lengthInBytes, greaterThan(0));
  });

  for (final dark in [false, true]) {
    testWidgets('PaxLogo muestra el emblema oficial al tamaño pedido (${dark ? 'oscuro' : 'claro'})', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light),
        home: const Center(child: PaxLogo(size: 34)),
      ));
      expect(tester.getSize(find.byKey(const Key('pax.logo'))), const Size(34, 34));
      final image = tester.widget<Image>(find.descendant(of: find.byKey(const Key('pax.logo')), matching: find.byType(Image)));
      expect((image.image as AssetImage).assetName, PaxLogo.asset);
      expect(find.bySemanticsLabel('PaxFide, donaciones que llegan'), findsOneWidget);
    });
  }
}
