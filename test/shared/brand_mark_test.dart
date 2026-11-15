import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/features/auth/presentation/auth_layout.dart';
import 'package:paxfide_mobile/shared/widgets/brand_mark.dart';

Future<void> _pumpAt(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MaterialApp(home: AuthLayout(title: 'Entrar', child: SizedBox())));
}

void main() {
  test('el emblema está declarado en pubspec y existe en el bundle', () async {
    final data = await rootBundle.load(BrandMark.asset);
    expect(data.lengthInBytes, greaterThan(0));
  });

  testWidgets('móvil: emblema y nombre encima del formulario', (tester) async {
    await _pumpAt(tester, const Size(390, 844));
    expect(find.byKey(const Key('brand.mark')), findsOneWidget);
    expect(find.text('PaxFide'), findsOneWidget);
    expect(tester.getSize(find.byKey(const Key('brand.mark'))), const Size(56, 56));
    // decorativo: el nombre ya está en texto
    expect((tester.widget(find.byKey(const Key('brand.mark'))) as Image).excludeFromSemantics, isTrue);
  });

  testWidgets('ancho: emblema en el panel de marca, una sola vez', (tester) async {
    await _pumpAt(tester, const Size(1280, 800));
    expect(find.byKey(const Key('brand.mark')), findsOneWidget);
    expect(tester.getSize(find.byKey(const Key('brand.mark'))), const Size(120, 120));
    expect(find.byIcon(Icons.volunteer_activism), findsNothing);
  });
}
