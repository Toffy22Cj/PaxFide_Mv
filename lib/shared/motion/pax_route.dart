import 'package:flutter/cupertino.dart';

import 'pax_motion.dart';

/// Ruta suelta (fuera del router) con la transición «deslizar»: la de iOS a 350 ms, con vuelta deslizando desde el
/// borde. Para las pantallas que reciben datos en memoria (el código de seguimiento nunca va en una ruta).
class PaxPageRoute<T> extends CupertinoPageRoute<T> {
  PaxPageRoute({required super.builder, super.fullscreenDialog});

  @override
  Duration get transitionDuration => const Duration(milliseconds: 350);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => PaxMotion.reduce(context) ? child : super.buildTransitions(context, animation, secondaryAnimation, child);
}
