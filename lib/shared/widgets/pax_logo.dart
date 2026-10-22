import 'package:flutter/material.dart';

import '../theme/pax_tokens.dart';

/// Logo de PaxFide (M-35), el mismo del landing web: el sol, la hoja verde y el corazón azul que abrazan una caja, y la
/// curva de la mano debajo. Dibujado en vector (sin imagen ni fondo blanco), así queda nítido a cualquier tamaño y se
/// integra con el fondo en claro y en oscuro. Colores de la paleta.
class PaxLogo extends StatelessWidget {
  const PaxLogo({super.key, this.size = 120});
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'PaxFide, donaciones que llegan',
    image: true,
    child: SizedBox(
      key: const Key('pax.logo'),
      width: size,
      height: size,
      child: CustomPaint(painter: _LogoPainter(dark: Theme.of(context).brightness == Brightness.dark)),
    ),
  );
}

class _LogoPainter extends CustomPainter {
  const _LogoPainter({required this.dark});
  final bool dark;

  static Color _mx(Color top, double a, Color base) => Color.alphaBlend(top.withValues(alpha: a), base);

  @override
  void paint(Canvas canvas, Size size) {
    // El dibujo ocupa y = 2.5…35.5 del viewBox de 48: se centra en vertical.
    final s = size.shortestSide / 40;
    canvas.translate((size.width - 48 * s) / 2, (size.height - 48 * s) / 2 - 4.5 * s);
    canvas.scale(s);
    final p = Paint()..isAntiAlias = true;

    // Sol y rayos.
    canvas.drawCircle(const Offset(24, 7.5), 3.2, p..color = PaxTokens.brandYellow400);
    p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(24, 2.5), const Offset(24, 3.8), p);
    canvas.drawLine(const Offset(20, 4.2), const Offset(20.9, 5.3), p);
    canvas.drawLine(const Offset(28, 4.2), const Offset(27.1, 5.3), p);
    p.style = PaintingStyle.fill;

    // Hoja (izquierda) y corazón (derecha), con su degradado.
    final leaf = Path()
      ..moveTo(24, 14)
      ..cubicTo(19, 8.5, 12, 10.5, 12, 17.5)
      ..cubicTo(12, 24.5, 24, 30.5, 24, 30.5)
      ..cubicTo(24, 30.5, 18, 25.5, 17, 20.5)
      ..cubicTo(16, 16.5, 20, 14.5, 24, 17.5)
      ..close();
    final heart = Path()
      ..moveTo(24, 14)
      ..cubicTo(29, 8.5, 36, 10.5, 36, 17.5)
      ..cubicTo(36, 24.5, 24, 30.5, 24, 30.5)
      ..cubicTo(24, 30.5, 30, 25.5, 31, 20.5)
      ..cubicTo(32, 16.5, 28, 14.5, 24, 17.5)
      ..close();
    void gradient(Path path, Color a, Color b) {
      final r = path.getBounds();
      canvas.drawPath(
        path,
        Paint()
          ..isAntiAlias = true
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [a, b],
          ).createShader(r),
      );
    }

    gradient(leaf, _mx(PaxTokens.brandGreen500, 0.85, PaxTokens.white), PaxTokens.brandGreen900);
    gradient(heart, PaxTokens.brandBlue500, PaxTokens.brandBlue800);

    // La caja.
    canvas.drawPath(
      Path()..addPolygon(const [Offset(24, 19), Offset(28.5, 21.5), Offset(24, 24), Offset(19.5, 21.5)], true),
      p..color = _mx(PaxTokens.brandYellow400, 0.6, PaxTokens.white),
    );
    canvas.drawPath(
      Path()..addPolygon(const [Offset(19.5, 21.5), Offset(24, 24), Offset(24, 29), Offset(19.5, 26.5)], true),
      p..color = _mx(PaxTokens.brandYellow900, 0.35, PaxTokens.brandYellow400),
    );
    canvas.drawPath(
      Path()..addPolygon(const [Offset(28.5, 21.5), Offset(24, 24), Offset(24, 29), Offset(28.5, 26.5)], true),
      p..color = PaxTokens.brandYellow400,
    );

    // La mano que sostiene (en oscuro, su inverso para que se vea sobre el fondo).
    canvas.drawPath(
      Path()
        ..moveTo(12, 25.5)
        ..cubicTo(14.5, 23.5, 18, 28.5, 24, 32)
        ..cubicTo(30, 30, 35.5, 25, 36.5, 21.5)
        ..cubicTo(35.5, 26.5, 31, 34.5, 24, 35.5)
        ..cubicTo(17, 35.5, 12, 30.5, 12, 25.5)
        ..close(),
      p..color = dark ? PaxDarkTokens.green : PaxTokens.brandGreen900,
    );
  }

  @override
  bool shouldRepaint(_LogoPainter old) => old.dark != dark;
}
