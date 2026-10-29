import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../motion/pax_motion.dart';
import '../theme/pax_tokens.dart';

/// Cargas de PaxFide, las mismas de la web (`components/loaders`): cubos encadenados, camión en ruta, árbol de
/// Merkle, puntos de marca y esqueleto. Cada una es un `CustomPainter` que repinta con su propia animación dentro de
/// un `RepaintBoundary`: no reconstruye widgets en cada fotograma.

/// Valor de una animación por fotogramas clave (`@keyframes`): [frames] son pares (momento 0–1, valor), en orden.
double keyframes(double t, List<(double, double)> frames, [Curve curve = Curves.linear]) {
  if (t <= frames.first.$1) return frames.first.$2;
  for (var i = 1; i < frames.length; i++) {
    final (at, v) = frames[i];
    if (t <= at) {
      final (from, u) = frames[i - 1];
      final k = at == from ? 1.0 : curve.transform((t - from) / (at - from));
      return u + (v - u) * k;
    }
  }
  return frames.last.$2;
}

abstract class _LoopPainterWidget extends StatefulWidget {
  const _LoopPainterWidget({super.key, this.semanticsLabel});

  /// Sin etiqueta, la carga es decorativa (el texto de al lado ya la nombra).
  final String? semanticsLabel;
}

abstract class _LoopPainterState<T extends _LoopPainterWidget> extends State<T>
    with SingleTickerProviderStateMixin<T>, PaxLoopMixin<T> {
  Size get size;
  CustomPainter painter(BuildContext context);

  @override
  Widget build(BuildContext context) {
    final paint = RepaintBoundary(
      child: CustomPaint(size: size, painter: painter(context)),
    );
    final label = widget.semanticsLabel;
    return label == null ? ExcludeSemantics(child: paint) : Semantics(label: label, child: paint);
  }
}

// ---------------------------------------------------------------- 01 · Cubos encadenados

/// 01 Cubos encadenados: tres cubos que saltan en secuencia (dos azules y uno verde). La carga de pantalla.
class ChainCubesLoader extends _LoopPainterWidget {
  const ChainCubesLoader({super.key, super.semanticsLabel});

  @override
  State<ChainCubesLoader> createState() => _ChainCubesState();
}

class _ChainCubesState extends _LoopPainterState<ChainCubesLoader> {
  @override
  Duration get loopDuration => PaxMotion.normal * 4;

  @override
  double get stillValue => 0;

  @override
  Size get size => const Size(138, 46);

  @override
  CustomPainter painter(BuildContext context) => _ChainCubesPainter(loop);
}

class _ChainCubesPainter extends CustomPainter {
  _ChainCubesPainter(this.t) : super(repaint: t);
  final Animation<double> t;

  static final Path _top = Path()..addPolygon(const [Offset(15, 2), Offset(28, 9), Offset(15, 16), Offset(2, 9)], true);
  static final Path _left = Path()
    ..addPolygon(const [Offset(2, 9), Offset(15, 16), Offset(15, 32), Offset(2, 25)], true);
  static final Path _right = Path()
    ..addPolygon(const [Offset(28, 9), Offset(15, 16), Offset(15, 32), Offset(28, 25)], true);
  static final _blue = [PaxTokens.brandBlue500, PaxTokens.brandBlue800, PaxTokens.brandBlue700];
  static final _green = [PaxTokens.brandGreen500, PaxTokens.brandGreen900, PaxTokens.brandGreen800];
  static final _paint = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    const delays = [0.0, 0.125, 0.25]; // fast y normal sobre un ciclo de 4 × normal
    for (var i = 0; i < 3; i++) {
      final p = (t.value - delays[i]) % 1.0;
      final y = keyframes(p, const [(0, 0), (0.25, -12), (0.4, 0), (1, 0)], PaxMotion.standard);
      final sy = keyframes(p, const [(0, 1), (0.25, 1), (0.4, 0.9), (0.6, 1), (1, 1)], PaxMotion.standard);
      final x = i * 54.0;
      canvas
        ..save()
        ..translate(x, 12 + y + 34 * (1 - sy))
        ..scale(1, sy);
      final colors = i == 2 ? _green : _blue;
      canvas
        ..drawPath(_top, _paint..color = colors[0])
        ..drawPath(_left, _paint..color = colors[1])
        ..drawPath(_right, _paint..color = colors[2])
        ..restore();
      if (i < 2) {
        final o = keyframes((t.value - delays[i]) % 1.0, const [(0, 0.25), (0.35, 1), (1, 0.25)]);
        canvas.drawRRect(
          RRect.fromLTRBR(x + 36, 12 + 15.5, x + 48, 12 + 18.5, const Radius.circular(2)),
          _paint..color = PaxTokens.brandBlue500.withValues(alpha: o),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_ChainCubesPainter old) => old.t != t;
}

// ---------------------------------------------------------------- 03 · Camión en ruta

/// 03 Camión en ruta: el camión de PaxFide con la carretera en movimiento. Se ve mientras un lote va en camino, así
/// que es un bucle «de ambiente» ([PaxMotion.ambient]).
class TruckLoader extends _LoopPainterWidget {
  const TruckLoader({super.key, super.semanticsLabel = 'En camino', this.width = 200});
  final double width;

  @override
  State<TruckLoader> createState() => _TruckState();
}

class _TruckState extends _LoopPainterState<TruckLoader> {
  @override
  Duration get loopDuration => PaxMotion.fast * 4;

  @override
  bool get ambientLoop => true;

  @override
  Size get size => Size(widget.width, 60);

  @override
  CustomPainter painter(BuildContext context) =>
      TruckPainter(loop, road: Theme.of(context).colorScheme.outline, hub: PaxTokens.brandGreen50);
}

/// Pinta el camión (y su carretera, si [road] no es nulo) a lo ancho del lienzo. Lo usa también el árbol del
/// seguimiento.
class TruckPainter extends CustomPainter {
  TruckPainter(this.t, {this.road, required this.hub}) : super(repaint: t);
  final Animation<double> t;
  final Color? road;
  final Color hub;

  static final _paint = Paint();
  static final Path _logo = Path()
    ..moveTo(15, 24.5)
    ..relativeCubicTo(-3, -2, -4.2, -3.7, -3.5, -5.2)
    ..relativeCubicTo(.6, -1.2, 2, -1.1, 3.5, .4)
    ..relativeCubicTo(1.4, -1, 2.8, -.6, 3.3, .8)
    ..relativeCubicTo(.6, 1.5, -.5, 2.9, -3.3, 4)
    ..close();
  static final Path _cab = Path()
    ..addPolygon(const [Offset(40, 14), Offset(52, 14), Offset(61, 23), Offset(61, 30), Offset(40, 30)], true);
  static final Path _window = Path()
    ..addPolygon(const [Offset(43, 16), Offset(51, 16), Offset(57, 22), Offset(43, 22)], true);

  /// Dibuja solo el camión (66 × 42) en el origen del lienzo.
  static void drawTruck(Canvas canvas, Color hub) {
    canvas
      ..drawRRect(RRect.fromLTRBR(2, 8, 40, 30, const Radius.circular(3)), _paint..color = PaxTokens.brandYellow400)
      ..drawRRect(RRect.fromLTRBR(2, 8, 40, 13, const Radius.circular(2)), _paint..color = PaxTokens.brandYellow900)
      ..drawPath(_logo, _paint..color = PaxTokens.brandGreen900)
      ..drawPath(_cab, _paint..color = PaxTokens.brandGreen800)
      ..drawPath(_window, _paint..color = PaxTokens.brandBlue50)
      ..drawRRect(RRect.fromLTRBR(0, 29, 63, 32, const Radius.circular(1.5)), _paint..color = PaxTokens.brandGreen900)
      ..drawCircle(const Offset(14, 34), 6, _paint)
      ..drawCircle(const Offset(51, 34), 6, _paint)
      ..drawCircle(const Offset(14, 34), 2, _paint..color = hub)
      ..drawCircle(const Offset(51, 34), 2, _paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final v = t.value;
    if (road case final Color c) {
      final y = size.height - 15;
      final dx = -20 * v;
      _paint.color = c;
      for (var x = dx; x < size.width; x += 20) {
        canvas.drawRect(Rect.fromLTWH(math.max(0, x), y, (x + 10).clamp(0, size.width) - math.max(0, x), 3), _paint);
      }
    }
    // Rebote de 2 px cada `normal` (dos por ciclo).
    final bump = -2 * math.sin(math.pi * ((v * 2) % 1.0));
    const scale = 70 / 66;
    canvas
      ..save()
      ..translate((size.width - 70) / 2 - 3, size.height - 14 - 42 * scale + bump)
      ..scale(scale);
    drawTruck(canvas, hub);
    canvas.restore();
  }

  @override
  bool shouldRepaint(TruckPainter old) => old.t != t || old.road != road || old.hub != hub;
}

// ---------------------------------------------------------------- 09 · Árbol de Merkle

/// 09 Árbol de Merkle: hojas, ramas y raíz dorada que aparecen en orden. Mientras se verifica la integridad.
class MerkleTreeLoader extends _LoopPainterWidget {
  const MerkleTreeLoader({super.key, super.semanticsLabel = 'Verificando integridad'});

  @override
  State<MerkleTreeLoader> createState() => _MerkleState();
}

class _MerkleState extends _LoopPainterState<MerkleTreeLoader> {
  @override
  Duration get loopDuration => PaxMotion.slow * 6;

  @override
  double get stillValue => 0.7;

  @override
  Size get size => const Size(150, 110);

  @override
  CustomPainter painter(BuildContext context) => _MerklePainter(loop);
}

class _MerklePainter extends CustomPainter {
  _MerklePainter(this.t) : super(repaint: t);
  final Animation<double> t;

  static final _fill = Paint();
  static final _edge = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  static final Path _edges = Path()
    ..moveTo(24, 86)
    ..lineTo(48, 56)
    ..moveTo(58, 86)
    ..lineTo(48, 56)
    ..moveTo(92, 86)
    ..lineTo(102, 56)
    ..moveTo(126, 86)
    ..lineTo(102, 56)
    ..moveTo(48, 56)
    ..lineTo(75, 24)
    ..moveTo(102, 56)
    ..lineTo(75, 24);

  void _node(Canvas c, Rect r, double radius, double s, Color color) {
    if (s <= 0) return;
    final scaled = Rect.fromCenter(center: r.center, width: r.width * s, height: r.height * s);
    c.drawRRect(RRect.fromRectAndRadius(scaled, Radius.circular(radius * s)), _fill..color = color);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final v = t.value;
    final edge = keyframes(v, const [(0, 0), (0.22, 0), (0.35, 1), (0.88, 1), (1, 0)], PaxMotion.out);
    canvas.drawPath(_edges, _edge..color = PaxTokens.brandBlue700.withValues(alpha: edge.clamp(0, 1)));
    const leafDelays = [0.0, 0.0278, 0.0556, 0.0833]; // 0, ½, 1 y 1½ × fast sobre 6 × slow
    for (var i = 0; i < 4; i++) {
      final s = keyframes((v - leafDelays[i]) % 1.0, const [(0, 0), (0.12, 1), (0.88, 1), (1, 0)], PaxMotion.spring);
      _node(canvas, Rect.fromLTWH(14 + 34.0 * i, 78, 20, 20), 4, s, PaxTokens.brandBlue700);
    }
    final b = keyframes(v, const [(0, 0), (0.25, 0), (0.38, 1), (0.88, 1), (1, 0)], PaxMotion.spring);
    _node(canvas, const Rect.fromLTWH(37, 45, 22, 22), 5, b, PaxTokens.brandBlue800);
    _node(canvas, const Rect.fromLTWH(91, 45, 22, 22), 5, b, PaxTokens.brandBlue800);
    final r = keyframes(v, const [(0, 0), (0.48, 0), (0.6, 1), (0.88, 1), (1, 0)], PaxMotion.spring);
    _node(canvas, const Rect.fromLTWH(61, 10, 28, 28), 7, r, PaxTokens.brandYellow400);
  }

  @override
  bool shouldRepaint(_MerklePainter old) => old.t != t;
}

// ---------------------------------------------------------------- 06 · Puntos de marca

/// 06 Puntos de marca: verde, azul y amarillo con desfase. Sustituye al círculo de carga dentro de los botones.
class BrandDots extends _LoopPainterWidget {
  const BrandDots({super.key, super.semanticsLabel, this.color});

  /// Color del primer punto (el del texto del botón); por defecto, el `onPrimary` del tema.
  final Color? color;

  @override
  State<BrandDots> createState() => _BrandDotsState();
}

class _BrandDotsState extends _LoopPainterState<BrandDots> {
  @override
  Duration get loopDuration => PaxMotion.slow * 2;

  @override
  Size get size => const Size(31, 14);

  @override
  CustomPainter painter(BuildContext context) {
    final first = widget.color ?? Theme.of(context).colorScheme.onPrimary;
    return _DotsPainter(loop, [first, PaxTokens.brandBlue500, PaxTokens.brandYellow400]);
  }
}

class _DotsPainter extends CustomPainter {
  _DotsPainter(this.t, this.colors) : super(repaint: t);
  final Animation<double> t;
  final List<Color> colors;
  static final _paint = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 3; i++) {
      final p = (t.value - i * 0.1333) % 1.0; // 0,8 × fast de desfase sobre 2 × slow
      final k = keyframes(p, const [(0, 0), (0.4, 1), (0.8, 0), (1, 0)], PaxMotion.standard);
      _paint.color = colors[i].withValues(alpha: 0.55 + 0.45 * k);
      canvas.drawCircle(Offset(3.5 + 12.0 * i, size.height - 3.5 - 6 * k), 3.5, _paint);
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) => old.t != t || old.colors != colors;
}

// ---------------------------------------------------------------- 07 · Esqueleto

/// 07 Esqueleto: la forma de lo que va a aparecer, con un brillo que la recorre. Un solo brillo para todo el grupo
/// ([children] son [SkeletonBox]), así todas las barras brillan a la vez y con un único reloj.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, required this.child, this.semanticsLabel = 'Cargando'});
  final Widget child;
  final String semanticsLabel;

  /// Tarjeta simulada: imagen y tres líneas (convocatorias).
  static Widget card({Key? key, String label = 'Cargando convocatorias'}) => Skeleton(
    key: key,
    semanticsLabel: label,
    child: const Padding(
      padding: EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(height: 62, radius: 10),
          SizedBox(height: 8),
          SkeletonBox(height: 10, widthFactor: 0.7),
          SizedBox(height: 8),
          SkeletonBox(height: 10, widthFactor: 0.45),
          SizedBox(height: 8),
          SkeletonBox(height: 8, widthFactor: 0.3, radius: 99),
        ],
      ),
    ),
  );

  /// Lista simulada de [count] filas con icono y dos líneas.
  static Widget list({Key? key, int count = 3, String label = 'Cargando'}) => Skeleton(
    key: key,
    semanticsLabel: label,
    child: Column(
      children: [
        for (var i = 0; i < count; i++)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                SkeletonBox(width: 32, height: 32, radius: 8),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(height: 10, widthFactor: 0.6),
                      SizedBox(height: 6),
                      SkeletonBox(height: 8, widthFactor: 0.35),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin<Skeleton>, PaxLoopMixin<Skeleton> {
  @override
  Duration get loopDuration => PaxMotion.slow * 3;

  /// Ocupa el sitio del contenido mientras llega, a veces un rato: cuenta como bucle de ambiente.
  @override
  bool get ambientLoop => true;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final base = s.outlineVariant;
    final shine = s.surfaceContainerLowest;
    return Semantics(
      label: widget.semanticsLabel,
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: loop,
            // El hijo (las barras) se construye una vez; cada fotograma solo cambia el sombreador.
            child: widget.child,
            builder: (context, child) {
              // El brillo cruza la pieza de derecha a izquierda, como el `background-position` de la web.
              final p = 1 - 2 * PaxMotion.inOut.transform(loop.value);
              return ShaderMask(
                blendMode: BlendMode.srcATop,
                shaderCallback: (r) => LinearGradient(
                  colors: [base, shine, base],
                  stops: const [0.2, 0.5, 0.8],
                  transform: _SlideGradient(p),
                ).createShader(r),
                child: child,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SlideGradient extends GradientTransform {
  const _SlideGradient(this.p);
  final double p;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) => Matrix4.translationValues(bounds.width * p, 0, 0);
}

/// Barra del esqueleto: solo forma (el brillo lo pone el [Skeleton] que la contiene).
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, this.height = 12, this.widthFactor, this.radius = 4});
  final double? width;
  final double height;
  final double? widthFactor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.outlineVariant,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
    return widthFactor == null ? box : FractionallySizedBox(widthFactor: widthFactor, child: box);
  }
}
