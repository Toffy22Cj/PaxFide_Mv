import 'package:flutter/material.dart';

/// Movimiento de PaxFide: los mismos tiempos y curvas que la web (`globals.css`, `movimiento.html`).
///
/// Reglas de fluidez que siguen todas las animaciones de la app:
/// - una sola `AnimationController` por pieza y pintura con `CustomPainter(repaint: controller)` dentro de un
///   `RepaintBoundary`: cada fotograma repinta solo esa pieza, sin reconstruir widgets;
/// - los bucles se apagan solos fuera de pantalla (`TickerMode`) y con «reducir movimiento» del teléfono se quedan en
///   un fotograma fijo ([reduce]).
abstract final class PaxMotion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 450);

  /// `--ease-standard` (0.4, 0, 0.2, 1).
  static const Curve standard = Cubic(0.4, 0, 0.2, 1);

  /// `--ease-out` (0.22, 1, 0.36, 1): entradas.
  static const Curve out = Cubic(0.22, 1, 0.36, 1);

  /// `--ease-in-out` (0.645, 0.045, 0.355, 1): ida y vuelta.
  static const Curve inOut = Cubic(0.645, 0.045, 0.355, 1);

  /// `--ease-spring` (0.175, 0.885, 0.32, 1.275): rebote corto.
  static const Curve spring = Cubic(0.175, 0.885, 0.32, 1.275);

  /// Animaciones que no terminan nunca (camión del seguimiento, ciudad de Inicio). Las pruebas lo apagan para que
  /// `pumpAndSettle` termine; en la app siempre está encendido.
  static bool ambient = true;

  /// «Reducir movimiento» del teléfono (o animaciones desactivadas en accesibilidad).
  static bool reduce(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// Duración que respeta [reduce]: cero si la persona pidió menos movimiento.
  static Duration of(BuildContext context, Duration d) => reduce(context) ? Duration.zero : d;
}

/// Bucle de una pieza animada: arranca o se queda quieto según [PaxMotion.reduce] y [PaxMotion.ambient] cada vez que
/// cambian las dependencias, sin reconstruir nada en cada fotograma.
mixin PaxLoopMixin<T extends StatefulWidget> on State<T>, SingleTickerProviderStateMixin<T> {
  late final AnimationController loop = AnimationController(vsync: this, duration: loopDuration);

  Duration get loopDuration;

  /// `true` para bucles que se ven mientras la pantalla está quieta (no solo mientras carga): respetan
  /// [PaxMotion.ambient].
  bool get ambientLoop => false;

  /// Valor del fotograma fijo con movimiento reducido.
  double get stillValue => 0.35;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = PaxMotion.reduce(context) || (ambientLoop && !PaxMotion.ambient);
    if (still) {
      loop
        ..stop()
        ..value = stillValue;
    } else if (!loop.isAnimating) {
      loop.repeat();
    }
  }

  @override
  void dispose() {
    loop.dispose();
    super.dispose();
  }
}
