import 'package:flutter/cupertino.dart';

import '../../shared/motion/pax_motion.dart';

/// Cómo entra una pantalla (`movimiento.html`, transiciones de pantalla).
enum PaxTransition {
  /// 01 Deslizar (350 ms): de una lista a su detalle. La de atrás se corre un 30 %. Se vuelve deslizando desde el
  /// borde izquierdo.
  slide,

  /// 02 Fundido intermedio (300 ms): cambiar de pestaña. La barra de pestañas es igual en las dos pantallas, así que
  /// solo se nota el cambio del contenido.
  fadeThrough,

  /// 03 Eje Z (300 ms): pasos de un mismo flujo (bienvenida, entrar, registrarse) y de entrar a Inicio.
  zAxis,
}

/// Página del router con la transición de PaxFide. Con «reducir movimiento» las transiciones son instantáneas.
class PaxPage<T> extends Page<T> {
  const PaxPage({required this.child, required this.transition, super.key, super.name});

  final Widget child;
  final PaxTransition transition;

  @override
  Route<T> createRoute(BuildContext context) => _PaxRoute<T>(this);
}

class _PaxRoute<T> extends PageRoute<T> with CupertinoRouteTransitionMixin<T> {
  _PaxRoute(PaxPage<T> page) : super(settings: page);

  PaxPage<T> get _page => settings as PaxPage<T>;
  PaxTransition get kind => _page.transition;

  @override
  Widget buildContent(BuildContext context) => _page.child;

  @override
  String? get title => null;

  @override
  bool get maintainState => true;

  @override
  bool get fullscreenDialog => false;

  @override
  Duration get transitionDuration => switch (kind) {
    PaxTransition.slide => const Duration(milliseconds: 350),
    _ => PaxMotion.normal,
  };

  @override
  Duration get reverseTransitionDuration => transitionDuration;

  /// Solo una pantalla que entra deslizando mueve a la de atrás (la corre un 30 %); las pestañas no la tocan.
  @override
  bool canTransitionTo(TransitionRoute<dynamic> nextRoute) =>
      nextRoute is _PaxRoute && nextRoute.kind == PaxTransition.slide;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (PaxMotion.reduce(context)) return child;
    switch (kind) {
      case PaxTransition.slide:
        // La de iOS: entra de 1 a 0, la de atrás va de 0 a −0,3 y se puede volver deslizando desde el borde.
        return CupertinoRouteTransitionMixin.buildPageTransitions(this, context, animation, secondaryAnimation, child);
      case PaxTransition.fadeThrough:
        return _behind(
          secondaryAnimation,
          FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: PaxMotion.standard),
            child: child,
          ),
        );
      case PaxTransition.zAxis:
        final a = CurvedAnimation(parent: animation, curve: PaxMotion.standard);
        return _behind(
          secondaryAnimation,
          FadeTransition(
            opacity: a,
            child: ScaleTransition(scale: Tween(begin: 0.92, end: 1.0).animate(a), child: child),
          ),
        );
    }
  }

  /// La parte de «la de atrás» cuando entra una pantalla deslizando encima.
  Widget _behind(Animation<double> secondary, Widget child) => CupertinoPageTransition(
    primaryRouteAnimation: kAlwaysCompleteAnimation,
    secondaryRouteAnimation: secondary,
    linearTransition: false,
    child: child,
  );
}
