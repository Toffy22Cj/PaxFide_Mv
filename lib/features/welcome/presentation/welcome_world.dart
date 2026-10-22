import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../shared/theme/pax_tokens.dart';

/// El mundo del landing web, llevado a Flutter: **un solo mapa isométrico** fijo detrás del contenido. Al deslizar, la
/// cámara recorre la carretera parada por parada (pago → bodega → ruta → sellado → entrega) y al final se aleja para
/// ver todo el recorrido; el día pasa a atardecer, noche y vuelve a amanecer; las escenas se animan al llegar (cajas que
/// caen en los estantes, el lote que se divide, los cubos que suben hasta la raíz, la caja que llega a la comunidad) y
/// el mundo sigue vivo: nubes que avanzan, pasto que se mece, monedas, luciérnagas y el camión que patrulla.
///
/// Port directo del `<canvas id="world">` del landing (`paxfide-landing.html`), con los **colores solo de la paleta**
/// (tokens con o sin transparencia) y sin datos de ejemplo en las etiquetas (sin lugares ni cantidades inventadas).
abstract final class WelcomeWorld {
  /// Movimiento continuo (nubes, pasto, camión…). Las pruebas lo apagan para que `pumpAndSettle` termine; con
  /// `MediaQuery.disableAnimations` tampoco hay movimiento (como `prefers-reduced-motion` en la web).
  static bool ambientMotion = true;

  /// Noche automática según la parada (landing: `getAutoNight`).
  static double autoNight(double u) {
    if (u <= 1) return _lerp(0, 0.12, u);
    if (u <= 2) return _lerp(0.12, 0.65, u - 1);
    if (u <= 3) return _lerp(0.65, 1.0, u - 2);
    if (u <= 4) return _lerp(1.0, 0.15, u - 3);
    return _lerp(0.15, 0, _cl(u - 4));
  }

  /// Suavizado del landing (`ss`).
  static double smooth(double a, double b, double x) => _ss(a, b, x);
}

/// Estado de un cuadro: posición de la cámara en el recorrido (0…5), reloj del mundo y cuánto es de noche (0…1).
class WorldClock extends ChangeNotifier {
  double camS = 0;
  double t = 0;
  double night = 0;

  void set({required double camS, required double t, required double night}) {
    if (camS == this.camS && t == this.t && night == this.night) return;
    this.camS = camS;
    this.t = t;
    this.night = night;
    notifyListeners();
  }
}

/// El lienzo del mundo, a pantalla completa.
class WelcomeWorldView extends StatelessWidget {
  const WelcomeWorldView({super.key, required this.clock});
  final WorldClock clock;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: RepaintBoundary(
      child: CustomPaint(painter: WorldPainter(clock), size: Size.infinite),
    ),
  );
}

// --- utilidades del landing ---------------------------------------------------------------------------------------

double _cl(double x) => x < 0 ? 0 : (x > 1 ? 1 : x);
double _lerp(double a, double b, double p) => a + (b - a) * p;
double _out(double x) => 1 - math.pow(1 - x, 3).toDouble();
double _inOut(double x) => x < 0.5 ? 4 * x * x * x : 1 - math.pow(-2 * x + 2, 3).toDouble() / 2;
double _back(double x) {
  const c = 1.70158;
  return 1 + (c + 1) * math.pow(x - 1, 3) + c * math.pow(x - 1, 2);
}

double _ss(double a, double b, double x) {
  final t = _cl((x - a) / (b - a));
  return t * t * (3 - 2 * t);
}

Color _mx(Color top, double a, Color base) => Color.alphaBlend(top.withValues(alpha: a), base);
Color _a(Color c, double a) => c.withValues(alpha: c.a * _cl(a));

// --- datos del mundo (mismos que el landing, misma semilla) -------------------------------------------------------

typedef _V = (double, double);

const List<_V> _stops = [(0, 0), (9, -3), (18, 1), (27, -3), (36, 1)];
const List<_V> _ctrl = [(-12, 4), (-6, 2), (0, 0), (9, -3), (18, 1), (27, -3), (36, 1), (42, -1), (48, -2)];

_V _cr(_V p0, _V p1, _V p2, _V p3, double t) {
  final t2 = t * t, t3 = t2 * t;
  double k(double a, double b, double c, double d) =>
      0.5 * (2 * b + (-a + c) * t + (2 * a - 5 * b + 4 * c - d) * t2 + (-a + 3 * b - 3 * c + d) * t3);
  return (k(p0.$1, p1.$1, p2.$1, p3.$1), k(p0.$2, p1.$2, p2.$2, p3.$2));
}

/// Punto de la carretera en la posición `u` del recorrido (0 = pago, 4 = entrega).
_V _road(double u) {
  final v = u + 2;
  var j = v.floor();
  if (j < 1) j = 1;
  if (j > 6) j = 6;
  return _cr(_ctrl[j - 1], _ctrl[j], _ctrl[j + 1], _ctrl[j + 2], v - j);
}

class _Cloud {
  _Cloud(this.bx, this.by, this.z, this.s, this.spd, this.phase, this.puffs);
  final double bx, by, z, s, spd, phase;
  final List<(double, double, double)> puffs;
}

class _Data {
  _Data._() {
    for (var u = -1.8; u <= 5.8; u += 0.04) {
      roadPts.add(_road(u));
    }
    const sr = <_V>[(17, -1), (18, 1), (19.2, 3.4), (20.6, 6.6), (21.6, 9.6), (22.4, 12)];
    for (var j = 1; j < sr.length - 2; j++) {
      for (var t = 0.0; t < 1; t += 0.05) {
        sidePts.add(_cr(sr[j - 1], sr[j], sr[j + 1], sr[j + 2], t));
      }
    }
    for (var t = -3.2; t <= 6.8; t += 0.06) {
      riverPts.add((-32 + t * 14.5, -22 + math.sin(t * 1.35) * 4.6 + math.cos(t * 0.8) * 3.0));
    }
    for (var i = 0; i < 54; i++) {
      meadows.add((
        x: -38 + rnd() * 110,
        y: -28 + rnd() * 66,
        w: 2.6 + rnd() * 4.8,
        h: 1.6 + rnd() * 3.2,
        rot: rnd() * 3.14,
        day: (rnd() * 4).floor(),
        night: (rnd() * 3).floor(),
      ));
    }
    for (var i = 0; i < 680 && trees.length < 230; i++) {
      final x = -38 + rnd() * 110, y = -28 + rnd() * 66;
      if (!_near(x, y, 1.8) && !_nearRiver(x, y, 2.4) && !_nearFinca(x, y, 2.0)) {
        final type = (rnd() * 6).floor();
        trees.add((x, y, 0.36 + rnd() * 0.42, type));
      }
    }
    for (var i = 0; i < 480 && bushes.length < 150; i++) {
      final x = -38 + rnd() * 110, y = -28 + rnd() * 66;
      if (!_near(x, y, 1.3) && !_nearRiver(x, y, 1.8) && !_nearFinca(x, y, 1.5)) {
        bushes.add((x, y, 0.28 + rnd() * 0.3, (rnd() * 4).floor()));
      }
    }
    for (var i = 0; i < 1600 && grass.length < 720; i++) {
      final x = -38 + rnd() * 110, y = -28 + rnd() * 66;
      if (!_nearRoad(x, y, 0.85) && !_nearRiver(x, y, 1.6)) {
        grass.add((x: x, y: y, s: 0.65 + rnd() * 0.65, type: (rnd() * 3).floor(), col: (rnd() * 5).floor()));
      }
    }
    for (var i = 0; i < 44; i++) {
      final type = i % 3;
      final double z, s, spd;
      final List<(double, double, double)> puffs;
      if (type == 0) {
        z = 5.4 + rnd() * 2.6;
        s = 1.7 + rnd() * 0.75;
        spd = 0.22 + rnd() * 0.18;
        puffs = const [
          (0, 0, 1.15),
          (-0.95, 0.12, 0.9),
          (0.95, 0.1, 0.92),
          (1.75, 0.22, 0.72),
          (-1.7, 0.2, 0.7),
          (-0.45, -0.45, 0.85),
          (0.5, -0.42, 0.82),
          (0, -0.65, 0.72),
        ];
      } else if (type == 1) {
        z = 4.6 + rnd() * 2.4;
        s = 1.25 + rnd() * 0.45;
        spd = 0.28 + rnd() * 0.24;
        puffs = const [
          (0, 0, 1.05),
          (-0.82, 0.14, 0.8),
          (0.82, 0.12, 0.82),
          (1.45, 0.2, 0.65),
          (-1.4, 0.18, 0.62),
          (-0.22, -0.42, 0.75),
          (0.42, -0.38, 0.7),
        ];
      } else {
        z = 7.5 + rnd() * 3.8;
        s = 0.85 + rnd() * 0.35;
        spd = 0.16 + rnd() * 0.16;
        puffs = const [(0, 0, 0.95), (-0.7, 0.1, 0.75), (0.7, 0.08, 0.78), (1.3, 0.15, 0.6), (-0.3, -0.3, 0.68)];
      }
      clouds.add(_Cloud(-45 + rnd() * 125, -28 + rnd() * 62, z, s, spd, rnd() * 6.28, puffs));
    }
    for (var i = 0; i < 75; i++) {
      stars.add((x: rnd(), y: rnd(), r: 0.7 + rnd() * 1.5, phase: rnd() * 6.28, gold: rnd() <= 0.2));
    }
    for (var i = 0; i < 26; i++) {
      fireflies.add((23 + rnd() * 10, -4 + rnd() * 7, rnd() * 6.28));
    }
  }

  static final _Data instance = _Data._();

  int _seed = 17;
  double rnd() {
    _seed = (_seed * 16807) % 2147483647;
    return _seed / 2147483647;
  }

  final roadPts = <_V>[];
  final sidePts = <_V>[];
  final riverPts = <_V>[];
  final meadows = <({double x, double y, double w, double h, double rot, int day, int night})>[];
  static const crops = <({double x, double y, double w, double d, int c})>[
    (x: -16, y: 7, w: 4.8, d: 3.2, c: 0),
    (x: 6, y: 13, w: 5.2, d: 3.5, c: 1),
    (x: 34, y: -19, w: 6.0, d: 3.8, c: 0),
    (x: -24, y: -14, w: 5.5, d: 3.4, c: 1),
  ];
  static const fincas = <_V>[(-18, 5.5), (12, 15), (38, -8), (-8, -15.5)];
  final trees = <(double, double, double, int)>[];
  final bushes = <(double, double, double, int)>[];
  final grass = <({double x, double y, double s, int type, int col})>[];
  final clouds = <_Cloud>[];
  final stars = <({double x, double y, double r, double phase, bool gold})>[];
  final fireflies = <(double, double, double)>[];

  static double _d(_V p, double x, double y) => math.sqrt((p.$1 - x) * (p.$1 - x) + (p.$2 - y) * (p.$2 - y));

  bool _nearRiver(double x, double y, double rad) => riverPts.any((p) => _d(p, x, y) < rad);
  bool _nearFinca(double x, double y, double rad) => fincas.any((f) => _d(f, x, y) < rad);
  bool _near(double x, double y, double rad) =>
      roadPts.any((p) => _d(p, x, y) < rad) ||
      sidePts.any((p) => _d(p, x, y) < rad * 0.85) ||
      _stops.any((s) => _d((s.$1 - 0.6, s.$2 - 2.6), x, y) < 3.4);
  bool _nearRoad(double x, double y, double rad) =>
      roadPts.any((p) => _d(p, x, y) < rad) || sidePts.any((p) => _d(p, x, y) < rad);
}

// --- colores (solo paleta) ----------------------------------------------------------------------------------------

const _w = PaxTokens.white;
const _g9 = PaxTokens.brandGreen900;
const _g8 = PaxTokens.brandGreen800;
const _g5 = PaxTokens.brandGreen500;
const _g50 = PaxTokens.brandGreen50;
const _b8 = PaxTokens.brandBlue800;
const _b7 = PaxTokens.brandBlue700;
const _b5 = PaxTokens.brandBlue500;
const _b50 = PaxTokens.brandBlue50;
const _y9 = PaxTokens.brandYellow900;
const _y4 = PaxTokens.brandYellow400;
const _y50 = PaxTokens.brandYellow50;
const _n7 = PaxTokens.brandNeutral700;
const _r7 = PaxTokens.danger700;
const _nb = PaxDarkTokens.background;

/// Colores del mundo para un grado de noche `n` (0 = día, 1 = noche): cada uno pasa de su tono de día al de noche.
class _Tint {
  _Tint(double n)
    : ground = Color.lerp(_mx(_g5, 0.72, _w), _mx(_g9, 0.5, _nb), n)!,
      riverBank = Color.lerp(_mx(_y4, 0.18, _mx(_g5, 0.45, _w)), _mx(_g9, 0.45, _nb), n)!,
      riverWater = Color.lerp(_mx(_b5, 0.85, _w), _mx(_b8, 0.55, _nb), n)!,
      riverDeep = Color.lerp(_b7, _mx(_b8, 0.42, _nb), n)!,
      roadBase = Color.lerp(_mx(_n7, 0.24, _mx(_g5, 0.2, _w)), _mx(_g9, 0.42, _nb), n)!,
      roadSurface = Color.lerp(_mx(_n7, 0.14, _mx(_g5, 0.15, _w)), _mx(_g8, 0.55, _nb), n)!,
      dash = Color.lerp(_y4, _mx(_y4, 0.7, _w), n)!,
      grass = Color.lerp(_mx(_g5, 0.9, _g8), _mx(_g8, 0.6, _nb), n)!,
      stem = Color.lerp(_mx(_g8, 0.5, _g5), _mx(_g8, 0.6, _nb), n)!,
      trunk = Color.lerp(_y9, _mx(_y9, 0.45, _nb), n)!,
      bloom = Color.lerp(_y4, _mx(_y4, 0.6, _nb), n)!,
      bloomShade = Color.lerp(_mx(_y9, 0.45, _y4), _mx(_y9, 0.7, _nb), n)!,
      palm = Color.lerp(_mx(_g8, 0.6, _g5), _mx(_g9, 0.55, _nb), n)!,
      fincaWall = [
        Color.lerp(_w, _mx(_n7, 0.18, _w), n)!,
        Color.lerp(_mx(_n7, 0.1, _w), _mx(_n7, 0.42, _w), n)!,
        Color.lerp(_mx(_n7, 0.05, _w), _mx(_n7, 0.3, _w), n)!,
      ],
      fincaRoof = Color.lerp(_mx(_r7, 0.75, _y4), _mx(_r7, 0.6, _nb), n)!,
      fincaRoofSide = Color.lerp(_r7, _mx(_r7, 0.45, _nb), n)!,
      fincaWindow = Color.lerp(_mx(_b5, 0.55, _w), _y50, _cl((n - 0.2) * 3))!,
      houseWindow = Color.lerp(_b50, _y50, _cl((n - 0.2) * 3))!,
      warehouseFloor = Color.lerp(_mx(_n7, 0.1, _w), _mx(_g9, 0.55, _nb), n)!,
      chain = Color.lerp(_b7, _b5, n)!,
      chainCube = n > 0.5 ? [_mx(_b5, 0.5, _w), _b8, _b5] : [_mx(_b5, 0.55, _w), _b8, _b7],
      guide = Color.lerp(_a(_g9, 0.35), _a(_b5, 0.45), n)!,
      anchor = Color.lerp(_g9, _mx(_b5, 0.6, _w), n)!,
      labelBg = Color.lerp(_a(_w, 0.95), _a(_mx(_g9, 0.9, _nb), 0.94), n)!,
      labelBorder = Color.lerp(_a(_g9, 0.22), _a(_g5, 0.35), n)!,
      labelFg = Color.lerp(_g9, _g50, n)!,
      doneBg = Color.lerp(_g9, _mx(_g9, 0.8, _g5), n)!,
      badgeBg = Color.lerp(_y50, _a(_y4, 0.22), n)!,
      badgeFg = Color.lerp(_y9, _mx(_y4, 0.6, _w), n)!,
      cloudBase = Color.lerp(_mx(_g5, 0.3, _w), _mx(_b8, 0.45, _nb), n)!,
      cloudBody = Color.lerp(_mx(_g50, 0.6, _w), _mx(_b8, 0.7, _nb), n)!,
      cloudHi = Color.lerp(_w, _mx(_b5, 0.75, _w), n)!,
      shadowA = n > 0.5 ? 0.22 : 0.1,
      meadowDay = [_mx(_g5, 0.8, _w), _mx(_g5, 0.64, _w), _mx(_g5, 0.9, _w), _mx(_g5, 0.56, _w)],
      meadowNight = [_mx(_g9, 0.38, _nb), _mx(_g9, 0.55, _nb), _mx(_g9, 0.28, _nb)],
      cropDay = [_mx(_g5, 0.86, _w), _mx(_g5, 0.92, _w)],
      cropRowDay = [_mx(_g8, 0.55, _g5), _mx(_g8, 0.45, _g5)],
      night = n;

  final double night;
  final Color ground, riverBank, riverWater, riverDeep, roadBase, roadSurface, dash, grass, stem, trunk, bloom;
  final Color bloomShade, palm, fincaRoof, fincaRoofSide, fincaWindow, houseWindow, warehouseFloor, chain, guide;
  final Color anchor, labelBg, labelBorder, labelFg, doneBg, badgeBg, badgeFg, cloudBase, cloudBody, cloudHi;
  final List<Color> fincaWall, chainCube, meadowDay, meadowNight, cropDay, cropRowDay;
  final double shadowA;

  Color meadow(int day, int nightIdx) => Color.lerp(meadowDay[day], meadowNight[nightIdx], night)!;
  Color tree(int c) => Color.lerp(
    [_g5, _mx(_g8, 0.6, _g5), _g8, _mx(_g5, 0.75, _w)][c],
    [_mx(_g9, 0.6, _nb), _mx(_g9, 0.48, _nb), _mx(_g8, 0.6, _nb), _mx(_g9, 0.55, _nb)][c],
    night,
  )!;
  Color bush(int c) => Color.lerp(
    [_g5, _mx(_g8, 0.7, _g5), _mx(_g5, 0.8, _w), _b7][c],
    [_mx(_g8, 0.45, _nb), _mx(_g9, 0.55, _nb), _mx(_g8, 0.6, _nb), _mx(_b8, 0.45, _nb)][c],
    night,
  )!;
  Color crop(int c) => Color.lerp(cropDay[c], _mx(_g9, 0.35, _nb), night)!;
  Color cropRow(int c) => Color.lerp(cropRowDay[c], _mx(_g9, 0.6, _nb), night)!;

  static final flowers = [_w, _y4, _mx(_y4, 0.6, _w), _mx(_b5, 0.55, _w), _mx(_r7, 0.5, _w)];
  static final box = [_mx(_y4, 0.6, _w), _mx(_y9, 0.35, _y4), _y4];
  static final crateBand = _a(_mx(_y9, 0.5, _y4), 0.8);
  static final blue = [_mx(_b5, 0.55, _w), _b8, _b7];
  static final gold = [_mx(_y4, 0.45, _w), _mx(_y9, 0.4, _y4), _y4];
  static final stone = [_mx(_n7, 0.04, _w), _mx(_n7, 0.16, _w), _mx(_n7, 0.1, _w)];
  static final terminal = [_mx(_n7, 0.6, _nb), _mx(_n7, 0.15, _nb), _mx(_n7, 0.35, _nb)];
  static final fund = [_mx(_g5, 0.8, _w), _g9, _g8];
  static final shelf = [_mx(_y9, 0.35, _mx(_y4, 0.5, _w)), _mx(_y9, 0.6, _y4), _mx(_y9, 0.45, _y4)];
  static final chassis = [_mx(_n7, 0.08, _w), _mx(_n7, 0.28, _w), _mx(_n7, 0.18, _w)];
  static final cab = [_g5, _g9, _g8];
  static final moto = [_b7, _b8, _mx(_b8, 0.5, _b7)];
  static final house = [_w, _mx(_n7, 0.06, _w), _mx(_n7, 0.12, _w)];
  static final people = [_b7, _y4, _g5, _g9, _b8];
  static final skin = _mx(_y9, 0.6, _y4);
  static final wheel = _mx(_n7, 0.5, _nb);
  static final coinDark = _mx(_y9, 0.4, _y4);
  static final windshield = _mx(_b5, 0.25, _w);
}

// --- pintor -------------------------------------------------------------------------------------------------------

/// Pinta un cuadro del mundo. Repinta cuando cambia el [WorldClock].
class WorldPainter extends CustomPainter {
  WorldPainter(this.clock) : super(repaint: clock);
  final WorldClock clock;

  static const double _tw = 34, _th = 17, _hz = 36;
  final _data = _Data.instance;
  final _p = Paint()..isAntiAlias = true;
  final _labels = <String, TextPainter>{};

  late Canvas _c;
  late Size _size;
  late _Tint _col;
  double _camX = 0, _camY = -1, _k = 1, _ox = 0, _oy = 0, _t = 0, _camS = 0;
  Size? _ovFor;
  double _ovK = 0.3, _ovX = 17, _ovY = -1;

  Offset _pt(double x, double y, [double z = 0]) =>
      Offset(_ox + (x - _camX - (y - _camY)) * _tw * _k, _oy + (x - _camX + (y - _camY)) * _th * _k - z * _hz * _k);

  bool get _mobile => _size.width <= 900;

  void _overview() {
    if (_ovFor == _size) return;
    _ovFor = _size;
    var a0 = 1e9, a1 = -1e9, b0 = 1e9, b1 = -1e9;
    for (var u = -0.4; u <= 4.4; u += 0.1) {
      final (x, y) = _road(u);
      final a = (x - y) * _tw, b = (x + y) * _th;
      a0 = math.min(a0, a);
      a1 = math.max(a1, a);
      b0 = math.min(b0, b - 110);
      b1 = math.max(b1, b + 30);
    }
    _ovK = math.min(0.88 * _size.width / (a1 - a0), 0.62 * _size.height / (b1 - b0));
    final aa = (a0 + a1) / 2 / _tw, bb = (b0 + b1) / 2 / _th;
    _ovX = (aa + bb) / 2;
    _ovY = (bb - aa) / 2;
  }

  void _camera() {
    final w = _size.width, h = _size.height;
    final k0 = _mobile ? (w / 540).clamp(0.5, 0.72) : (w / 1350).clamp(0.78, 1.25);
    final fx = _mobile ? w * 0.5 : w * 0.64, fy = _mobile ? h * 0.36 : h * 0.56;
    if (_camS <= 4) {
      final (rx, ry) = _road(_camS);
      final rest = 1 - math.min(1, (_camS - _camS.roundToDouble()).abs() * 2);
      _camX = rx;
      _camY = ry - 1.1;
      _k = k0 * _lerp(1.1, 1.5, _inOut(rest.toDouble()));
      _ox = fx;
      _oy = fy;
    } else {
      final p = _inOut(_cl(_camS - 4));
      final (rx, ry) = _road(4);
      _camX = _lerp(rx, _ovX, p);
      _camY = _lerp(ry - 1.1, _ovY, p);
      _k = _lerp(k0 * 1.5, _ovK, p);
      _ox = _lerp(fx, w * 0.5, p);
      _oy = _lerp(fy, h * 0.52, p);
      if (_camS >= 4.4) {
        _camX += math.sin(_t * 0.22) * 1.5;
        _camY += math.cos(_t * 0.18) * 0.9;
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    _c = canvas;
    _size = size;
    _t = clock.t;
    _camS = clock.camS;
    _col = _Tint(clock.night);
    _overview();
    _camera();
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    _draw();
    canvas.restore();
  }

  @override
  bool shouldRepaint(WorldPainter old) => old.clock != clock;

  // --- primitivas ---

  void _fill(Color c) {
    _p
      ..style = PaintingStyle.fill
      ..color = c
      ..shader = null;
  }

  void _stroke(Color c, double width, {StrokeCap cap = StrokeCap.butt}) {
    _p
      ..style = PaintingStyle.stroke
      ..color = c
      ..strokeWidth = width
      ..strokeCap = cap
      ..strokeJoin = StrokeJoin.round
      ..shader = null;
  }

  void _poly(List<Offset> pts, Color c, [double al = 1]) {
    _fill(_a(c, al));
    _c.drawPath(Path()..addPolygon(pts, true), _p);
  }

  void _box(double x, double y, double z, double w, double d, double h, List<Color> c, [double al = 1]) {
    final a = _pt(x, y, z + h), b = _pt(x + w, y, z + h), cc = _pt(x + w, y + d, z + h), dd = _pt(x, y + d, z + h);
    final b0 = _pt(x + w, y, z), c0 = _pt(x + w, y + d, z), d0 = _pt(x, y + d, z);
    _poly([dd, cc, c0, d0], c[1], al);
    _poly([b, cc, c0, b0], c[2], al);
    _poly([a, b, cc, dd], c[0], al);
  }

  void _shadow(double x, double y, double r, [double a = 0.1]) {
    final p = _pt(x, y);
    _fill(_a(_g9, a));
    _c.drawOval(Rect.fromCenter(center: p, width: 2 * r * _tw * _k, height: 2 * r * _th * _k), _p);
  }

  void _strip(List<_V> pts, double hw, Color fill) {
    final l = <Offset>[], r = <Offset>[];
    for (var i = 0; i < pts.length; i++) {
      final a = pts[math.max(0, i - 1)], b = pts[math.min(pts.length - 1, i + 1)];
      var dx = b.$1 - a.$1, dy = b.$2 - a.$2;
      final len = math.sqrt(dx * dx + dy * dy);
      final n = len == 0 ? 1.0 : len;
      dx /= n;
      dy /= n;
      l.add(_pt(pts[i].$1 - dy * hw, pts[i].$2 + dx * hw));
      r.add(_pt(pts[i].$1 + dy * hw, pts[i].$2 - dx * hw));
    }
    _poly([...l, ...r.reversed], fill);
  }

  void _dashes(List<_V> pts, Color fill) {
    for (var i = 0; i + 3 < pts.length; i += 6) {
      final a = pts[i], b = pts[i + 3];
      final dx = b.$1 - a.$1, dy = b.$2 - a.$2;
      final len = math.sqrt(dx * dx + dy * dy);
      final l = len == 0 ? 1.0 : len;
      final nx = -dy / l * 0.06, ny = dx / l * 0.06;
      _poly([
        _pt(a.$1 + nx, a.$2 + ny),
        _pt(b.$1 + nx, b.$2 + ny),
        _pt(b.$1 - nx, b.$2 - ny),
        _pt(a.$1 - nx, a.$2 - ny),
      ], fill);
    }
  }

  void _face(
    double x,
    double y,
    double z,
    double w,
    double d,
    double h,
    double u0,
    double u1,
    double v0,
    double v1,
    Color f,
  ) {
    final xx = x + w;
    _poly([
      _pt(xx, y + d * u0, z + h * v1),
      _pt(xx, y + d * u1, z + h * v1),
      _pt(xx, y + d * u1, z + h * v0),
      _pt(xx, y + d * u0, z + h * v0),
    ], f);
  }

  void _faceL(
    double x,
    double y,
    double z,
    double w,
    double d,
    double h,
    double u0,
    double u1,
    double v0,
    double v1,
    Color f,
  ) {
    final yy = y + d;
    _poly([
      _pt(x + w * u0, yy, z + h * v1),
      _pt(x + w * u1, yy, z + h * v1),
      _pt(x + w * u1, yy, z + h * v0),
      _pt(x + w * u0, yy, z + h * v0),
    ], f);
  }

  void _heart(Offset at, double s, Color fill, [double al = 1]) {
    final k = s / 24;
    Offset q(double x, double y) => at + Offset(x * k, y * k);
    final path = Path()
      ..moveTo(q(0, 8).dx, q(0, 8).dy)
      ..cubicTo(q(-12, 0).dx, q(-12, 0).dy, q(-11, -10).dx, q(-11, -10).dy, q(-4, -9).dx, q(-4, -9).dy)
      ..cubicTo(q(-1.5, -8.6).dx, q(-1.5, -8.6).dy, q(0, -6).dx, q(0, -6).dy, q(0, -5).dx, q(0, -5).dy)
      ..cubicTo(q(0, -6).dx, q(0, -6).dy, q(1.5, -8.6).dx, q(1.5, -8.6).dy, q(4, -9).dx, q(4, -9).dy)
      ..cubicTo(q(11, -10).dx, q(11, -10).dy, q(12, 0).dx, q(12, 0).dy, q(0, 8).dx, q(0, 8).dy);
    _fill(_a(fill, al));
    _c.drawPath(path, _p);
  }

  void _crate(double x, double y, double z, double s, bool qr, bool heart, [double al = 1]) {
    _box(x, y, z, s, s, s * 0.82, _Tint.box, al);
    if (al < 0.5) return;
    final a = _pt(x + s * 0.15, y + s * 0.5, z + s * 0.82), b = _pt(x + s * 0.85, y + s * 0.5, z + s * 0.82);
    _stroke(_Tint.crateBand, math.max(1, s * _tw * _k * 0.08));
    _c.drawLine(a, b, _p);
    if (qr) {
      final h = s * 0.82;
      _face(x, y, z, s, s, h, 0.25, 0.72, 0.25, 0.75, _w);
      _face(x, y, z, s, s, h, 0.32, 0.46, 0.5, 0.68, _g9);
      _face(x, y, z, s, s, h, 0.52, 0.66, 0.5, 0.68, _g9);
      _face(x, y, z, s, s, h, 0.32, 0.46, 0.3, 0.44, _g9);
    }
    if (heart) _heart(_pt(x + s * 0.5, y + s, z + s * 0.4), s * _tw * _k * 0.5, _g9);
  }

  void _coin(Offset p, double r, double spin, [double al = 1]) {
    final w = math.max(1.0, r * spin.abs());
    _fill(_a(_Tint.coinDark, al));
    _c.drawOval(Rect.fromCenter(center: p + Offset(r * 0.08, 0), width: 2 * w, height: 2 * r), _p);
    _fill(_a(_y4, al));
    _c.drawOval(Rect.fromCenter(center: p, width: 2 * math.max(0.6, r * spin.abs() * 0.92), height: 2 * r * 0.92), _p);
  }

  void _cube(double cx, double cy, double z, double s, List<Color> c, [double al = 1]) =>
      _box(cx - s / 2, cy - s / 2, z, s, s, s, c, al);

  TextPainter _text(String text, double fs, Color color) {
    final key = '$text|$fs|${color.toARGB32()}';
    final cached = _labels[key];
    if (cached != null) return cached;
    if (_labels.length > 80) _labels.clear();
    return _labels[key] = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontFamily: 'monospace', fontSize: fs, fontWeight: FontWeight.w600, color: color),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  /// Etiqueta en píldora con línea guía discontinua al objeto (landing: `drawMapLabel`).
  void _label(
    double ax,
    double ay,
    double az,
    double lx,
    double ly,
    double lz,
    String text, {
    String variant = '',
    double al = 1,
  }) {
    if (al <= 0.01) return;
    final l = _pt(lx, ly, lz), anchor = _pt(ax, ay, az);
    final fs = (9.8 * _k).clamp(10.5, 13.5).roundToDouble();
    final (bg, border, fg) = switch (variant) {
      'done' => (_col.doneBg, _g5, _y4),
      'badge' => (_col.badgeBg, _y4, _col.badgeFg),
      _ => (_col.labelBg, _col.labelBorder, _col.labelFg),
    };
    final tp = _text(text, fs, fg);
    final w = tp.width + fs * 1.05 * 2, h = fs * 1.95;
    final dist = (l - anchor).distance;
    if (dist > 8) {
      _stroke(_a(_col.guide, al), math.max(1.2, 1.5 * _k));
      final end = l + Offset(0, h * 0.42);
      final total = (end - anchor).distance, on = 3 * _k, off = 2.5 * _k;
      final dir = (end - anchor) / total;
      for (var s = 0.0; s < total; s += on + off) {
        _c.drawLine(anchor + dir * s, anchor + dir * math.min(total, s + on), _p);
      }
      _fill(_a(_col.anchor, al));
      _c.drawCircle(anchor, math.max(2, 2.8 * _k), _p);
    }
    final rect = RRect.fromRectAndRadius(Rect.fromCenter(center: l, width: w, height: h), Radius.circular(h / 2));
    _fill(_a(_g9, 0.12 * al));
    _c.drawRRect(rect.shift(Offset(0, 2 * _k)).inflate(1.5 * _k), _p);
    _fill(_a(bg, al));
    _c.drawRRect(rect, _p);
    _stroke(_a(border, al), math.max(1, 1.2 * _k));
    _c.drawRRect(rect, _p);
    if (al < 1) {
      _c.saveLayer(rect.outerRect.inflate(2), Paint()..color = _a(_w, al));
      tp.paint(_c, l - Offset(tp.width / 2, tp.height / 2));
      _c.restore();
    } else {
      tp.paint(_c, l - Offset(tp.width / 2, tp.height / 2));
    }
  }

  // --- vegetación y casas ---

  void _grassTuft(double x, double y, double s, int type) {
    final p = _pt(x, y);
    final h = (type == 1 ? 9 : 7) * _k * s;
    final sway = math.sin(_t * 2.5 + x * 2 + y) * 1.5 * _k;
    _stroke(_col.grass, math.max(1, 1.2 * _k * s), cap: StrokeCap.round);
    final path = Path()
      ..moveTo(p.dx - 2.5 * _k, p.dy)
      ..quadraticBezierTo(p.dx - 5 * _k + sway, p.dy - h * 0.7, p.dx - 6 * _k + sway * 1.3, p.dy - h)
      ..moveTo(p.dx, p.dy)
      ..quadraticBezierTo(p.dx + sway * 0.5, p.dy - h * 0.8, p.dx + sway, p.dy - h * 1.2)
      ..moveTo(p.dx + 2.5 * _k, p.dy)
      ..quadraticBezierTo(p.dx + 4.5 * _k + sway, p.dy - h * 0.65, p.dx + 6 * _k + sway * 1.2, p.dy - h * 0.95);
    _c.drawPath(path, _p);
  }

  void _flower(double x, double y, double s, Color col) {
    if (_col.night > 0.85) return;
    final p = _pt(x, y);
    final r = 2.4 * _k * s;
    final top = p - Offset(0, 5 * _k * s);
    _stroke(_col.stem, 1);
    _c.drawLine(p, top, _p);
    _fill(col);
    _c.drawCircle(top, r, _p);
    _fill(_y4);
    _c.drawCircle(top, r * 0.45, _p);
  }

  void _bush(double x, double y, double r, int ci) {
    _shadow(x, y, r * 0.9, _col.night > 0.5 ? 0.25 : 0.08);
    final p = _pt(x, y);
    final rr = r * _tw * _k * 0.8;
    _fill(_col.bush(ci));
    _c.drawCircle(p + Offset(-rr * 0.38, -rr * 0.45), rr * 0.65, _p);
    _c.drawCircle(p + Offset(rr * 0.38, -rr * 0.5), rr * 0.6, _p);
    _c.drawCircle(p + Offset(0, -rr * 0.75), rr * 0.72, _p);
    _fill(_a(_w, _lerp(0.22, 0.06, _col.night)));
    _c.drawCircle(p + Offset(-rr * 0.2, -rr * 0.9), rr * 0.35, _p);
  }

  void _finca(double x, double y) {
    _shadow(x, y, 1.1, _col.night > 0.5 ? 0.2 : 0.08);
    _box(x, y, 0, 1.6, 1.2, 0.9, _col.fincaWall);
    const top = 0.9, rh = 0.6;
    final ym = y + 0.6;
    _poly([_pt(x, y, top), _pt(x + 1.6, y, top), _pt(x + 1.6, ym, top + rh), _pt(x, ym, top + rh)], _col.fincaRoof);
    _poly([_pt(x + 1.6, y, top), _pt(x + 1.6, y + 1.2, top), _pt(x + 1.6, ym, top + rh)], _col.fincaRoofSide);
    _poly([
      _pt(x, ym, top + rh),
      _pt(x + 1.6, ym, top + rh),
      _pt(x + 1.6, y + 1.2, top),
      _pt(x, y + 1.2, top),
    ], _col.fincaRoof);
    _faceL(x, y, 0, 1.6, 1.2, 0.9, 0.2, 0.45, 0.3, 0.65, _col.fincaWindow);
  }

  void _palm(double x, double y, double r) {
    _shadow(x, y, r * 0.9, _col.night > 0.5 ? 0.22 : 0.08);
    final a = _pt(x, y), d = _pt(x + 0.15, y + 0.1, 1.35 * r).dy;
    _stroke(_col.trunk, math.max(1.8, 0.14 * _tw * _k));
    _c.drawPath(
      Path()
        ..moveTo(a.dx, a.dy)
        ..quadraticBezierTo(a.dx + 4 * _k, (a.dy + d) / 2, a.dx + 3 * _k, d),
      _p,
    );
    _stroke(_col.palm, math.max(1.4, 2.2 * _k * r), cap: StrokeCap.round);
    final px = a.dx + 3 * _k, py = d;
    for (var ang = 0.0; ang < 6.28; ang += 1.05) {
      final len = 20 * _k * r;
      _c.drawPath(
        Path()
          ..moveTo(px, py)
          ..quadraticBezierTo(
            px + math.cos(ang) * len * 0.6,
            py + math.sin(ang) * len * 0.3 - 4 * _k,
            px + math.cos(ang) * len,
            py + math.sin(ang) * len * 0.58 + 5 * _k,
          ),
        _p,
      );
    }
  }

  void _crown(double x, double y, double r, Color shade, Color main, {required bool flowers}) {
    _shadow(x + 0.1, y + 0.1, r * 0.95, _col.night > 0.5 ? 0.24 : 0.08);
    final a = _pt(x, y), d = _pt(x, y, 0.55);
    _stroke(_col.trunk, math.max(1.8, 0.16 * _tw * _k));
    _c.drawLine(a, d, _p);
    final p = _pt(x, y, 0.55 + r * 1.05);
    final rr = r * _tw * _k * 0.95;
    _fill(shade);
    _c.drawCircle(p + Offset(-rr * 0.32, rr * 0.08), rr * 0.62, _p);
    _c.drawCircle(p + Offset(rr * 0.32, rr * 0.08), rr * 0.62, _p);
    _c.drawCircle(p + Offset(0, -rr * 0.25), rr * 0.82, _p);
    if (flowers) {
      _fill(main);
      _c.drawCircle(p + Offset(-rr * 0.15, -rr * 0.35), rr * 0.68, _p);
    } else {
      _fill(_a(_w, _lerp(0.2, 0.07, _col.night)));
      _c.drawCircle(p + Offset(-rr * 0.24, -rr * 0.48), rr * 0.42, _p);
    }
  }

  void _person(double x, double y, Color shirt, double al, double bob) {
    if (al <= 0) return;
    _shadow(x, y, 0.2, (_col.night > 0.5 ? 0.22 : 0.12) * al);
    final p = _pt(x, y);
    final w = 0.26 * _tw * _k, h = 0.7 * _hz * _k;
    _fill(_a(shirt, al));
    _c.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(p.dx - w / 2, p.dy - h - bob, w, h), Radius.circular(w / 2)),
      _p,
    );
    _fill(_a(_Tint.skin, al));
    _c.drawCircle(Offset(p.dx, _pt(x, y, 0.92).dy - bob), 0.15 * _tw * _k, _p);
  }

  void _truck(double x, double y, bool cargo) {
    _shadow(x - 0.1, y, 1.1, _col.night > 0.5 ? 0.26 : 0.12);
    final n = _col.night;
    if (n > 0.28) {
      final beam = (n - 0.28) / 0.72 * 0.42;
      final h = _pt(x + 0.98, y - 0.15, 0.4), f1 = _pt(x + 4.2, y - 1.2), f3 = _pt(x + 4.2, y + 0.8);
      final mid = Offset((f1.dx + f3.dx) / 2, (f1.dy + f3.dy) / 2);
      _p
        ..style = PaintingStyle.fill
        ..shader = RadialGradient(
          colors: [_a(_y50, beam * 0.95), _a(_y50, beam * 0.45), _a(_y50, 0)],
          stops: const [0, 0.5, 1],
        ).createShader(Rect.fromCircle(center: mid, radius: math.max(1, 85 * _k)));
      _c.drawPath(Path()..addPolygon([h, f1, f3], true), _p);
      _p.shader = null;
    }
    _box(x - 1.05, y - 0.45, 0.22, 1.4, 0.9, 0.14, _Tint.chassis);
    _box(x + 0.38, y - 0.45, 0.22, 0.6, 0.9, 0.78, _Tint.cab);
    _faceL(x + 0.38, y - 0.45, 0.22, 0.6, 0.9, 0.78, 0.15, 0.85, 0.45, 0.85, _Tint.windshield);
    for (final wx in const [-0.7, 0.65]) {
      final p = _pt(x + wx, y + 0.45, 0.2);
      _fill(_Tint.wheel);
      _c.save();
      _c.translate(p.dx, p.dy);
      _c.rotate(math.atan2(_th, _tw));
      _c.drawOval(Rect.fromCenter(center: Offset.zero, width: 0.4 * _tw * _k, height: 0.42 * _hz * _k), _p);
      _c.restore();
    }
    if (cargo) _crate(x - 0.95, y - 0.38, 0.36, 0.72, true, true);
  }

  void _lock(Offset p, double s, double al) {
    if (al <= 0) return;
    _fill(_a(_g9, al));
    _c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(p.dx - s * 0.55, p.dy - s * 0.1, s * 1.1, s * 0.85),
        Radius.circular(s * 0.15),
      ),
      _p,
    );
    _stroke(_a(_g9, al), math.max(1.5, s * 0.18));
    _c.drawArc(Rect.fromCircle(center: p - Offset(0, s * 0.1), radius: s * 0.32), math.pi, math.pi, false, _p);
  }

  // --- paradas ---

  double _act(int i) => _camS >= i ? 1 : _out(_cl(1 - (i - _camS) / 0.9));

  void _scenes(List<(double, VoidCallback)> d) {
    final sh = _col.shadowA;
    // 0 · Donación
    {
      final (sx, sy) = _stops[0];
      final a = _act(0);
      d.add((
        sx - 1.4 + sy - 2.2,
        () {
          _shadow(sx - 1.2, sy - 1.5, 1, sh);
          _box(sx - 1.5, sy - 2.3, 0, 0.32, 1.6, 2.7, _Tint.terminal);
          _face(sx - 1.5, sy - 2.3, 0, 0.32, 1.6, 2.7, 0.08, 0.92, 0.06, 0.94, _g50);
          _heart(_pt(sx - 1.18, sy - 1.5, 1.75), 30 * _k, _g5);
          _label(sx - 1.18, sy - 1.5, 1.75, sx - 1.18, sy - 1.5, 3.1, 'Donar', variant: 'done');
        },
      ));
      d.add((
        sx + 0.6 + sy - 2.3 + 0.7,
        () {
          _shadow(sx + 1.3, sy - 1.6, 1.1, sh);
          _box(sx + 0.6, sy - 2.4, 0, 1.4, 1.4, 1.15, _Tint.fund, 0.92);
          _faceL(sx + 0.6, sy - 2.4, 0, 1.4, 1.4, 1.15, 0.15, 0.85, 0.35, 0.7, _a(_w, 0.18));
          final n = 1 + (5 * a).round();
          for (var j = 0; j < n; j++) {
            final p = _pt(sx + 1.3, sy - 1.7, 1.15 + j * 0.09);
            _fill(j.isOdd ? _Tint.coinDark : _y4);
            _c.drawOval(Rect.fromCenter(center: p, width: 0.64 * _tw * _k, height: 0.32 * _tw * _k), _p);
          }
          _label(sx + 1.3, sy - 1.7, 1.2, sx + 2.6, sy - 1.8, 3.1, 'Fondo de la convocatoria', al: a);
        },
      ));
      d.add((
        sx + sy + 1,
        () {
          if (a < 0.2) return;
          for (var j = 0; j < 4; j++) {
            final qd = (_t * 0.45 + j / 4) % 1;
            final x = _lerp(sx - 1.1, sx + 1.3, qd), y = _lerp(sy - 1.5, sy - 1.7, qd);
            final z = _lerp(1.6, 1.4, qd) + math.sin(math.pi * qd) * 1.1;
            _coin(_pt(x, y, z), 0.2 * _tw * _k, math.cos(_t * 5 + j), a * math.sin(math.pi * qd));
          }
        },
      ));
      d.add((sx - 2.8 + sy - 2.5, () => _label(sx - 1.5, sy - 2.3, 0.8, sx - 3.4, sy - 2.6, 2.4, 'Pasarela de pago')));
    }

    // 1 · Bodega
    {
      final (sx, sy) = _stops[1];
      final a = _act(1), bx = sx - 1.2, by = sy - 4.2;
      d.add((
        bx + by,
        () {
          _poly([_pt(bx, by), _pt(bx + 3.6, by), _pt(bx + 3.6, by + 2.6), _pt(bx, by + 2.6)], _col.warehouseFloor);
          _box(bx, by, 0, 3.6, 0.16, 2.5, _Tint.stone);
          _box(bx - 0.16, by, 0, 0.16, 2.6, 2.5, _Tint.stone);
          for (final lv in const [0.75, 1.55]) {
            _box(bx + 0.15, by + 0.2, lv, 3.3, 0.85, 0.07, _Tint.shelf);
          }
        },
      ));
      d.add((
        bx + by + 0.6,
        () {
          var j = 0;
          for (final lv in const [0.82, 1.62]) {
            for (var i = 0; i < 4; i++, j++) {
              final p = _back(_cl(a * 1.4 - j * 0.05));
              if (p <= 0) continue;
              _crate(bx + 0.3 + i * 0.8, by + 0.27, lv + (1 - p) * 0.8, 0.62, true, false, _cl(p * 2));
            }
          }
        },
      ));
      d.add((
        bx + 3.2 + by + 2.9,
        () => _label(bx + 1.8, by + 1.2, 1.8, bx + 1.8, by + 1.2, 3.4, 'Lote registrado · QR', al: a),
      ));
      d.add((bx + 3.8 + by + 2.8, () => _label(bx + 1.8, by + 1.2, 0, bx + 3.8, by + 2.8, 2.2, 'Bodega')));
    }

    // 2 · Ruta y reparto
    {
      final (sx, sy) = _stops[2];
      final a = _act(2), px = sx - 1.4, py = sy - 3;
      d.add((px + py, () => _box(px - 0.1, py - 0.1, 0, 1.9, 1.3, 0.14, _Tint.shelf)));
      d.add((
        px + py + 1,
        () {
          final sp = _inOut(_ss(0.25, 0.85, a));
          _crate(px, py, 0.14, 1.0, true, true);
          _crate(px + 1.0 * sp + 0.05, py + 0.15 + sp * 1.6, 0.14, 0.78, true, false, _cl(sp * 3));
          _label(px + 0.5, py + 0.5, 0.14, px + 0.5, py + 0.5, 1.35, sp > 0.5 ? 'Parte 1' : 'Lote');
          if (sp > 0.05) {
            final x = px + 1.0 * sp + 0.45, y = py + 0.55 + sp * 1.6;
            _label(x, y, 0.14, x, y, 1.15, 'Parte 2', variant: 'badge', al: _cl(sp * 2));
          }
          if (sp > 0.5) {
            _label(px + 0.5, py + 0.5, 0.4, px + 0.4, py + 0.5, 2.35, 'Lote dividido', al: _cl((sp - 0.5) * 3));
          }
        },
      ));
      d.add((sx + 3.6 + sy + 2.8, () => _label(sx + 1.8, sy + 1.4, 0, sx + 3.6, sy + 2.8, 1.8, 'Ruta de entrega')));
      d.add((30, () => _label(18.5, 5.8, 0, 19.2, 6.8, 1.6, 'Punto de control')));
    }

    // 3 · Sello en la red pública
    {
      final (sx, sy) = _stops[3];
      final a = _act(3), cx = sx - 0.2, cy = sy - 2.4;
      d.add((
        cx + cy - 1,
        () {
          for (var j = 0; j < 7; j++) {
            final x = sx - 4.6 + j * 0.62, y = sy - 1.25;
            final lit = _cl(a * 1.6 - j * 0.08);
            final pulse = (math.sin(_t * 3 - j * 0.9) + 1) / 2 * 0.35;
            _cube(x, y, 0, 0.34, lit > 0 ? _col.chainCube : _Tint.stone, 0.5 + lit * 0.5);
            if (lit > 0 && j < 6) {
              _stroke(_a(_col.chain, (_col.night > 0.5 ? 0.6 : 0.4) + pulse), 2.2);
              final p = _pt(x + 0.17, y, 0.17), q = _pt(x + 0.45, y, 0.17);
              final len = (q - p).distance, dir = (q - p) / (len == 0 ? 1 : len);
              for (var s = 0.0; s < len; s += 6) {
                _c.drawLine(p + dir * s, p + dir * math.min(len, s + 3), _p);
              }
            }
          }
          _box(cx - 1, cy - 1, 0, 2, 2, 0.45, _Tint.stone);
        },
      ));
      d.add((
        cx + cy + 2,
        () {
          final leaves = [
            for (final dx in const [-1.05, -0.35, 0.35, 1.05]) (cx + dx, cy, 1.55),
          ];
          final mids = [(cx - 0.7, cy, 2.75), (cx + 0.7, cy, 2.75)];
          final root = (cx, cy, 3.95);
          final pl = _ss(0.05, 0.4, a), pm = _ss(0.35, 0.65, a), pr = _ss(0.6, 0.85, a), pb = _ss(0.8, 1, a);
          void ln((double, double, double) aa, (double, double, double) bb, double al) {
            if (al <= 0) return;
            _stroke(_a(_col.chain, (_col.night > 0.5 ? 0.85 : 0.7) * al), math.max(1.5, 2.4 * _k));
            _c.drawLine(_pt(aa.$1, aa.$2, aa.$3 + 0.2), _pt(bb.$1, bb.$2, bb.$3 + 0.2), _p);
          }

          if (pb > 0) {
            final p = _pt(root.$1, root.$2, root.$3 + 0.4);
            final bw = 24 * _k;
            final rect = Rect.fromLTWH(p.dx - bw / 2, 0, bw, math.max(0, p.dy));
            _p
              ..style = PaintingStyle.fill
              ..shader = LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [_a(_y4, (_col.night > 0.5 ? 0.6 : 0.45) * pb), _a(_y4, 0)],
              ).createShader(rect);
            _c.drawRect(rect, _p);
            _p.shader = null;
          }
          for (var j = 0; j < leaves.length; j++) {
            ln(leaves[j], mids[j >> 1], pm);
          }
          for (final m in mids) {
            ln(m, root, pr);
          }
          for (var j = 0; j < leaves.length; j++) {
            final p = _back(_cl(pl * 1.3 - j * 0.08));
            if (p > 0) _cube(leaves[j].$1, leaves[j].$2, leaves[j].$3 + (1 - p) * 0.6, 0.36, _Tint.blue, _cl(p * 2));
          }
          for (final m in mids) {
            final p = _back(pm);
            if (p > 0) _cube(m.$1, m.$2, m.$3 + (1 - p) * 0.6, 0.44, _Tint.blue, _cl(p * 2));
          }
          final p = _back(pr);
          if (p > 0) {
            _cube(root.$1, root.$2, root.$3 + (1 - p) * 0.6, 0.6, _Tint.gold, _cl(p * 2));
            _lock(_pt(root.$1 + 0.3, root.$2 + 0.3, root.$3 + 0.3), 14 * _k * math.max(0.5, p), _ss(0.85, 1, a));
          }
          _label(cx, cy, 3.95, cx, cy, 5.3, 'Raíz anclada', al: pb);
        },
      ));
      d.add((cx + 2.4 + cy + 2.0, () => _label(cx, cy, 0.45, cx + 2.4, cy + 2.0, 2.6, 'Anclaje en blockchain')));
    }

    // 4 · Entrega
    {
      final (sx, sy) = _stops[4];
      final a = _act(4), hx = sx - 1.2, hy = sy - 4.1;
      d.add((
        hx + hy + 1,
        () {
          _shadow(hx + 1.4, hy + 1.2, 2, _col.night > 0.5 ? 0.22 : 0.08);
          _box(hx, hy, 0, 2.8, 2.1, 1.5, _Tint.house);
          const top = 1.5, rh = 0.9;
          final ym = hy + 1.05;
          _poly([_pt(hx, hy, top), _pt(hx + 2.8, hy, top), _pt(hx + 2.8, ym, top + rh), _pt(hx, ym, top + rh)], _g8);
          _poly([_pt(hx + 2.8, hy, top), _pt(hx + 2.8, hy + 2.1, top), _pt(hx + 2.8, ym, top + rh)], _Tint.house[2]);
          _poly([
            _pt(hx, ym, top + rh),
            _pt(hx + 2.8, ym, top + rh),
            _pt(hx + 2.8, hy + 2.1, top),
            _pt(hx, hy + 2.1, top),
          ], _mx(_g8, 0.6, _g5));
          _faceL(hx, hy, 0, 2.8, 2.1, 1.5, 0.38, 0.6, 0, 0.62, _y9);
          final win = _col.houseWindow;
          _faceL(hx, hy, 0, 2.8, 2.1, 1.5, 0.1, 0.28, 0.4, 0.72, win);
          _faceL(hx, hy, 0, 2.8, 2.1, 1.5, 0.7, 0.88, 0.4, 0.72, win);
          _face(hx, hy, 0, 2.8, 2.1, 1.5, 0.2, 0.45, 0.4, 0.72, win);
          _face(hx, hy, 0, 2.8, 2.1, 1.5, 0.6, 0.85, 0.4, 0.72, win);
        },
      ));
      d.add((
        hx + hy + 3.2,
        () {
          final st = _ss(0.3, 0.75, a);
          _crate(hx + 0.2, hy + 2.35, 0, 0.7, true, true);
          if (st > 0) {
            _crate(
              _lerp(sx - 0.95, hx + 0.2, st),
              _lerp(sy - 0.23, hy + 2.35, st),
              0.7 * st + math.sin(math.pi * st) * 0.6,
              0.7,
              true,
              true,
            );
          }
        },
      ));
      final ppl = [
        (hx + 1.4, hy + 2.7),
        (hx + 2.05, hy + 2.55),
        (hx + 1.75, hy + 3.2),
        (hx + 2.6, hy + 3.0),
        (hx + 0.95, hy + 3.35),
      ];
      d.add((
        hx + hy + 5.6,
        () {
          for (var j = 0; j < ppl.length; j++) {
            final bob = (math.sin(_t * 2.2 + j)).abs() * 2 * _k * _ss(0.7, 1, a);
            _person(ppl[j].$1, ppl[j].$2, _Tint.people[j], _cl(a * 1.6 - j * 0.12), bob);
          }
        },
      ));
      d.add((
        hx + hy + 6,
        () {
          final p = _back(_ss(0.6, 0.9, a));
          if (p <= 0) return;
          final q = _pt(hx + 1.4, hy + 1.05, 4.2);
          final r = 16 * _k * p;
          _fill(_g5);
          _c.drawCircle(q, r.abs(), _p);
          _stroke(_w, math.max(2, 3 * _k * p), cap: StrokeCap.round);
          _c.drawPath(
            Path()
              ..moveTo(q.dx - r * 0.4, q.dy)
              ..lineTo(q.dx - r * 0.1, q.dy + r * 0.32)
              ..lineTo(q.dx + r * 0.42, q.dy - r * 0.3),
            _p,
          );
          _label(hx + 1.4, hy + 1.05, 2.4, hx + 1.4, hy + 1.05, 5.1, 'Entrega confirmada', variant: 'done', al: _cl(p));
        },
      ));
      d.add((hx + 3.4 + hy + 3.0, () => _label(hx + 1.4, hy + 2.1, 0, hx + 3.4, hy + 3.0, 2.2, 'Centro comunitario')));
    }

    // Camión, moneda y mundo vivo
    final u = _camS;
    if (u >= 4.4) {
      final (tx, ty) = _road(0.85 + (_t * 0.16) % 3.15);
      final bounce = math.sin(_t * 8) * 0.025;
      d.add((tx + ty, () => _truck(tx, ty + 0.15 + bounce, true)));
      final (mx, my) = _road(1.1 + (_t * 0.26 + 1.6) % 2.7);
      d.add((
        mx + my + 0.1,
        () {
          _shadow(mx, my, 0.45, sh);
          _box(mx - 0.25, my - 0.15, 0.15, 0.5, 0.35, 0.3, _Tint.moto);
          _crate(mx - 0.15, my - 0.1, 0.45, 0.32, false, false);
          final p = _pt(mx, my, 0.7);
          _fill(_col.night > 0.4 ? _y50 : _y4);
          _c.drawCircle(p + Offset(4 * _k, 0), 3 * _k, _p);
        },
      ));
      for (var j = 0; j < 3; j++) {
        final qd = (_t * 0.32 + j / 3) % 1;
        final (cx, cy) = _road(0.85 + qd * 3.1);
        final cz = 0.55 + math.sin(math.pi * qd) * 0.85;
        d.add((
          cx + cy + 0.3,
          () {
            final al = 0.85 * math.sin(math.pi * qd);
            _shadow(cx, cy, 0.28, (_col.night > 0.5 ? 0.2 : 0.08) * al);
            _coin(_pt(cx, cy, cz), 0.3 * _tw * _k, math.cos(_t * 5 + j * 2), al);
          },
        ));
      }
    } else {
      if (u > 0.12 && u < 0.98) {
        final (x, y) = _road(u);
        final al = _ss(0.12, 0.3, u) * (1 - _ss(0.85, 0.98, u));
        d.add((
          x + y + 0.5,
          () {
            _shadow(x, y, 0.35, (_col.night > 0.5 ? 0.22 : 0.12) * al);
            _coin(_pt(x, y, 0.75 + math.sin(_t * 3) * 0.08), 0.42 * _tw * _k, math.cos(u * 24), al);
          },
        ));
      }
      final (x, y) = _road(u.clamp(1, 4).toDouble());
      final delivered = u > 3.5 && _ss(0.3, 0.75, _act(4)) > 0.02;
      d.add((x + y, () => _truck(x, y + 0.15, !delivered)));
    }
  }

  // --- cuadro completo ---

  bool _visible(Offset p, double m) =>
      p.dx >= -m && p.dx <= _size.width + m && p.dy >= -m && p.dy <= _size.height + m * 1.6;

  void _draw() {
    final w = _size.width, h = _size.height, n = _col.night;
    _c.drawColor(_col.ground, BlendMode.src);

    for (final m in _data.meadows) {
      final p = _pt(m.x, m.y);
      final kw = m.w * _tw * _k, kh = m.h * _th * _k;
      if (p.dx < -kw || p.dx > w + kw || p.dy < -kh || p.dy > h + kh) continue;
      _fill(_col.meadow(m.day, m.night));
      _c.save();
      _c.translate(p.dx, p.dy);
      _c.rotate(m.rot);
      _c.drawOval(Rect.fromCenter(center: Offset.zero, width: 2 * kw, height: 2 * kh), _p);
      _c.restore();
    }

    // Sol y luna
    final sunA = _cl(1 - n * 1.55);
    if (sunA > 0.01) {
      final s = Offset(w * 0.82, h * 0.15 + n * 110);
      final sr = math.max(11, 15 * _k).toDouble();
      _p
        ..style = PaintingStyle.fill
        ..shader = RadialGradient(
          colors: [_a(_y4, sunA * 0.35), _a(_y4, 0)],
          stops: const [0.14, 1],
        ).createShader(Rect.fromCircle(center: s, radius: sr * 2.8));
      _c.drawCircle(s, sr * 2.8, _p);
      _fill(_a(_y4, sunA));
      _c.drawCircle(s, sr, _p);
      _stroke(_a(_y4, sunA), math.max(1.8, 2.2 * _k), cap: StrokeCap.round);
      for (var i = 0; i < 8; i++) {
        final ang = i * math.pi / 4 + _t * 0.08;
        final dir = Offset(math.cos(ang), math.sin(ang));
        _c.drawLine(s + dir * (sr * 1.35), s + dir * (sr * 1.8), _p);
      }
    }
    final moonA = _cl((n - 0.25) / 0.75);
    if (moonA > 0.01) {
      final m = Offset(w * 0.82, h * 0.14 - (1 - n) * 35);
      final mr = math.max(12, 16 * _k).toDouble();
      _p
        ..style = PaintingStyle.fill
        ..shader = RadialGradient(
          colors: [_a(_b5, moonA * 0.25), _a(_b5, 0)],
          stops: const [0.16, 1],
        ).createShader(Rect.fromCircle(center: m, radius: mr * 2.5));
      _c.drawCircle(m, mr * 2.5, _p);
      _fill(_a(_y50, moonA * 0.95));
      _c.drawCircle(m, mr, _p);
      _fill(_col.ground);
      _c.drawCircle(m + Offset(mr * 0.45, -mr * 0.1), mr * 0.88, _p);
      for (final st in _data.stars) {
        final al = moonA * (0.35 + 0.55 * math.sin(_t * 3 + st.phase));
        if (al <= 0.05) continue;
        _fill(_a(st.gold ? _y4 : _w, al));
        _c.drawCircle(Offset(st.x * w, st.y * h * 0.45), st.r, _p);
      }
    }

    // Río
    _strip(_data.riverPts, 2.5, _col.riverBank);
    _strip(_data.riverPts, 2.0, _col.riverWater);
    _strip(_data.riverPts, 1.3, _col.riverDeep);
    if (n < 0.6) {
      _fill(_a(_w, (1 - n) * 0.42));
      for (var i = 2; i < _data.riverPts.length - 2; i += 6) {
        final (rx, ry) = _data.riverPts[i];
        final p = _pt(rx + math.sin(_t * 2 + i) * 0.35, ry);
        if (p.dx > -20 && p.dx < w + 20 && p.dy > -20 && p.dy < h + 20) {
          _c.drawOval(Rect.fromCenter(center: p, width: 9 * _k, height: 2.4 * _k), _p);
        }
      }
    }

    // Parcelas
    for (final cf in _Data.crops) {
      _poly([
        _pt(cf.x, cf.y),
        _pt(cf.x + cf.w, cf.y),
        _pt(cf.x + cf.w, cf.y + cf.d),
        _pt(cf.x, cf.y + cf.d),
      ], _col.crop(cf.c));
      _stroke(_col.cropRow(cf.c), math.max(1, 1.2 * _k));
      for (var i = 0.3; i < cf.w - 0.2; i += 0.55) {
        _c.drawLine(_pt(cf.x + i, cf.y + 0.1), _pt(cf.x + i, cf.y + cf.d - 0.1), _p);
      }
    }

    // Carretera y camino lateral
    _strip(_data.roadPts, 0.82, _col.roadBase);
    _strip(_data.roadPts, 0.68, _col.roadSurface);
    _dashes(_data.roadPts, _col.dash);
    _strip(_data.sidePts, 0.6, _col.roadBase);
    _strip(_data.sidePts, 0.48, _col.roadSurface);

    // Pasto y flores
    for (final g in _data.grass) {
      final p = _pt(g.x, g.y);
      if (p.dx < -40 || p.dx > w + 40 || p.dy < -40 || p.dy > h + 40) continue;
      if (g.type == 2) {
        _flower(g.x, g.y, g.s, _Tint.flowers[g.col]);
      } else {
        _grassTuft(g.x, g.y, g.s, g.type);
      }
    }

    // Luciérnagas
    if (n > 0.4) {
      for (final (fx0, fy0, fp) in _data.fireflies) {
        final p = _pt(
          fx0 + math.sin(_t * 1.5 + fp) * 0.6,
          fy0 + math.cos(_t * 1.2 + fp) * 0.4,
          0.4 + math.sin(_t * 2 + fp) * 0.3,
        );
        if (p.dx < -20 || p.dx > w + 20 || p.dy < -20 || p.dy > h + 20) continue;
        final glow = (math.sin(_t * 4 + fp) + 1) / 2;
        _fill(_a(_mx(_y4, 0.8, _w), n * (0.35 + glow * 0.6)));
        _c.drawCircle(p, math.max(1.5, 2.5 * _k), _p);
      }
    }

    // Follaje, fincas y paradas ordenados por profundidad
    final d = <(double, VoidCallback)>[];
    const m = 140.0;
    for (final b in _data.bushes) {
      if (!_visible(_pt(b.$1, b.$2), m)) continue;
      d.add((b.$1 + b.$2, () => _bush(b.$1, b.$2, b.$3, b.$4)));
    }
    for (final t in _data.trees) {
      if (!_visible(_pt(t.$1, t.$2), m)) continue;
      d.add((
        t.$1 + t.$2,
        switch (t.$4) {
          4 => () => _crown(t.$1, t.$2, t.$3, _col.bloomShade, _col.bloom, flowers: true),
          5 => () => _palm(t.$1, t.$2, t.$3),
          final c => () => _crown(t.$1, t.$2, t.$3, _col.tree(c), _col.tree(c), flowers: false),
        },
      ));
    }
    for (final f in _Data.fincas) {
      if (!_visible(_pt(f.$1, f.$2), m)) continue;
      d.add((f.$1 + f.$2, () => _finca(f.$1, f.$2)));
    }
    _scenes(d);
    final order = List<int>.generate(d.length, (i) => i)
      ..sort((a, b) {
        final c = d[a].$1.compareTo(d[b].$1);
        return c != 0 ? c : a.compareTo(b);
      });
    for (final i in order) {
      d[i].$2();
    }

    _clouds();
  }

  // Nubes con sombra en el suelo; se desvanecen cerca de las paradas y del haz de anclaje.
  void _clouds() {
    final w = _size.width, h = _size.height, night = _col.night > 0.5;
    final objs = [
      (_stops[0].$1, _stops[0].$2 - 1.5, 1.5, 52.0),
      (_stops[1].$1 + 0.6, _stops[1].$2 - 3.0, 1.5, 62.0),
      (_stops[2].$1 - 0.9, _stops[2].$2 - 2.5, 1.0, 52.0),
      (_stops[3].$1 - 0.2, _stops[3].$2 - 2.4, 2.2, 68.0),
      (_stops[4].$1 + 0.2, _stops[4].$2 - 3.05, 2.0, 68.0),
    ];
    final beam = _pt(_stops[3].$1 - 0.2, _stops[3].$2 - 2.4, 3.95);
    final beamW = 26 * _k;
    final pos = <(_Cloud, double, double, double)>[];
    for (final c in _data.clouds) {
      final raw = c.bx + _t * c.spd;
      final cx = ((raw % 125) + 125) % 125 - 45;
      final cy = c.by + math.sin(_t * 0.12 + c.phase) * 0.5;
      final cp = _pt(cx, cy, c.z);
      final rad = _tw * _k * c.s * 1.5;
      var fade = 1.0;
      if (cp.dy < beam.dy + 30) {
        fade = _cl(((cp.dx - beam.dx).abs() - (beamW * 0.6 + 24)) / math.max(1, rad * 0.82));
      }
      for (final o in objs) {
        final op = _pt(o.$1, o.$2, o.$3);
        fade = math.min(fade, _cl(((cp - op).distance - o.$4 * _k) / math.max(1, rad * 0.85)));
      }
      if (fade > 0.005) pos.add((c, cx, cy, fade));
    }
    for (final (c, cx, cy, fade) in pos) {
      final sp = _pt(cx + c.z * 0.26, cy + c.z * 0.26);
      if (sp.dx < -240 || sp.dx > w + 240 || sp.dy < -240 || sp.dy > h + 240) continue;
      final kw = _tw * _k * c.s, kh = _th * _k * c.s;
      final path = Path();
      for (final (dx, dy, r) in c.puffs) {
        final sr = r * kw * 0.72;
        path.addOval(
          Rect.fromCenter(center: sp + Offset(dx * kw * 0.85, dy * kh * 1.05), width: sr * 2.24, height: sr * 1.12),
        );
      }
      _fill(_a(_g9, (night ? 0.07 : 0.13) * fade));
      _c.drawPath(path, _p);
    }
    for (final (c, cx, cy, fade) in pos) {
      final cp = _pt(cx, cy, c.z);
      if (cp.dx < -240 || cp.dx > w + 240 || cp.dy < -240 || cp.dy > h + 240) continue;
      final kw = _tw * _k * c.s, kh = _th * _k * c.s;
      final al = (night ? 0.86 : 0.95) * fade;
      void layer(Color col, double ox, double oyK, double rk) {
        final path = Path();
        for (final (dx, dy, r) in c.puffs) {
          path.addOval(
            Rect.fromCircle(
              center: cp + Offset(dx * kw * 0.85 + r * kw * ox, dy * kh * 1.05 + r * kw * oyK),
              radius: r * kw * rk,
            ),
          );
        }
        _fill(_a(col, al));
        _c.drawPath(path, _p);
      }

      layer(_col.cloudBase, 0, 0.16, 0.74);
      layer(_col.cloudBody, 0, 0, 0.72);
      layer(_col.cloudHi, 0.05, -0.12, 0.56);
    }
  }
}

/// Portada ilustrada de una convocatoria sin foto (landing, variante 12): cajas con QR apiladas en isométrico.
class CrateArt extends StatelessWidget {
  const CrateArt({super.key});

  @override
  Widget build(BuildContext context) => const ExcludeSemantics(child: CustomPaint(painter: _CratePainter()));
}

class _CratePainter extends CustomPainter {
  const _CratePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.shortestSide / 5.2;
    final o = Offset(size.width / 2, size.height * 0.78);
    Offset p(double x, double y, double z) => o + Offset((x - y) * u * 0.9, (x + y) * u * 0.45 - z * u * 0.95);
    final paint = Paint()..isAntiAlias = true;
    void poly(List<Offset> pts, Color c) => canvas.drawPath(Path()..addPolygon(pts, true), paint..color = c);
    void crate(double x, double y, double z, double s) {
      final h = s * 0.82;
      poly([p(x, y + s, z + h), p(x + s, y + s, z + h), p(x + s, y + s, z), p(x, y + s, z)], _Tint.box[1]);
      poly([p(x + s, y, z + h), p(x + s, y + s, z + h), p(x + s, y + s, z), p(x + s, y, z)], _Tint.box[2]);
      poly([p(x, y, z + h), p(x + s, y, z + h), p(x + s, y + s, z + h), p(x, y + s, z + h)], _Tint.box[0]);
      Offset f(double a, double b) => p(x + s, y + s * a, z + h * b);
      poly([f(0.25, 0.75), f(0.72, 0.75), f(0.72, 0.25), f(0.25, 0.25)], _w);
      poly([f(0.32, 0.68), f(0.46, 0.68), f(0.46, 0.5), f(0.32, 0.5)], _g9);
      poly([f(0.52, 0.68), f(0.66, 0.68), f(0.66, 0.5), f(0.52, 0.5)], _g9);
      poly([f(0.32, 0.44), f(0.46, 0.44), f(0.46, 0.3), f(0.32, 0.3)], _g9);
    }

    canvas.drawOval(
      Rect.fromCenter(center: o + Offset(0, u * 0.2), width: u * 4.2, height: u * 1.3),
      paint..color = _a(_g9, 0.35),
    );
    crate(-1.1, -0.2, 0, 1.1);
    crate(0.1, -0.3, 0, 1.0);
    crate(-0.5, -0.3, 0.92, 0.95);
  }

  @override
  bool shouldRepaint(_CratePainter old) => false;
}
