import 'package:flutter/material.dart';

/// Una barra: etiqueta, valor real devuelto por el backend (para la proporción) y su texto ya formateado.
class AmountBar {
  const AmountBar(this.label, this.value, this.display);
  final String label;
  final num value;
  final String display;
}

/// Barras horizontales proporcionales al mayor valor, dibujadas con `CustomPainter` (sin librerías). Solo pinta lo
/// que recibe: sin valores, no dibuja nada.
class AmountBars extends StatelessWidget {
  const AmountBars({super.key, required this.bars});

  final List<AmountBar> bars;

  @override
  Widget build(BuildContext context) {
    if (bars.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final max = bars.map((b) => b.value).fold<num>(0, (a, b) => b > a ? b : a);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final b in bars)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${b.label}: ${b.display}'),
                const SizedBox(height: 2),
                SizedBox(
                  height: 10,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _BarPainter(
                      fraction: max <= 0 ? 0 : (b.value / max).clamp(0, 1).toDouble(),
                      color: scheme.primary,
                      track: scheme.surfaceContainerHighest,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter({required this.fraction, required this.color, required this.track});
  final double fraction;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Radius.circular(size.height / 2);
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, r), Paint()..color = track);
    if (fraction > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width * fraction, size.height), r),
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) => old.fraction != fraction || old.color != color || old.track != track;
}
