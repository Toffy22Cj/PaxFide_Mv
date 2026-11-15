import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/app/router/app_router_delegate.dart';
import 'package:paxfide_mobile/app/router/pax_page.dart';
import 'package:paxfide_mobile/shared/motion/pax_motion.dart';
import 'package:paxfide_mobile/shared/widgets/loaders.dart';

Widget _wrap(Widget child, {bool reduce = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduce),
    child: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  test('keyframes interpola entre fotogramas clave', () {
    const f = [(0.0, 0.0), (0.5, 10.0), (1.0, 0.0)];
    expect(keyframes(0, f), 0);
    expect(keyframes(0.25, f), 5);
    expect(keyframes(0.5, f), 10);
    expect(keyframes(0.75, f), 5);
    expect(keyframes(2, f), 0);
  });

  for (final (name, loader) in [
    ('cubos', const ChainCubesLoader()),
    ('Merkle', const MerkleTreeLoader()),
    ('puntos', const BrandDots()),
    ('esqueleto', Skeleton.list()),
  ]) {
    testWidgets('$name: se anima y con «reducir movimiento» se queda quieto', (tester) async {
      await tester.pumpWidget(_wrap(loader));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpWidget(_wrap(loader, reduce: true));
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
    });
  }

  testWidgets('camión: bucle de ambiente, apagado si PaxMotion.ambient es false', (tester) async {
    addTearDown(() => PaxMotion.ambient = true);
    PaxMotion.ambient = false;
    await tester.pumpWidget(_wrap(const TruckLoader()));
    expect(tester.hasRunningAnimations, isFalse);
    expect(find.bySemanticsLabel('En camino'), findsOneWidget);
  });

  test('transición por ruta: pestañas fundido, flujo de entrada eje Z, detalles deslizar', () {
    expect(AppRouterDelegate.transitionFor('/account'), PaxTransition.fadeThrough);
    expect(AppRouterDelegate.transitionFor('/donations'), PaxTransition.fadeThrough);
    expect(AppRouterDelegate.transitionFor('/operator/pending'), PaxTransition.fadeThrough);
    expect(AppRouterDelegate.transitionFor('/login'), PaxTransition.zAxis);
    expect(AppRouterDelegate.transitionFor('/home'), PaxTransition.zAxis);
    expect(AppRouterDelegate.transitionFor('/assets/abc'), PaxTransition.slide);
    expect(AppRouterDelegate.transitionFor('/c/ABC123'), PaxTransition.slide);
    expect(AppRouterDelegate.transitionFor('/tracking'), PaxTransition.slide);
  });
}
