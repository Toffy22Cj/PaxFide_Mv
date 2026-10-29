import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'city_palette.dart';
import 'city_scene.dart';

/// Dibujo de la ciudad (port de `components/background/cityDraw.ts`, motor isométrico del prototipo).
///
/// Para que vaya fluido en un teléfono:
/// - el suelo que no se mueve (pasto, praderas, caminos, río, calles, plazas, flores) se pinta **una vez** en una
///   imagen del tamaño de la pantalla y en cada fotograma solo se copia;
/// - lo que se mueve se dibuja solo si cae dentro de la pantalla (se descarta lo de fuera antes de pintar);
/// - pinceles y textos de las etiquetas se reutilizan entre fotogramas.
class CityPainter extends CustomPainter {
  CityPainter(this.world) : super(repaint: world);
  final CityWorld world;

  @override
  void paint(Canvas canvas, Size size) => world._draw(canvas, size);

  @override
  bool shouldRepaint(CityPainter oldDelegate) => oldDelegate.world != world;
}

const _tw = 36.0, _th = 18.0, _hz = 22.0;

const _treeSize = {
  TreeKind.shade: (h: 1.4, r: 17.0),
  TreeKind.guayacan: (h: 1.35, r: 15.0),
  TreeKind.jacaranda: (h: 1.3, r: 14.0),
  TreeKind.pine: (h: 1.7, r: 11.0),
};

TreeKind? _kind(TreeType t) => switch (t) {
  TreeType.shade => TreeKind.shade,
  TreeType.guayacan => TreeKind.guayacan,
  TreeType.jacaranda => TreeKind.jacaranda,
  TreeType.pine => TreeKind.pine,
  _ => null,
};

/// Estado de la ciudad: la escena, el reloj del mundo y cuánto es de noche (0 día, 1 noche). Avisa a su pintor con
/// [tick]; no reconstruye ningún widget.
class CityWorld extends ChangeNotifier {
  CityWorld({this.district = District.home});

  final District district;
  final CityScene scene = CityScene.create();
  double t = 0;
  double night = 0;

  /// Avanza [dt] segundos y pide un fotograma.
  void tick(double dt, double targetNight) {
    t += dt;
    night += (targetNight - night) * math.min(1, dt * 4);
    if ((night - targetNight).abs() < 0.01) night = targetNight;
    scene.step(dt);
    notifyListeners();
  }

  /// Fotograma quieto (pausa o «reducir movimiento») con la noche ya en su sitio.
  void still(double targetNight) {
    night = targetNight;
    notifyListeners();
  }

  // ---------------------------------------------------------------- cámara y lienzo
  late Canvas _c;
  double _k = 1, _cx = 0, _cy = 0, _ox = 0, _oy = 0, _w = 0, _h = 0;
  late CityPalette _p;

  ui.Image? _ground;
  (Size, bool, double)? _groundKey;
  final _paint = Paint();
  final _imagePaint = Paint()..filterQuality = FilterQuality.low;
  final _stroke = Paint()..style = PaintingStyle.stroke;
  final _path = Path();
  final Map<String, TextPainter> _tags = {};

  void _camera(Size size) {
    _w = size.width;
    _h = size.height;
    // Como la web en pantallas estrechas (× 0,8) y algo más lejos en una franja baja, para ver el barrio entero.
    _k = district.k * (size.width < 768 ? 0.8 : 1) * (size.height < 400 ? 0.8 : 1);
    _cx = district.x;
    _cy = district.y;
    _ox = size.width / 2;
    _oy = size.height / 2 + 35;
  }

  Offset _iso(double x, double y, [double z = 0]) =>
      Offset(_ox + ((x - _cx) - (y - _cy)) * _tw * _k, _oy + ((x - _cx) + (y - _cy)) * _th * _k - z * _hz * _k);

  /// ¿Algo alrededor de (x, y) cae en pantalla? Margen generoso para árboles y edificios altos.
  bool _visible(double x, double y, [double margin = 140]) {
    final p = _iso(x, y);
    return p.dx > -margin && p.dx < _w + margin && p.dy > -margin * 1.2 && p.dy < _h + margin * 0.6;
  }

  void _draw(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    _camera(size);
    _p = CityPalette.of(night);
    _c = canvas;
    canvas.clipRect(Offset.zero & size);
    final n = night, t = this.t;
    _paint.shader = ui.Gradient.linear(
      Offset.zero,
      Offset(0, size.height),
      [for (final s in _p.sky) s.$2],
      [for (final s in _p.sky) s.$1],
    );
    canvas.drawRect(Offset.zero & size, _paint);
    _paint.shader = null;
    if (n > 0.5) {
      for (var s = 0; s < 60; s++) {
        final x = cityMod(s * 197.3, size.width), y = cityMod(s * 83.7, size.height * 0.55);
        _paint.color = CityPalette.star.withValues(alpha: ((math.sin(t * 2 + s) * 0.5 + 0.5) * 0.7 * n).clamp(0, 1));
        canvas.drawRect(Rect.fromLTWH(x, y, 1.5, 1.5), _paint);
      }
    }
    _drawGround(size, n, t);
    final objects = _sceneObjects(n, t)..sort((a, b) => a.$1.compareTo(b.$1));
    for (final o in objects) {
      o.$2();
    }
    _drawAir(n, t);
  }

  // ---------------------------------------------------------------- primitivas
  void _poly(List<Offset> pts, Color? fill, [Color? stroke, double strokeW = 1]) {
    _path
      ..reset()
      ..addPolygon(pts, true);
    if (fill != null) _c.drawPath(_path, _paint..color = fill);
    if (stroke != null) {
      _c.drawPath(
        _path,
        _stroke
          ..color = stroke
          ..strokeWidth = strokeW * _k,
      );
    }
  }

  void _box(double x, double y, double z, double w, double d, double h, CityBox c) {
    final a = _iso(x, y, z + h), b = _iso(x + w, y, z + h), cc = _iso(x + w, y + d, z + h), dd = _iso(x, y + d, z + h);
    final b0 = _iso(x + w, y, z), c0 = _iso(x + w, y + d, z), d0 = _iso(x, y + d, z);
    _poly([dd, cc, c0, d0], c.left);
    _poly([cc, b, b0, c0], c.right);
    _poly([a, b, cc, dd], c.top);
  }

  void _flat(double x, double y, double w, double d, double z, Color fill, Color stroke) =>
      _poly([_iso(x, y, z), _iso(x + w, y, z), _iso(x + w, y + d, z), _iso(x, y + d, z)], fill, stroke, 1.2);

  void _hipRoof(double x, double y, double z, double w, double d, double h, double o, CityBox c) {
    final a = _iso(x - o, y - o, z), b = _iso(x + w + o, y - o, z);
    final cc = _iso(x + w + o, y + d + o, z), dd = _iso(x - o, y + d + o, z);
    final r1 = _iso(x + w * 0.28, y + d * 0.5, z + h), r2 = _iso(x + w * 0.72, y + d * 0.5, z + h);
    _poly([a, b, r2, r1], c.top);
    _poly([a, dd, r1], c.left);
    _poly([dd, cc, r2, r1], c.left);
    _poly([cc, b, r2], c.right);
  }

  void _windows(
    bool leftFace,
    double x,
    double y,
    double z,
    double length,
    int rows,
    int cols,
    double ws,
    double hs,
    double n,
    double t,
  ) {
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final lit = n > 0.25 && math.sin(t * 0.35 + (r * 7 + c * 13 + x * 3)) > -0.55;
        final col = lit ? CityPalette.windowLit.withValues(alpha: (0.5 + n * 0.45).clamp(0, 1)) : _p.windowOff;
        final u = (c + 0.5) / cols, wz = z + ((r + 0.5) / rows) * (rows * hs * 1.3);
        final (q0, q1) = leftFace
            ? ((x + u * length - ws * 0.4, y), (x + u * length + ws * 0.4, y))
            : ((x, y + u * length - ws * 0.4), (x, y + u * length + ws * 0.4));
        _poly([
          _iso(q0.$1, q0.$2, wz),
          _iso(q1.$1, q1.$2, wz),
          _iso(q1.$1, q1.$2, wz + hs),
          _iso(q0.$1, q0.$2, wz + hs),
        ], col);
      }
    }
  }

  void _groundShadow(double x, double y, double rx, double ry, [double a = 0.16]) {
    final p = _iso(x, y, 0.01);
    _c.drawOval(
      Rect.fromCenter(center: p, width: rx * _tw * _k * 2, height: ry * _th * _k * 2),
      _paint..color = CityPalette.shadow.withValues(alpha: a),
    );
  }

  void _line(Offset a, Offset b, Color color, double width, {StrokeCap cap = StrokeCap.round}) => _c.drawLine(
    a,
    b,
    _stroke
      ..color = color
      ..strokeWidth = width
      ..strokeCap = cap,
  );

  // ---------------------------------------------------------------- vegetación
  void _canopy(Offset top, double rad, List<Color> cols, double t, double seed) {
    final br = 1 + math.sin(t * 1.3 + seed) * 0.03;
    _c
      ..drawCircle(top.translate(0, -3 * _k), rad * br, _paint..color = cols[0])
      ..drawCircle(top.translate(-rad * 0.38, -rad * 0.2), rad * 0.74 * br, _paint..color = cols[1])
      ..drawCircle(top.translate(rad * 0.42, -rad * 0.14), rad * 0.76 * br, _paint)
      ..drawCircle(top.translate(rad * 0.08, -rad * 0.5), rad * 0.62 * br, _paint..color = cols[2]);
  }

  void _tree(TreeType type, double x, double y, double s, double t) {
    if (type == TreeType.palm) return _palm(x, y, s, t);
    if (type == TreeType.bush) return _bush(x, y, 0.45 * s);
    final kind = _kind(type)!;
    final size = _treeSize[kind]!, col = _p.trees[kind]!;
    _groundShadow(x, y, 0.8 * s, 0.42 * s, 0.24);
    final sway = math.sin(t * 1.6 + x * 1.5 + y) * 0.08 * s;
    final base = _iso(x, y), top = _iso(x + sway, y - sway, size.h * s);
    _line(base, top, col.trunk, math.max(2, 4.6 * s * _k));
    if (kind == TreeKind.pine) {
      for (var i = 0; i < 3; i++) {
        final w = (size.r - i * 3) * _k * s, yy = top.dy + (6 - i * 9) * _k * s;
        _path
          ..reset()
          ..moveTo(top.dx - w, yy)
          ..lineTo(top.dx + w, yy)
          ..lineTo(top.dx + sway * 20, yy - 16 * _k * s)
          ..close();
        _c.drawPath(_path, _paint..color = col.canopy[i]);
      }
      return;
    }
    _canopy(top, size.r * _k * s, col.canopy, t, x * 3 + y);
  }

  void _palm(double x, double y, double s, double t) {
    _groundShadow(x, y, 0.5 * s, 0.26 * s, 0.22);
    final sway = math.sin(t * 1.8 + x * 1.3) * 0.12 * s;
    final base = _iso(x, y), top = _iso(x + sway, y - sway, 1.8 * s);
    _path
      ..reset()
      ..moveTo(base.dx, base.dy)
      ..quadraticBezierTo(base.dx + 5 * _k, (base.dy + top.dy) / 2, top.dx, top.dy);
    _c.drawPath(
      _path,
      _stroke
        ..color = _p.palmTrunk
        ..strokeWidth = math.max(2, 3.4 * _k * s)
        ..strokeCap = StrokeCap.round,
    );
    for (var i = 0; i < 6; i++) {
      final ang = (i / 6) * math.pi * 2 + math.sin(t * 0.9 + x) * 0.15;
      final len = (16 + (i % 2) * 5) * _k * s;
      _path
        ..reset()
        ..moveTo(top.dx, top.dy)
        ..quadraticBezierTo(
          top.dx + math.cos(ang) * len * 0.55,
          top.dy - 8 * _k,
          top.dx + math.cos(ang) * len,
          top.dy + math.sin(ang) * len * 0.55 + 3 * _k,
        );
      _c.drawPath(
        _path,
        _stroke
          ..color = _p.palmLeaves[i % 4]
          ..strokeWidth = math.max(1.5, 2.5 * _k * s),
      );
    }
  }

  void _bush(double x, double y, double r, [Color? col]) {
    _groundShadow(x, y, r * 0.8, r * 0.4, 0.18);
    final b = _iso(x, y, 0.12);
    _paint.color = col ?? _p.bush;
    _c
      ..drawCircle(b, r * 14 * _k, _paint)
      ..drawCircle(b.translate(-r * 5 * _k, r * 2 * _k), r * 10 * _k, _paint)
      ..drawCircle(b.translate(r * 5 * _k, r * 2 * _k), r * 10 * _k, _paint)
      ..drawCircle(b.translate(-r * 3 * _k, -r * 6 * _k), r * 5 * _k, _paint..color = _p.bushHighlight);
  }

  void _lamp(double x, double y, double n) {
    final p0 = _iso(x, y), p1 = _iso(x, y, 1.05);
    _line(p0, p1, _p.lampPole, math.max(1.4, 2 * _k), cap: StrokeCap.butt);
    _c.drawCircle(
      p1,
      math.max(2, 3.2 * _k),
      _paint..color = n > 0.35 ? CityPalette.night.lampBulb : CityPalette.day.lampBulb,
    );
    if (n > 0.1) {
      final r = Rect.fromCenter(center: p0, width: 64 * _k, height: 32 * _k);
      _paint.shader = ui.Gradient.radial(p0, 32 * _k, [
        CityPalette.lampGlow.withValues(alpha: 0.45 * n),
        CityPalette.lampGlow.withValues(alpha: 0),
      ]);
      _c.drawOval(r, _paint);
      _paint.shader = null;
    }
  }

  // ---------------------------------------------------------------- vehículos y peatones
  void _truck(Vehicle v, double n, double t) {
    final l = CityPalette.liveries[v.livery];
    final p = v.pos;
    final alongX = p.dx.abs() >= p.dy.abs();
    final dir = alongX ? (p.dx == 0 ? 1.0 : p.dx.sign) : (p.dy == 0 ? 1.0 : p.dy.sign);
    final bump = math.sin(t * 9 + v.i).abs() * 0.02;
    _groundShadow(p.x, p.y, 0.65, 0.36, 0.28);
    final cab = dir > 0 ? 0.28 : -0.52, box = dir > 0 ? -0.45 : -0.15;
    if (alongX) {
      _box(p.x + box, p.y - 0.24, 0.06 + bump, 0.68, 0.48, 0.48, l.cargo);
      _box(p.x + cab, p.y - 0.22, 0.06 + bump, 0.32, 0.44, 0.36, l.cab);
    } else {
      _box(p.x - 0.24, p.y + box, 0.06 + bump, 0.48, 0.68, 0.48, l.cargo);
      _box(p.x - 0.22, p.y + cab, 0.06 + bump, 0.44, 0.32, 0.36, l.cab);
    }
    if (n > 0.2) {
      final f = _iso(p.x + (alongX ? dir * 0.45 : 0), p.y + (alongX ? 0 : dir * 0.45), 0.22);
      final ang = math.atan2((p.dx + p.dy) * _th, (p.dx - p.dy) * _tw);
      _paint.shader = ui.Gradient.radial(f, 60 * _k, [
        CityPalette.headlight.withValues(alpha: 0.7 * n),
        CityPalette.headlight.withValues(alpha: 0),
      ]);
      _path
        ..reset()
        ..moveTo(f.dx, f.dy)
        ..arcTo(Rect.fromCircle(center: f, radius: 60 * _k), ang - 0.35, 0.7, false)
        ..close();
      _c.drawPath(_path, _paint);
      _paint.shader = null;
    }
  }

  void _person(double x, double y, Color col, double t) {
    final step = math.sin(t * 10).abs() * 0.04;
    final p = _iso(x, y), h = _iso(x, y, 0.62 + step);
    _c.drawOval(
      Rect.fromCenter(center: p, width: 8 * _k, height: 4 * _k),
      _paint..color = CityPalette.shadow.withValues(alpha: 0.2),
    );
    _line(p.translate(0, -2 * _k), h.translate(0, 4 * _k), _p.personBody ?? col, math.max(2, 4 * _k));
    _c.drawCircle(h, math.max(1.8, 2.6 * _k), _paint..color = _p.personHead);
  }

  // ---------------------------------------------------------------- pasada 1: suelo
  void _drawGround(Size size, double n, double t) {
    final dpr = ui.PlatformDispatcher.instance.implicitView?.devicePixelRatio ?? 1;
    final scale = dpr.clamp(1.0, 2.0);
    final key = (size, n > 0.5, scale);
    if (_groundKey != key || _ground == null) {
      _ground?.dispose();
      final rec = ui.PictureRecorder();
      final real = _c;
      _c = Canvas(rec)..scale(scale);
      _groundStatic();
      _c = real;
      final pic = rec.endRecording();
      _ground = pic.toImageSync((size.width * scale).ceil(), (size.height * scale).ceil());
      pic.dispose();
      _groundKey = key;
    }
    _c.drawImageRect(
      _ground!,
      Rect.fromLTWH(0, 0, _ground!.width.toDouble(), _ground!.height.toDouble()),
      Rect.fromLTWH(0, 0, _ground!.width / scale, _ground!.height / scale),
      _imagePaint,
    );
    _groundLive(n, t);
  }

  void _groundStatic() {
    final p = _p;
    _box(-13.5, -12.5, -0.65, 27, 25, 0.65, CityBox(p.grass, p.soilLeft, p.soilRight));
    final q = [_iso(-13.5, -12.5), _iso(13.5, -12.5), _iso(13.5, 12.5), _iso(-13.5, 12.5)];
    _c
      ..save()
      ..clipPath(Path()..addPolygon(q, true));
    for (final m in scene.meadow) {
      final c = _iso(m.x, m.y), rx = m.rx * _tw * _k, ry = m.ry * _th * _k;
      final col = m.tone > 0.5 ? p.meadowLight : p.meadowDark;
      _paint.shader = ui.Gradient.radial(c, math.max(rx, ry), [col, col.withValues(alpha: 0)]);
      _c.drawOval(Rect.fromCenter(center: c, width: rx * 2, height: ry * 2), _paint);
    }
    _paint.shader = null;
    _c.restore();
    _stroke
      ..color = p.path
      ..strokeWidth = 0.42 * _tw * _k
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final path in cityPaths) {
      _path.reset();
      for (final (i, (x, y)) in path.indexed) {
        final o = _iso(x, y, 0.01);
        i == 0 ? _path.moveTo(o.dx, o.dy) : _path.lineTo(o.dx, o.dy);
      }
      _c.drawPath(_path, _stroke);
    }
    void band(double half, double z, Color fill) {
      final top = <Offset>[], bot = <Offset>[];
      for (var i = 0; i <= 54; i++) {
        final u = -13.5 + (i / 54) * 27, y = riverY(u);
        top.add(_iso(u, y - half, z));
        bot.add(_iso(u, y + half, z));
      }
      _poly([...top, ...bot.reversed], fill);
    }

    band(1.55, 0.02, p.sand);
    band(1.25, -0.06, p.water);
    band(0.55, -0.05, p.waterChannel);
    for (final (x1, y1, x2, y2) in cityRoads) {
      final a = _iso(x1, y1, 0.015), b = _iso(x2, y2, 0.015);
      _line(a, b, p.roadEdge, 1.4 * _tw * _k);
      _line(a, b, p.road, 1.05 * _tw * _k);
      // Línea discontinua de 8 y 8 (escaladas).
      final len = (b - a).distance, dash = 8 * _k;
      if (len > 0) {
        final dir = (b - a) / len;
        for (var d = 0.0; d < len; d += dash * 2) {
          _line(a + dir * d, a + dir * math.min(len, d + dash), p.roadLine, math.max(1, 1.8 * _k), cap: StrokeCap.butt);
        }
      }
    }
    _box(-2.65, 3.8, 0, 1.3, 2.8, 0.26, p.bridge);
    _box(-8.8, -8.5, 0, 4.6, 4.4, 0.14, p.plazaOrg);
    _box(5.2, -8.2, 0, 5.2, 5.2, 0.16, p.plazaHub);
    _box(-2.4, -2.4, 0, 4.8, 4.8, 0.12, p.plazaHome);
    _box(-1.5, -1.5, 0.12, 3, 3, 0.03, p.plazaHomeInner);
    _box(4.5, -0.2, 0, 3.6, 3.6, 0.14, p.plazaVilla);
    _box(-10.2, 5.8, 0, 6, 4.8, 0.15, p.plazaSchool);
    _flat(-6.2, 6.4, 1.7, 2.4, 0.17, CityPalette.court, CityPalette.courtLine);
    _box(0.8, 6.5, 0, 4.8, 3.6, 0.14, p.plazaRiver);
    _box(1.8, 5.2, 0.05, 1.6, 1.5, 0.12, CityPalette.deck);
    for (final f in scene.flowers) {
      final o = _iso(f.x, f.y, 0.02), r = math.max(1.4, 2.2 * _k * f.s);
      _c.drawCircle(o.translate(0, -3 * _k), r, _paint..color = CityPalette.flowers[f.tone]);
    }
  }

  void _groundLive(double n, double t) {
    final p = _p, k = _k;
    for (var j = 0; j < 14; j++) {
      final u = cityMod(t * 1.1 + j * 2.1, 28) - 14, lane = (((j * 7) % 5) - 2) * 0.35;
      if (u > -3.2 && u < -1.0) continue; // no pasar por encima del puente
      final a = _iso(u, riverY(u) + lane, -0.04), b = _iso(u + 0.9, riverY(u + 0.9) + lane, -0.04);
      final alpha = (math.sin(t * 2 + j) * 0.5 + 0.5) * 0.6 + 0.2;
      _line(a, b, p.stream.withValues(alpha: p.stream.a * alpha), math.max(1, 1.6 * k));
    }
    final night = n > 0.5;
    double gustAt(double x, double y) {
      final d = cityMod((x + y) - t * 3.2, 30) - 15;
      return math.exp((-d * d) / 6);
    }

    final tufts = [
      for (final g in scene.tufts)
        if (_visible(g.x, g.y, 20)) (g: g, s: _iso(g.x, g.y, 0.01), gust: night ? 0.0 : gustAt(g.x, g.y)),
    ];
    (double, double, double, double) tip(({Tuft g, Offset s, double gust}) u, int side) {
      final kk = k * u.g.s, hgt = (side == 0 ? 13 : 9) * kk;
      final wind = (math.sin(t * 2.4 + u.g.x * 2.1 + u.g.y * 1.7 + u.g.p) * 4 + u.gust * 9) * kk;
      return (
        u.s.dx + side * 6 * k + wind,
        u.s.dy - hgt * (1 - u.gust * 0.25),
        u.s.dx + side * 4 * k,
        u.s.dy - hgt * 0.6,
      );
    }

    _stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(1, 1.4 * k);
    for (final (col, side) in [(p.tuftBlades[0], -1), (p.tuftBlades[1], 0), (p.tuftBlades[2], 1)]) {
      _path.reset();
      for (final u in tufts) {
        final (tx, ty, cx, cy) = tip(u, side);
        _path
          ..moveTo(u.s.dx + side * 3 * k, u.s.dy)
          ..quadraticBezierTo(cx, cy, tx, ty);
      }
      _c.drawPath(_path, _stroke..color = col);
    }
    if (!night) {
      _path.reset();
      for (final u in tufts) {
        if (u.gust > 0.35) {
          final (tx, ty, _, _) = tip(u, 0);
          _path
            ..moveTo(tx, ty)
            ..lineTo(tx - 2 * k, ty + 4 * k * u.gust);
        }
      }
      _c.drawPath(
        _path,
        _stroke
          ..color = CityPalette.tuftGlint
          ..strokeWidth = math.max(1, 1.5 * k),
      );
    }
  }

  // ---------------------------------------------------------------- pasada 2: objetos por profundidad
  List<(double, VoidCallback)> _sceneObjects(double n, double t) {
    final o = <(double, VoidCallback)>[];
    final p = _p, k = _k;
    void add(double x, double y, VoidCallback fn, [double margin = 140]) {
      if (_visible(x, y, margin)) o.add((x + y, fn));
    }

    void tree(TreeType type, double x, double y, double s, [double ph = 0]) =>
        add(x, y, () => _tree(type, x, y, s, t + ph));

    // Sede de las organizaciones
    add(-6.9, -6.7, () {
      _groundShadow(-6.9, -6.7, 2, 1, 0.22);
      _box(-8.2, -7.8, 0.14, 2.6, 2.2, 1.05, p.orgBase);
      _box(-7.8, -7.4, 1.19, 1.8, 1.4, 0.65, p.orgTop);
      _windows(true, -8.0, -5.6, 0.35, 2.2, 2, 4, 0.28, 0.28, n, t);
    }, 200);
    for (final (idx, (wx, wy, wh)) in const [(-8.3, -4.8, 3.2), (-5.0, -7.8, 2.7)].indexed) {
      add(wx, wy, () {
        final b = _iso(wx, wy, 0.14), top = _iso(wx, wy, wh);
        _line(b, top, p.mill, 3.2 * k);
        for (var bl = 0; bl < 3; bl++) {
          final a = t * 2.4 + idx * 1.2 + bl * 2.094;
          _line(top, top.translate(math.cos(a) * 21 * k, math.sin(a) * 18 * k), CityPalette.millBlade, 2.2 * k);
        }
        _c.drawCircle(top, 3.5 * k, _paint..color = CityPalette.millHub);
      }, 200);
    }
    tree(TreeType.shade, -9.5, -6.5, 1.1);
    tree(TreeType.jacaranda, -5.2, -5.2, 1.05, 1);
    add(-7.0, -4.5, () => _bush(-7.0, -4.5, 0.55));

    // Centro de trazabilidad
    add(7.4, -6.2, () {
      _groundShadow(7.4, -6.2, 2, 1.1, 0.22);
      _box(5.8, -7.6, 0.16, 3.2, 2.8, 1.35, p.hubBase);
      _box(6.1, -7.2, 1.51, 0.7, 2, 0.28, CityPalette.hubPanel);
      _box(7.2, -7.2, 1.51, 0.7, 2, 0.28, CityPalette.hubPanel);
      _windows(true, 6.0, -4.8, 0.4, 2.8, 2, 5, 0.26, 0.28, n, t);
    }, 200);
    add(6.6, -4.4, () {
      _box(6.2, -4.8, 0.16, 0.8, 0.08, 0.75, CityPalette.crateGate);
      _box(7.4, -4.8, 0.16, 0.8, 0.08, 0.75, CityPalette.crateGate);
      _box(5.6, -4.3, 0.16, 0.65, 0.65, 0.52, CityPalette.crate1);
      _box(6.4, -4.2, 0.16, 0.55, 0.55, 0.42, CityPalette.crate2);
      _box(5.7, -4.2, 0.68, 0.45, 0.45, 0.35, CityPalette.crate3);
    });
    add(9.5, -6.8, () {
      // torre de anclaje: el bloque sube y baja y emite ondas
      _box(9.1, -7.2, 0.16, 0.8, 0.8, 1.9, CityPalette.tower);
      final fz = 2.45 + math.sin(t * 3) * 0.18;
      _box(9.2, -7.1, fz, 0.6, 0.6, 0.55, CityPalette.towerBlock);
      final b = _iso(9.5, -6.8, fz + 0.3);
      for (var r = 0; r < 2; r++) {
        final ph = cityMod(t * 0.7 + r * 0.5, 1), rad = (6 + ph * 30) * k;
        _c.drawCircle(
          b,
          rad,
          _stroke
            ..color = CityPalette.wave.withValues(alpha: 1 - ph)
            ..strokeWidth = 2 * k,
        );
      }
    }, 200);
    tree(TreeType.palm, 10.2, -5.5, 1.1);
    tree(TreeType.guayacan, 4.6, -6.8, 1.0, 1.5);

    // Plaza fundacional
    add(0, -1.6, () {
      _groundShadow(0, -1.6, 2.4, 1.1, 0.22);
      _box(-1.8, -2.3, 0.15, 3.6, 1.5, 1.45, p.hall);
      _windows(true, -1.6, -0.8, 0.35, 3.2, 2, 5, 0.28, 0.32, n, t);
      _hipRoof(-1.95, -2.45, 1.6, 3.9, 1.8, 0.55, 0.35, CityPalette.hallRoof);
      _box(-0.55, -2.1, 1.6, 1.1, 1.1, 1.15, p.hallTower);
      final c = _iso(0, -1.0, 2.2);
      final face = Rect.fromCenter(center: c, width: 10 * k, height: 12 * k);
      _c
        ..drawOval(face, _paint..color = CityPalette.clockFace)
        ..drawOval(
          face,
          _stroke
            ..color = CityPalette.clockHands
            ..strokeWidth = 1.2 * k,
        );
      _line(c, c.translate(math.cos(t * 0.5) * 4 * k, math.sin(t * 0.5) * 4 * k), CityPalette.clockHands, 1.2 * k);
      _hipRoof(-0.68, -2.22, 2.75, 1.36, 1.36, 0.5, 0.25, CityPalette.hallTowerRoof);
    }, 220);
    add(0, 0.3, () {
      // fuente con chorro y gotas
      _box(-0.75, -0.35, 0.15, 1.5, 1.5, 0.28, CityPalette.fountain);
      _box(-0.4, 0, 0.43, 0.8, 0.8, 0.25, CityPalette.fountainInner);
      final f = _iso(0, 0.4, 0.72), jh = (12 + math.sin(t * 5) * 4) * k;
      _line(f, f.translate(0, -jh), CityPalette.jet, 2.5 * k);
      _paint.color = CityPalette.drops;
      for (var d = 0; d < 6; d++) {
        final ph = cityMod(t * 1.2 + d / 6, 1), a = d * 1.05;
        _c.drawCircle(f.translate(math.cos(a) * ph * 12 * k, -jh + ph * ph * (jh + 6 * k)), 1.4 * k, _paint);
      }
    });
    tree(TreeType.palm, -2.0, 1.8, 1.05);
    tree(TreeType.palm, 2.0, 1.8, 1.1, 1.2);
    tree(TreeType.guayacan, -2.0, -0.4, 1.0);
    tree(TreeType.shade, 2.0, -0.4, 1.0, 2);
    add(-1.3, 1.5, () => _lamp(-1.3, 1.5, n));
    add(1.3, 1.5, () => _lamp(1.3, 1.5, n));

    // Barrio residencial
    add(6.2, 1.2, () {
      _groundShadow(6.2, 1.2, 1.6, 0.8, 0.2);
      _box(5.1, 0.3, 0.14, 2.2, 1.8, 1.05, p.house);
      _windows(true, 5.2, 2.1, 0.32, 1.8, 2, 3, 0.26, 0.28, n, t);
      _hipRoof(4.95, 0.15, 1.19, 2.5, 2.1, 0.48, 0.25, CityPalette.houseRoof);
      final s = _iso(6.6, 0.8, 1.75);
      for (var q = 0; q < 4; q++) {
        final ph = cityMod(t * 0.35 + q / 4, 1);
        _c.drawCircle(
          s.translate(ph * 10 * k, -ph * 26 * k),
          (2 + ph * 5) * k,
          _paint..color = CityPalette.smoke.withValues(alpha: (1 - ph) * 0.5),
        );
      }
    }, 200);
    tree(TreeType.jacaranda, 7.5, 2.2, 1.0, 1);
    tree(TreeType.shade, 4.2, -1.2, 0.95, 0.5);
    add(4.9, 2.5, () => _lamp(4.9, 2.5, n));

    // Barrio de las escuelas
    add(-8.1, 7.3, () {
      _groundShadow(-8.1, 7.3, 1.8, 0.9, 0.22);
      _box(-9.6, 6.3, 0.15, 3, 2, 1.15, p.school);
      _box(-9.3, 6.6, 1.31, 1.1, 1.4, 0.06, CityPalette.schoolPanel);
      _box(-7.9, 6.6, 1.31, 1.1, 1.4, 0.06, CityPalette.schoolPanel);
      _windows(true, -9.4, 8.3, 0.32, 2.6, 2, 4, 0.3, 0.3, n, t);
    }, 200);
    add(-5.3, 7.6, () {
      final bz = 0.2 + math.sin(t * 3).abs() * 0.9, bx = -5.3 + math.sin(t * 0.8) * 0.5;
      _groundShadow(bx, 7.6, 0.14, 0.08, 0.3);
      _c.drawCircle(_iso(bx, 7.6, bz), 3.2 * k, _paint..color = CityPalette.ball);
    });
    add(-9.5, 9.5, () {
      _line(_iso(-9.5, 9.5, 0.15), _iso(-9.5, 9.5, 1.95), CityPalette.mast, 3 * k);
      _box(-9.9, 9.1, 1.95, 0.85, 0.85, 0.75, CityPalette.tank);
    });
    tree(TreeType.guayacan, -4.8, 9.8, 1.1, 0.5);
    tree(TreeType.shade, -10.5, 5.5, 1.0, 1.2);
    tree(TreeType.palm, -7.0, 5.4, 1.0);
    add(-6.5, 9.2, () => _bush(-6.5, 9.2, 0.45, CityPalette.bushAlt));

    // Ronda del río
    add(2.7, 7.9, () {
      _groundShadow(2.7, 7.9, 1.6, 0.8, 0.2);
      _box(1.5, 7.0, 0.14, 2.4, 1.8, 0.95, p.riverHouse);
      _windows(true, 1.7, 8.8, 0.3, 2.0, 1, 4, 0.3, 0.34, n, t);
      _hipRoof(1.35, 6.85, 1.09, 2.7, 2.1, 0.45, 0.25, CityPalette.riverHouseRoof);
    }, 200);
    tree(TreeType.palm, 4.5, 7.4, 1.15, 2.1);
    tree(TreeType.shade, 4.3, 9.1, 1.05, 1.4);
    tree(TreeType.guayacan, 0.5, 8.2, 0.95, 0.8);
    add(1.3, 6.8, () => _lamp(1.3, 6.8, n));
    add(3.8, 6.8, () => _lamp(3.8, 6.8, n));

    for (final w in scene.wildTrees) {
      add(w.x, w.y, () => _tree(w.type, w.x, w.y, w.s, t + w.p));
    }

    // Lanchas en el río
    for (final (u, dir) in [(-11 + cityMod(t * 1.05, 22), 1.0), (11 - cityMod(t * 0.8 + 6, 22), -1.0)]) {
      add(u, riverY(u), () {
        final ry = riverY(u), bob = math.sin(t * 2.5 + u) * 0.03, b = _iso(u, ry, -0.02 + bob);
        _line(
          b.translate(-dir * 20 * k, -dir * 10 * k + 3 * k),
          b.translate(0, 3 * k),
          CityPalette.boatWake,
          1.8 * k,
          cap: StrokeCap.butt,
        );
        _box(u - 0.45, ry - 0.25, -0.04 + bob, 0.9, 0.5, 0.2, CityPalette.boatHull);
        _box(u - 0.2, ry - 0.15, 0.16 + bob, 0.4, 0.3, 0.22, CityPalette.boatCabin);
      });
    }
    for (final v in scene.vehicles) {
      final pos = v.pos;
      add(pos.x, pos.y, () => _truck(v, n, t));
    }
    for (final person in scene.people) {
      final (x, y) = ringPoint(person.off + person.dir * t * person.speed);
      add(x, y, () => _person(x, y, CityPalette.people[person.tone], t + person.off * 9));
    }
    return o;
  }

  // ---------------------------------------------------------------- pasada 3: aire
  void _drawAir(double n, double t) {
    final p = _p, k = _k;
    _stroke
      ..strokeWidth = math.max(1.4, 2 * k)
      ..strokeCap = StrokeCap.round
      ..color = p.bird;
    for (var f = 0; f < 2; f++) {
      // dos bandadas en V
      final lead = cityMod(t * (2 + f * 0.6) + f * 17, 40) - 20;
      for (var b = 0; b < 5; b++) {
        final side = b == 0 ? 0 : (b.isOdd ? -1 : 1) * (b / 2).ceil();
        final bx = lead - side.abs() * 0.9, by = -6 + f * 9 + side * 0.7 + math.sin(t * 0.8 + b) * 0.25;
        final q = _iso(bx, by, 4.6 + f * 0.8), flap = math.sin(t * 13 + b * 1.6) * 5 * k;
        if (q.dx < -20 || q.dx > _w + 20 || q.dy < -20 || q.dy > _h + 20) continue;
        _path
          ..reset()
          ..moveTo(q.dx - 6 * k, q.dy - flap)
          ..quadraticBezierTo(q.dx - k, q.dy, q.dx, q.dy + 2 * k)
          ..quadraticBezierTo(q.dx + k, q.dy, q.dx + 6 * k, q.dy - flap);
        _c.drawPath(_path, _stroke);
      }
    }
    if (n <= 0.5) {
      final fl = scene.flowers;
      for (var i = 0; i < 10 && fl.isNotEmpty; i++) {
        // mariposas sobre las flores
        final f = fl[(i * 23) % fl.length];
        final x = f.x + math.sin(t * 0.7 + i) * 0.8, y = f.y + math.cos(t * 0.5 + i * 2) * 0.6;
        if (!_visible(x, y, 20)) continue;
        final q = _iso(x, y, 0.5 + math.sin(t * 2 + i) * 0.25), w = math.sin(t * 16 + i).abs() * 4 * k + k;
        _paint.color = CityPalette.butterflies[i % 4];
        for (final (dx, rot) in [(-w * 0.6, -0.4), (w * 0.6, 0.4)]) {
          _c
            ..save()
            ..translate(q.dx + dx, q.dy)
            ..rotate(rot)
            ..drawOval(Rect.fromCenter(center: Offset.zero, width: w * 2, height: 6 * k), _paint)
            ..restore();
        }
      }
      for (var i = 0; i < 18; i++) {
        // hojas y pétalos llevados por la brisa
        final x = cityMod(i * 3.4 + t * 1.5, 28) - 14, y = cityMod(i * 2.8 - t * 0.75, 24) - 12;
        if (!_visible(x, y, 20)) continue;
        final q = _iso(x, y, 0.5 + math.sin(t * 2.2 + i * 1.8) * 0.3 + (i % 3) * 0.4);
        _c
          ..save()
          ..translate(q.dx, q.dy)
          ..rotate(t * 2 + i)
          ..drawOval(
            Rect.fromCenter(center: Offset.zero, width: 7 * k, height: 3.6 * k),
            _paint..color = CityPalette.leaves[i % 3],
          )
          ..restore();
      }
    } else {
      for (var f = 0; f < 34; f++) {
        // luciérnagas: un halo y un punto (sin degradado por cada una, que es caro en cada fotograma)
        final x = cityMod(f * 1.7 + t * 0.2, 24) - 12, y = cityMod(f * 2.3 - t * 0.15, 22) - 11;
        if (!_visible(x, y, 20)) continue;
        final q = _iso(x, y, 0.3 + math.sin(t * 3 + f * 1.5) * 0.4);
        final glow = (math.sin(t * 4 + f * 2) * 0.5 + 0.5) * n;
        _c
          ..drawCircle(q, 8 * k, _paint..color = CityPalette.firefly.withValues(alpha: glow * 0.25))
          ..drawCircle(q, 2.4 * k, _paint..color = CityPalette.firefly.withValues(alpha: glow * 0.9));
      }
    }
    for (final c in scene.clouds) {
      _groundShadow(c.x, c.y, c.s * 0.8, c.s * 0.45, p.cloudShadow);
      final q = _iso(c.x, c.y, c.z), r = c.s * 15 * k;
      _paint.color = p.cloud;
      _path
        ..reset()
        ..addOval(Rect.fromCircle(center: q, radius: r))
        ..addOval(Rect.fromCircle(center: q.translate(r * 0.75, -r * 0.2), radius: r * 0.75))
        ..addOval(Rect.fromCircle(center: q.translate(-r * 0.65, -r * 0.1), radius: r * 0.7))
        ..addOval(Rect.fromCircle(center: q.translate(r * 0.3, -r * 0.55), radius: r * 0.65));
      _c.drawPath(_path, _paint);
    }
    _tag(0, -1.5, 3.5, district.name, true, t);
  }

  /// Etiqueta del lugar de la cámara («Plaza central»), flotando. El texto se maqueta una sola vez.
  void _tag(double x, double y, double z, String text, bool on, double t) {
    final q = _iso(x, y, z + (on ? math.sin(t * 2.4) * 0.08 : 0));
    final tp = _tags.putIfAbsent(
      text,
      () => TextPainter(
        text: TextSpan(
          text: text,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            fontFamily: 'monospace',
            color: CityPalette.tagTextDark,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(),
    );
    final r = RRect.fromRectAndRadius(
      Rect.fromCenter(center: q, width: tp.width + 22, height: 22),
      const Radius.circular(11),
    );
    _c
      ..drawRRect(r, _paint..color = on ? CityPalette.tagYellow : CityPalette.tagDarkBg)
      ..drawRRect(
        r,
        _stroke
          ..color = on ? CityPalette.tagTextLight : CityPalette.tagBorder
          ..strokeWidth = 1,
      );
    tp.paint(_c, q - Offset(tp.width / 2, tp.height / 2 - 1));
  }

  @override
  void dispose() {
    _ground?.dispose();
    for (final tp in _tags.values) {
      tp.dispose();
    }
    super.dispose();
  }
}
