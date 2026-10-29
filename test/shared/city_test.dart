import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/shared/city/city_background.dart';
import 'package:paxfide_mobile/shared/city/city_painter.dart';
import 'package:paxfide_mobile/shared/city/city_scene.dart';
import 'package:paxfide_mobile/shared/motion/pax_motion.dart';

void main() {
  test('el generador da los mismos números que el de la web (mismo valle)', () {
    final r = cityRng(citySeed);
    expect(
      [r(), r(), r(), r()],
      [
        closeTo(0.6241667082067579, 1e-15),
        closeTo(0.7992063749115914, 1e-15),
        closeTo(0.4817302452865988, 1e-15),
        closeTo(0.2715193019248545, 1e-15),
      ],
    );
  });

  test('la escena: nada sembrado sobre el río, las calles ni los barrios', () {
    final s = CityScene.create();
    expect(s.tufts, hasLength(340));
    expect(s.wildTrees.length, lessThanOrEqualTo(58));
    for (final t in s.wildTrees) {
      expect(isFree(t.x, t.y, 0.45), isTrue);
    }
    final before = s.vehicles.first.pos;
    s.step(1);
    expect(s.vehicles.first.pos, isNot(before));
  });

  for (final (name, brightness) in [('día', Brightness.light), ('noche', Brightness.dark)]) {
    testWidgets('se dibuja de $name sin errores, quieta con «reducir movimiento»', (tester) async {
      final paused = ValueNotifier(false);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: SizedBox(width: 411, height: 260, child: CityBackground(paused: paused)),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(tester.hasRunningAnimations, isFalse);
    });
  }

  testWidgets('se anima y al pausarla se detiene', (tester) async {
    final paused = ValueNotifier(false);
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(width: 411, height: 260, child: CityBackground(paused: paused)),
      ),
    );
    expect(PaxMotion.ambient, isTrue);
    expect(tester.hasRunningAnimations, isTrue);
    final world = (tester.widget<CustomPaint>(find.byKey(const Key('city'))).painter! as CityPainter).world;
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 100));
    final t = world.t;
    expect(t, greaterThan(0));
    paused.value = true;
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.hasRunningAnimations, isFalse);
    expect(world.t, t);
  });
}
