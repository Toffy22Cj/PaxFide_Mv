import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../shared/theme/pax_tokens.dart';

/// Escenas ilustradas de la bienvenida: el mundo isométrico del landing (terreno, caminos, árboles, cajas, camión,
/// bodega, cubos de la cadena y centro comunitario), dibujado con `CustomPaint` y **solo con la paleta** (tokens con o
/// sin transparencia). Sin imágenes ni dependencias.
enum WelcomeScene { donate, warehouse, route, seal, delivery, overview }

/// Momento del día de una escena: el landing pasa de día a noche a lo largo del recorrido.
enum DayTime { day, dusk, night }

/// Colores de la escena según el momento del día, todos derivados de la paleta.
class ScenePalette {
  ScenePalette._(this.time);
  final DayTime time;

  factory ScenePalette.of(DayTime t) => ScenePalette._(t);

  bool get dark => time == DayTime.night;
  static Color _mix(Color top, double a, Color base) => Color.alphaBlend(top.withValues(alpha: a), base);

  Color get terrain => switch (time) {
    DayTime.day => _mix(PaxTokens.brandGreen500, 0.72, PaxTokens.white),
    DayTime.dusk => _mix(PaxTokens.brandGreen800, 0.80, PaxTokens.brandYellow400),
    DayTime.night => _mix(PaxTokens.brandGreen900, 0.55, PaxDarkTokens.background),
  };
  Color get hill => switch (time) {
    DayTime.day => _mix(PaxTokens.brandGreen500, 0.9, PaxTokens.white),
    DayTime.dusk => _mix(PaxTokens.brandGreen900, 0.75, PaxTokens.brandYellow400),
    DayTime.night => _mix(PaxTokens.brandGreen900, 0.35, PaxDarkTokens.background),
  };
  Color get field => switch (time) {
    DayTime.day => _mix(PaxTokens.brandGreen50, 0.35, terrain),
    _ => _mix(PaxTokens.brandGreen800, 0.35, terrain),
  };
  Color get tree => dark ? _mix(PaxTokens.brandGreen800, 0.75, PaxDarkTokens.background) : PaxTokens.brandGreen800;
  Color get treeLight => dark ? _mix(PaxTokens.brandGreen500, 0.45, PaxDarkTokens.background) : PaxTokens.brandGreen500;
  Color get trunk => dark ? _mix(PaxTokens.brandYellow900, 0.6, PaxDarkTokens.background) : PaxTokens.brandYellow900;
  Color get shadow => (dark ? PaxDarkTokens.background : PaxTokens.brandGreen900).withValues(alpha: dark ? 0.45 : 0.16);
  Color get road => dark
      ? _mix(PaxTokens.brandNeutral700, 0.55, PaxDarkTokens.background)
      : _mix(PaxTokens.brandNeutral700, 0.28, PaxTokens.white);
  Color get roadEdge => dark
      ? _mix(PaxTokens.brandNeutral700, 0.75, PaxDarkTokens.background)
      : _mix(PaxTokens.brandNeutral700, 0.45, PaxTokens.white);
  Color get dash => PaxTokens.brandYellow400.withValues(alpha: dark ? 0.7 : 1);
  Color get water => dark ? PaxTokens.brandBlue800 : PaxTokens.brandBlue500;
  Color get box => PaxTokens.brandYellow400;
  Color get boxSide => _mix(PaxTokens.brandYellow900, 0.35, PaxTokens.brandYellow400);
  Color get boxDark => _mix(PaxTokens.brandYellow900, 0.6, PaxTokens.brandYellow400);
  Color get cube => PaxTokens.brandBlue500;
  Color get cubeTop => _mix(PaxTokens.white, 0.35, PaxTokens.brandBlue500);
  Color get cubeSide => PaxTokens.brandBlue800;
  Color get slab => dark ? _mix(PaxTokens.white, 0.85, PaxDarkTokens.background) : PaxTokens.white;
  Color get slabSide => dark
      ? _mix(PaxTokens.brandNeutral700, 0.4, PaxTokens.white)
      : _mix(PaxTokens.brandNeutral700, 0.18, PaxTokens.white);
  Color get truck => PaxTokens.brandGreen800;
  Color get truckSide => PaxTokens.brandGreen900;
  Color get roof => PaxTokens.danger700;
  Color get roofGreen => PaxTokens.brandGreen800;
  Color get wall => dark ? _mix(PaxTokens.white, 0.8, PaxDarkTokens.background) : PaxTokens.white;
  Color get wallSide => _mix(PaxTokens.brandNeutral700, 0.22, PaxTokens.white);
  Color get sun => PaxTokens.brandYellow400;
  Color get moon => PaxTokens.brandYellow50;
  Color get star => PaxTokens.white.withValues(alpha: 0.7);
  Color get cloud => PaxTokens.white;
  Color get labelBg => dark ? PaxTokens.brandGreen900 : PaxTokens.white;
  Color get labelFg => dark ? PaxTokens.brandGreen50 : PaxTokens.brandGreen900;
  Color get chipBg => PaxTokens.brandGreen900;
  Color get chipFg => PaxTokens.brandYellow400;
  Color get check => PaxTokens.brandGreen800;
}

/// Una escena del recorrido. [height] fija el alto del dibujo; el resto del área (detrás de la tarjeta) es terreno.
class WelcomeSceneView extends StatelessWidget {
  const WelcomeSceneView({super.key, required this.scene, required this.time, this.from});
  final WelcomeScene scene;
  final DayTime time;

  /// Momento del día de la escena anterior: el borde de arriba se funde con ella.
  final DayTime? from;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      painter: _ScenePainter(scene, ScenePalette.of(time), from == null ? null : ScenePalette.of(from!)),
    ),
  );
}

class _ScenePainter extends CustomPainter {
  _ScenePainter(this.scene, this.p, this.from);
  final WelcomeScene scene;
  final ScenePalette p;
  final ScenePalette? from;

  /// Unidad isométrica (px) según el ancho.
  late double u;

  /// Punto isométrico → pantalla, con origen [o].
  Offset iso(Offset o, double x, double y, [double z = 0]) =>
      o + Offset((x - y) * math.cos(math.pi / 6) * u, (x + y) * math.sin(math.pi / 6) * u - z * u);

  @override
  void paint(Canvas canvas, Size size) {
    u = (size.width / 22).clamp(12.0, 26.0);
    canvas.drawRect(Offset.zero & size, Paint()..color = p.terrain);
    final prev = from;
    if (prev != null && prev.time != p.time) {
      final r = Rect.fromLTWH(0, 0, size.width, 80);
      canvas.drawRect(
        r,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [prev.terrain, p.terrain],
          ).createShader(r),
      );
    }
    _hills(canvas, size);
    _sky(canvas, size);
    switch (scene) {
      case WelcomeScene.donate:
        _donate(canvas, size);
      case WelcomeScene.warehouse:
        _warehouse(canvas, size);
      case WelcomeScene.route:
        _route(canvas, size);
      case WelcomeScene.seal:
        _seal(canvas, size);
      case WelcomeScene.delivery:
        _delivery(canvas, size);
      case WelcomeScene.overview:
        _overview(canvas, size);
    }
    _trees(canvas, size);
  }

  // --- fondo ---------------------------------------------------------------------------------------------------

  void _hills(Canvas c, Size s) {
    final paint = Paint()..color = p.hill;
    c.drawOval(
      Rect.fromCenter(center: Offset(s.width * 0.15, s.height * 0.32), width: s.width * 0.9, height: 220),
      paint,
    );
    c.drawOval(
      Rect.fromCenter(center: Offset(s.width * 0.95, s.height * 0.75), width: s.width * 0.7, height: 260),
      paint,
    );
  }

  void _sky(Canvas c, Size s) {
    if (p.dark) {
      final rnd = math.Random(scene.index + 7);
      final star = Paint()..color = p.star;
      for (var i = 0; i < 26; i++) {
        c.drawCircle(
          Offset(rnd.nextDouble() * s.width, rnd.nextDouble() * s.height),
          rnd.nextDouble() * 1.6 + 0.6,
          star,
        );
      }
      final moonC = Offset(s.width * 0.82, 70);
      c.drawCircle(moonC, 34, Paint()..color = p.moon.withValues(alpha: 0.12));
      c.drawCircle(moonC, 22, Paint()..color = p.moon);
      c.drawCircle(moonC + const Offset(9, -5), 19, Paint()..color = p.terrain);
    } else {
      final sunC = Offset(s.width * 0.82, 70);
      final ray = Paint()
        ..color = p.sun
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 10; i++) {
        final a = i * math.pi / 5;
        c.drawLine(sunC + Offset(math.cos(a), math.sin(a)) * 28, sunC + Offset(math.cos(a), math.sin(a)) * 38, ray);
      }
      c.drawCircle(sunC, 21, Paint()..color = p.sun);
      if (p.time == DayTime.day) {
        _cloud(c, Offset(s.width * 0.18, 60), 1);
        _cloud(c, Offset(s.width * 0.6, 150), 0.7);
      }
    }
  }

  void _cloud(Canvas c, Offset o, double k) {
    final paint = Paint()..color = p.cloud.withValues(alpha: 0.92);
    for (final (dx, dy, r) in [(-30.0, 6.0, 18.0), (-8.0, -6.0, 24.0), (20.0, 2.0, 20.0), (40.0, 8.0, 14.0)]) {
      c.drawCircle(o + Offset(dx * k, dy * k), r * k, paint);
    }
    c.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(o.dx - 46 * k, o.dy + 2 * k, 100 * k, 22 * k), Radius.circular(11 * k)),
      paint,
    );
  }

  void _trees(Canvas c, Size s) {
    final rnd = math.Random(scene.index * 31 + 3);
    for (var i = 0; i < 9; i++) {
      final x = rnd.nextDouble() * s.width;
      final y = s.height * (0.08 + rnd.nextDouble() * 0.9);
      // Lejos del centro del dibujo, para no tapar la escena.
      if ((x - s.width / 2).abs() < s.width * 0.28 && y < s.height * 0.5) continue;
      _tree(c, Offset(x, y), 0.7 + rnd.nextDouble() * 0.6);
    }
  }

  void _tree(Canvas c, Offset base, double k) {
    c.drawOval(
      Rect.fromCenter(center: base + Offset(0, 2 * k), width: 36 * k, height: 12 * k),
      Paint()..color = p.shadow,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(base.dx - 3 * k, base.dy - 26 * k, 6 * k, 26 * k), Radius.circular(3 * k)),
      Paint()..color = p.trunk,
    );
    c.drawCircle(base + Offset(0, -34 * k), 17 * k, Paint()..color = p.tree);
    c.drawCircle(base + Offset(-6 * k, -40 * k), 6 * k, Paint()..color = p.treeLight.withValues(alpha: 0.6));
  }

  // --- piezas isométricas ----------------------------------------------------------------------------------------

  /// Caja isométrica de [w]×[d]×[h] (unidades) con su esquina en (x, y, z).
  void _box(
    Canvas c,
    Offset o,
    double x,
    double y,
    double z,
    double w,
    double d,
    double h,
    Color top,
    Color left,
    Color right,
  ) {
    Path face(List<Offset> pts) => Path()..addPolygon(pts, true);
    final p000 = iso(o, x, y, z),
        p100 = iso(o, x + w, y, z),
        p010 = iso(o, x, y + d, z),
        p110 = iso(o, x + w, y + d, z);
    final p001 = iso(o, x, y, z + h), p101 = iso(o, x + w, y, z + h), p011 = iso(o, x, y + d, z + h);
    final p111 = iso(o, x + w, y + d, z + h);
    c.drawPath(face([p010, p110, p111, p011]), Paint()..color = left);
    c.drawPath(face([p100, p110, p111, p101]), Paint()..color = right);
    c.drawPath(face([p001, p101, p111, p011]), Paint()..color = top);
    // Contorno suave para que las piezas se lean sobre el terreno.
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = p.shadow;
    c.drawPath(face([p001, p101, p111, p011]), edge);
    c.drawLine(p000, p000, edge);
  }

  void _crate(Canvas c, Offset o, double x, double y, double z, [double k = 1]) {
    _box(c, o, x, y, z, 1.4 * k, 1.4 * k, 1.1 * k, p.box, p.boxSide, p.boxDark);
    // Cinta y corazón de la caja de donación.
    final tape = Paint()
      ..color = p.boxDark
      ..strokeWidth = 2;
    c.drawLine(iso(o, x + 0.7 * k, y, z + 1.1 * k), iso(o, x + 0.7 * k, y + 1.4 * k, z + 1.1 * k), tape);
  }

  void _slab(Canvas c, Offset o, double x, double y, double w, double d, [double h = 0.35]) =>
      _box(c, o, x, y, 0, w, d, h, p.slab, p.slabSide, p.wallSide);

  void _truck(Canvas c, Offset o, double x, double y) {
    _box(c, o, x, y, 0.2, 2.2, 1.3, 1.3, p.truck, p.truckSide, p.truckSide);
    _box(c, o, x + 2.2, y, 0.2, 0.9, 1.3, 1.0, p.truck, p.truckSide, p.truckSide);
    final wheel = Paint()..color = PaxTokens.brandNeutral700;
    for (final wx in [x + 0.5, x + 2.6]) {
      c.drawCircle(iso(o, wx, y + 1.3, 0.2), u * 0.28, wheel);
    }
    _crate(c, o, x + 0.4, y + 0.0, 1.5, 0.8);
  }

  void _roadBand(Canvas c, Size s, List<Offset> pts) {
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length - 1; i += 2) {
      path.quadraticBezierTo(pts[i].dx, pts[i].dy, pts[i + 1].dx, pts[i + 1].dy);
    }
    c.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = u * 2.6
        ..strokeCap = StrokeCap.round
        ..color = p.roadEdge,
    );
    c.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = u * 2.2
        ..strokeCap = StrokeCap.round
        ..color = p.road,
    );
    final dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = p.dash;
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 26) {
        c.drawPath(m.extractPath(d, d + 12), dash);
      }
    }
  }

  void _house(Canvas c, Offset o, double x, double y, {bool green = false}) {
    _box(c, o, x, y, 0, 2.6, 2.0, 1.5, p.wall, p.wallSide, p.wall);
    final roof = green ? p.roofGreen : p.roof;
    final a = iso(o, x, y, 1.5),
        b = iso(o, x + 2.6, y, 1.5),
        cc = iso(o, x + 2.6, y + 2, 1.5),
        d = iso(o, x, y + 2, 1.5);
    final ridgeL = iso(o, x, y + 1, 2.6), ridgeR = iso(o, x + 2.6, y + 1, 2.6);
    c.drawPath(Path()..addPolygon([a, b, ridgeR, ridgeL], true), Paint()..color = roof);
    c.drawPath(
      Path()..addPolygon([d, cc, ridgeR, ridgeL], true),
      Paint()..color = Color.alphaBlend(PaxTokens.brandGreen900.withValues(alpha: 0.25), roof),
    );
    final door = iso(o, x + 1.1, y + 2, 0);
    c.drawRect(
      Rect.fromLTWH(door.dx - u * 0.25, door.dy - u * 0.9, u * 0.5, u * 0.9),
      Paint()..color = PaxTokens.brandBlue700,
    );
  }

  void _label(Canvas c, Offset at, String text, {bool chip = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 11.5,
          letterSpacing: 0.3,
          color: chip ? p.chipFg : p.labelFg,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final r = RRect.fromRectAndRadius(
      Rect.fromCenter(center: at, width: tp.width + 20, height: tp.height + 10),
      const Radius.circular(99),
    );
    c.drawRRect(r.shift(const Offset(0, 2)), Paint()..color = p.shadow);
    c.drawRRect(r, Paint()..color = chip ? p.chipBg : p.labelBg);
    c.drawRRect(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = p.chipBg.withValues(alpha: 0.35),
    );
    tp.paint(c, at - Offset(tp.width / 2, tp.height / 2));
  }

  void _check(Canvas c, Offset at) {
    c.drawCircle(at, 13, Paint()..color = p.check);
    final path = Path()
      ..moveTo(at.dx - 6, at.dy)
      ..lineTo(at.dx - 1.5, at.dy + 5)
      ..lineTo(at.dx + 6.5, at.dy - 5);
    c.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round
        ..color = PaxTokens.white,
    );
  }

  // --- escenas -----------------------------------------------------------------------------------------------------

  void _donate(Canvas c, Size s) {
    final o = Offset(s.width * 0.42, s.height * 0.16);
    _roadBand(c, s, [
      Offset(-20, s.height * 0.42),
      Offset(s.width * 0.3, s.height * 0.5),
      Offset(s.width + 20, s.height * 0.36),
    ]);
    // Pasarela: una "pantalla" isométrica con el botón Donar.
    _box(c, o, 0, 0, 0, 3.4, 0.5, 3.0, p.truckSide, p.truckSide, PaxTokens.brandGreen900);
    _box(c, o, 0.2, 0.5, 0.3, 3.0, 0.05, 2.4, p.slab, p.slab, p.slab);
    _crate(c, o, 3.6, 1.6, 0);
    _label(c, iso(o, 0.4, 0, 4.4), 'Pasarela de pago');
    _label(c, iso(o, 1.7, 0.5, 2.0), 'Donar', chip: true);
    _house(c, Offset(s.width * 0.08, s.height * 0.62), 0, 0);
  }

  void _warehouse(Canvas c, Size s) {
    final o = Offset(s.width * 0.48, s.height * 0.08);
    _slab(c, o, 0, 0, 6, 5);
    for (var i = 0; i < 3; i++) {
      for (var j = 0; j < 2; j++) {
        _crate(c, o, 0.6 + i * 1.6, 0.8 + j * 1.6, 0.35);
      }
    }
    _crate(c, o, 1.4, 1.6, 1.45);
    _crate(c, o, 3.0, 1.6, 1.45);
    _label(c, iso(o, 2.5, 0, 3.6), 'Lote registrado · 1 QR');
    _label(c, iso(o, 6, 4, 0.2), 'Bodega');
    _truck(c, Offset(s.width * 0.1, s.height * 0.42), 0, 0);
  }

  void _route(Canvas c, Size s) {
    _roadBand(c, s, [
      Offset(s.width * 0.05, -10),
      Offset(s.width * 0.2, s.height * 0.35),
      Offset(s.width * 0.55, s.height * 0.42),
      Offset(s.width * 0.9, s.height * 0.5),
      Offset(s.width + 30, s.height * 0.75),
    ]);
    final o = Offset(s.width * 0.42, s.height * 0.12);
    _crate(c, o, 1.6, 0, 0.0);
    _crate(c, o, 3.2, 0.2, 0.0, 0.8);
    _label(c, iso(o, 2.2, 0, 2.6), 'Lote dividido');
    _truck(c, Offset(s.width * 0.18, s.height * 0.3), 0, 0);
    _label(c, Offset(s.width * 0.62, s.height * 0.62), 'Punto de control');
  }

  void _seal(Canvas c, Size s) {
    final o = Offset(s.width * 0.5, s.height * 0.05);
    _slab(c, Offset(s.width * 0.5, s.height * 0.3), 0, 0, 5, 4, 0.6);
    // Árbol de huellas: hojas → raíz dorada con candado.
    final link = Paint()
      ..color = p.cube
      ..strokeWidth = 2.5;
    final root = iso(o, 1.2, 0.8, 4.4);
    final mids = [iso(o, 0, 1.6, 2.6), iso(o, 2.6, 0.2, 2.6)];
    final leaves = [iso(o, -0.6, 2.6, 1.0), iso(o, 0.8, 2.2, 1.0), iso(o, 2.2, 1.0, 1.0), iso(o, 3.4, 0.0, 1.0)];
    for (final m in mids) {
      c.drawLine(root, m, link);
    }
    c.drawLine(mids[0], leaves[0], link);
    c.drawLine(mids[0], leaves[1], link);
    c.drawLine(mids[1], leaves[2], link);
    c.drawLine(mids[1], leaves[3], link);
    void cube(Offset at, double k, Color top, Color l, Color r) {
      final local = at - iso(Offset.zero, 0, 0, 0);
      _box(c, local, -0.5 * k, -0.5 * k, -0.5 * k, k, k, k, top, l, r);
    }

    for (final l in leaves) {
      cube(l, 0.9, p.cubeTop, p.cube, p.cubeSide);
    }
    for (final m in mids) {
      cube(m, 1.1, p.cubeTop, p.cube, p.cubeSide);
    }
    cube(root, 1.4, p.box, p.boxSide, p.boxDark);
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: root + const Offset(0, 10), width: 12, height: 10),
        const Radius.circular(2),
      ),
      Paint()..color = PaxTokens.brandGreen900,
    );
    // Cadena de cubos hacia la red.
    for (var i = 0; i < 6; i++) {
      final at = Offset(s.width * 0.06 + i * u * 1.7, s.height * 0.45 + i * u * 0.95);
      cube(at, 0.9, p.cubeTop, p.cube, p.cubeSide);
    }
    _label(c, iso(o, 1.2, 0.8, 6.4), 'Raíz anclada');
    _label(c, Offset(s.width * 0.68, s.height * 0.5), 'Anclaje en blockchain');
  }

  void _delivery(Canvas c, Size s) {
    _roadBand(c, s, [
      Offset(-30, s.height * 0.3),
      Offset(s.width * 0.3, s.height * 0.55),
      Offset(s.width * 0.6, s.height * 0.45),
      Offset(s.width * 0.8, s.height * 0.35),
      Offset(s.width + 30, s.height * 0.5),
    ]);
    final o = Offset(s.width * 0.5, s.height * 0.1);
    _house(c, o, 0, 0, green: true);
    _crate(c, o, 3.0, 2.4, 0, 0.8);
    _check(c, iso(o, 1.3, 1, 4.0));
    _label(c, iso(o, 1.3, 1, 5.4), 'Entrega confirmada');
    _label(c, iso(o, 1.3, 2.6, -0.8), 'Centro comunitario');
    _truck(c, Offset(s.width * 0.08, s.height * 0.3), 0, 0);
  }

  void _overview(Canvas c, Size s) {
    // Río y camino que cruzan el mapa, con las paradas en miniatura.
    final river = Path()
      ..moveTo(-20, s.height * 0.18)
      ..quadraticBezierTo(s.width * 0.4, s.height * 0.05, s.width + 20, s.height * 0.28);
    c.drawPath(
      river,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = u * 1.8
        ..color = p.water,
    );
    _roadBand(c, s, [
      Offset(-20, s.height * 0.7),
      Offset(s.width * 0.35, s.height * 0.45),
      Offset(s.width * 0.6, s.height * 0.6),
      Offset(s.width * 0.85, s.height * 0.75),
      Offset(s.width + 20, s.height * 0.6),
    ]);
    final saved = u;
    u = saved * 0.55;
    _crate(c, Offset(s.width * 0.12, s.height * 0.42), 0, 0, 0);
    _slab(c, Offset(s.width * 0.34, s.height * 0.3), 0, 0, 4, 3);
    _crate(c, Offset(s.width * 0.34, s.height * 0.3), 1, 0.8, 0.35);
    _truck(c, Offset(s.width * 0.5, s.height * 0.52), 0, 0);
    _house(c, Offset(s.width * 0.78, s.height * 0.42), 0, 0, green: true);
    u = saved;
  }

  @override
  bool shouldRepaint(_ScenePainter old) => old.scene != scene || old.p.time != p.time || old.from?.time != from?.time;
}
