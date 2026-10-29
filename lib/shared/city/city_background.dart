import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../motion/pax_motion.dart';
import 'city_painter.dart';
import 'city_scene.dart';

/// La ciudad isométrica de la web detrás de Inicio. Decorativa: fuera de la lectura de pantalla y sin texto de la app
/// encima.
///
/// Se mueve solo cuando se ve: se queda en un fotograma fijo si la persona la pausa ([paused]), si pidió «reducir
/// movimiento», si quedó tapada ([visible] en `false`, p. ej. al desplazar Inicio) o si la pantalla no está delante
/// (`TickerMode`). Va a 30 fotogramas por segundo: es un fondo lento, y así el desplazamiento, los gestos y las
/// transiciones de encima tienen todo el margen del teléfono.
class CityBackground extends StatefulWidget {
  const CityBackground({super.key, required this.paused, this.visible});

  final ValueListenable<bool> paused;
  final ValueListenable<bool>? visible;

  @override
  State<CityBackground> createState() => _CityBackgroundState();
}

class _CityBackgroundState extends State<CityBackground> with SingleTickerProviderStateMixin {
  final _world = CityWorld(district: District.home);
  late final Ticker _ticker = createTicker(_onTick);
  late final CityPainter _painter = CityPainter(_world);
  Duration _last = Duration.zero;
  double _sinceFrame = 0;
  double _targetNight = 0;

  static const _frame = 1 / 30;

  @override
  void initState() {
    super.initState();
    widget.paused.addListener(_sync);
    widget.visible?.addListener(_sync);
  }

  @override
  void didUpdateWidget(CityBackground old) {
    super.didUpdateWidget(old);
    if (old.paused != widget.paused) {
      old.paused.removeListener(_sync);
      widget.paused.addListener(_sync);
    }
    if (old.visible != widget.visible) {
      old.visible?.removeListener(_sync);
      widget.visible?.addListener(_sync);
    }
    _sync();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _targetNight = Theme.of(context).brightness == Brightness.dark ? 1 : 0;
    _sync();
  }

  bool get _animate =>
      PaxMotion.ambient && !PaxMotion.reduce(context) && !widget.paused.value && (widget.visible?.value ?? true);

  void _sync() {
    if (!mounted) return;
    if (_animate) {
      if (!_ticker.isActive) {
        _last = Duration.zero;
        _ticker.start();
      }
    } else {
      if (_ticker.isActive) _ticker.stop();
      _world.still(_targetNight);
    }
  }

  void _onTick(Duration elapsed) {
    final dt = _last == Duration.zero ? 0.0 : (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    _sinceFrame += dt;
    if (_sinceFrame < _frame) return;
    _world.tick(_sinceFrame.clamp(0, 0.1), _targetNight);
    _sinceFrame = 0;
  }

  @override
  void dispose() {
    widget.paused.removeListener(_sync);
    widget.visible?.removeListener(_sync);
    _ticker.dispose();
    _world.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: RepaintBoundary(
      child: CustomPaint(key: const Key('city'), painter: _painter, size: Size.infinite, isComplex: true),
    ),
  );
}
