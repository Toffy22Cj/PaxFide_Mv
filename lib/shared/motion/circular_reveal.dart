import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'pax_motion.dart';

/// «Revelado circular» de `movimiento.html`: un círculo de color crece desde [origin] (500 ms, ida y vuelta cúbica),
/// muestra [child] un momento y se desvanece. Un solo reloj, sin temporizadores. Con «reducir movimiento» no se
/// muestra.
class CircularReveal extends StatefulWidget {
  const CircularReveal({super.key, required this.origin, required this.color, required this.child, this.onEnd});

  /// Centro del círculo, en coordenadas de este widget.
  final Offset? origin;
  final Color color;
  final Widget child;
  final VoidCallback? onEnd;

  /// Duración total: 500 ms de círculo, una pausa para leer y la salida.
  static const total = Duration(milliseconds: 1400);

  @override
  State<CircularReveal> createState() => _CircularRevealState();
}

class _CircularRevealState extends State<CircularReveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: CircularReveal.total)
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onEnd?.call();
    });
  // 0–36 %: crece; 36–80 %: se lee; 80–100 %: se va.
  late final Animation<double> _grow = CurvedAnimation(
    parent: _c,
    curve: const Interval(0, 0.36, curve: Curves.easeInOutCubic),
  );
  late final Animation<double> _fade = Tween(begin: 1.0, end: 0.0).animate(
    CurvedAnimation(
      parent: _c,
      curve: const Interval(0.8, 1, curve: PaxMotion.standard),
    ),
  );
  late final Animation<double> _content = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.3, 0.45, curve: PaxMotion.out),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c.isAnimating || _c.isCompleted) return;
    if (PaxMotion.reduce(context)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onEnd?.call());
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final size = box.biggest;
      final o = widget.origin ?? size.center(Offset.zero);
      // Radio hasta la esquina más lejana: el círculo llega a cubrir todo.
      final far = [
        Offset.zero,
        Offset(size.width, 0),
        Offset(0, size.height),
        Offset(size.width, size.height),
      ].map((c) => (c - o).distance).reduce(math.max);
      return IgnorePointer(
        child: FadeTransition(
          opacity: _fade,
          child: AnimatedBuilder(
            animation: _grow,
            child: ColoredBox(
              color: widget.color,
              child: FadeTransition(
                opacity: _content,
                child: ScaleTransition(
                  scale: Tween(begin: 0.9, end: 1.0).animate(_content),
                  child: Center(child: widget.child),
                ),
              ),
            ),
            builder: (context, child) => ClipPath(clipper: _Circle(o, far * _grow.value), child: child),
          ),
        ),
      );
    },
  );
}

class _Circle extends CustomClipper<Path> {
  const _Circle(this.center, this.radius);
  final Offset center;
  final double radius;

  @override
  Path getClip(Size size) => Path()..addOval(Rect.fromCircle(center: center, radius: radius));

  @override
  bool shouldReclip(_Circle old) => old.center != center || old.radius != radius;
}
