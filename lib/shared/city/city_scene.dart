import 'dart:math' as math;

/// La ciudad isométrica de la web (`components/background/cityScene.ts`): lógica pura y sembrada siempre con la misma
/// semilla, así el valle es el mismo que en la web. Sin colores (están en `city_palette.dart`) y sin dibujo.

int _i32(int x) => x.toSigned(32);
int _u32(int x) => x & 0xFFFFFFFF;
int _imul(int a, int b) => _i32(_u32(a) * _u32(b));

/// Generador determinista (mulberry32), igual que el de la web.
double Function() cityRng(int seed) {
  var s = _i32(seed);
  return () {
    s = _i32(s + 0x6d2b79f5);
    var t = _imul(s ^ (_u32(s) >> 15), 1 | s);
    t = _i32(_i32(t + _imul(t ^ (_u32(t) >> 7), 61 | t)) ^ t);
    return _u32(t ^ (_u32(t) >> 14)) / 4294967296;
  };
}

double cityMod(double a, double n) => ((a % n) + n) % n;

const citySeed = 20261018;

/// Centro (y) del río para cada x del valle.
double riverY(double u) => 5.6 + math.sin(u * 0.25) * 1.1;

typedef Segment = (double, double, double, double);

const List<Segment> cityRoads = [
  (-3, -3, 3, -3), (3, -3, 3, 3), (-3, 3, 3, 3), (-3, -3, -3, 3), (3, -2, 8, -2), (8, -6, 8, -2), //
  (-2, 3, -2, 8), (-8, 8, -2, 8), (-6, -3, -3, -3), (-6, -6, -6, -3), (3, 2, 6, 2),
];

/// (x, y, w, d) de cada barrio: ahí no se siembra nada al azar.
const List<(double, double, double, double)> cityZones = [
  (-8.8, -8.5, 4.6, 4.4), (5.2, -8.2, 5.2, 5.2), (-2.4, -2.4, 4.8, 4.8), (4.5, -0.2, 3.6, 3.6), //
  (-10.2, 5.8, 6.0, 4.8), (0.8, 6.5, 4.8, 3.6),
];

const List<List<(double, double)>> cityPaths = [
  [(-1.5, 2.5), (-1.5, 4.5), (1.5, 5.0)],
  [(3.5, -1.0), (5.0, 0.0), (5.2, 1.2)],
  [(-3.0, -2.5), (-4.5, -4.0), (-5.5, -4.5)],
  [(-3.0, 7.5), (-5.0, 7.5), (-6.5, 7.0)],
  [(9, -2), (10.5, 0.5), (11.5, 3)],
];

double distSeg(double px, double py, double x1, double y1, double x2, double y2) {
  final dx = x2 - x1, dy = y2 - y1;
  final l = (dx * dx + dy * dy) == 0 ? 1.0 : dx * dx + dy * dy;
  final t = (((px - x1) * dx + (py - y1) * dy) / l).clamp(0.0, 1.0);
  final ex = px - (x1 + t * dx), ey = py - (y1 + t * dy);
  return math.sqrt(ex * ex + ey * ey);
}

/// ¿Se puede sembrar en (x, y)? Fuera del valle, del río, de los barrios y de las calles, no.
bool isFree(double x, double y, [double m = 0.4]) {
  if (x < -12.8 || x > 12.8 || y < -11.8 || y > 11.8) return false;
  if ((y - riverY(x)).abs() < 1.7 + m) return false;
  for (final (a, b, w, d) in cityZones) {
    if (x > a - m && x < a + w + m && y > b - m && y < b + d + m) return false;
  }
  for (final (x1, y1, x2, y2) in cityRoads) {
    if (distSeg(x, y, x1, y1, x2, y2) < 0.75 + m) return false;
  }
  return true;
}

enum TreeType { shade, guayacan, jacaranda, pine, palm, bush }

class Tuft {
  Tuft(this.x, this.y, this.s, this.p);
  final double x, y, s, p;
}

class Flower {
  Flower(this.x, this.y, this.tone, this.s);
  final double x, y, s;
  final int tone;
}

class WildTree {
  WildTree(this.x, this.y, this.type, this.s, this.p);
  final double x, y, s, p;
  final TreeType type;
}

class Meadow {
  Meadow(this.x, this.y, this.rx, this.ry, this.tone);
  final double x, y, rx, ry, tone;
}

class Vehicle {
  Vehicle(this.route, this.i, this.t, this.speed, this.livery);
  final List<(double, double)> route;
  int i;
  double t;
  final double speed;
  final int livery;

  /// Posición y dirección del tramo actual.
  ({double x, double y, double dx, double dy}) get pos {
    final a = route[i], b = route[(i + 1) % route.length];
    return (x: a.$1 + (b.$1 - a.$1) * t, y: a.$2 + (b.$2 - a.$2) * t, dx: b.$1 - a.$1, dy: b.$2 - a.$2);
  }
}

class Person {
  Person(this.off, this.speed, this.dir, this.tone);
  final double off, speed;
  final int dir, tone;
}

class Cloud {
  Cloud(this.x, this.y, this.z, this.s, this.speed);
  double x, y;
  final double z, s, speed;
}

class CityScene {
  CityScene._(
    this.tufts,
    this.flowers,
    this.wildTrees,
    this.meadow,
    this.vehicles,
    this.people,
    this.clouds,
    this.next,
  );

  final List<Tuft> tufts;
  final List<Flower> flowers;
  final List<WildTree> wildTrees;
  final List<Meadow> meadow;
  final List<Vehicle> vehicles;
  final List<Person> people;
  final List<Cloud> clouds;

  /// Para lo que cambia durante la animación (nubes que vuelven a entrar): también determinista.
  final double Function() next;

  static const _treeTypes = [
    TreeType.shade, TreeType.shade, TreeType.guayacan, TreeType.jacaranda, TreeType.pine, TreeType.pine, //
    TreeType.palm, TreeType.bush, TreeType.bush,
  ];

  factory CityScene.create([int seed = citySeed]) {
    final r = cityRng(seed);
    final tufts = <Tuft>[], flowers = <Flower>[], wild = <WildTree>[], meadow = <Meadow>[];
    for (var i = 0; i < 900 && tufts.length < 340; i++) {
      final x = -12.8 + r() * 25.6, y = -11.8 + r() * 23.6;
      if (isFree(x, y, 0.05)) tufts.add(Tuft(x, y, 0.75 + r() * 0.55, r() * 6));
    }
    for (var c = 0; c < 26; c++) {
      // manchas de flores en grupos, no regadas al azar
      final cx = -12 + r() * 24, cy = -11 + r() * 22, tone = c % 5;
      for (var j = 0; j < 9; j++) {
        final x = cx + (r() - 0.5) * 1.6, y = cy + (r() - 0.5) * 1.1;
        if (isFree(x, y, 0.05)) flowers.add(Flower(x, y, tone, 0.7 + r() * 0.5));
      }
    }
    for (var i = 0; i < 700 && wild.length < 58; i++) {
      final x = -12.6 + r() * 25.2, y = -11.6 + r() * 23.2;
      if (!isFree(x, y, 0.45)) continue;
      if (wild.any((t) => math.sqrt((t.x - x) * (t.x - x) + (t.y - y) * (t.y - y)) < 1.15)) continue;
      wild.add(WildTree(x, y, _treeTypes[(r() * _treeTypes.length).floor()], 0.75 + r() * 0.4, r() * 6));
    }
    for (var i = 0; i < 16; i++) {
      meadow.add(Meadow(-12 + r() * 24, -11 + r() * 22, 1.6 + r() * 2.6, 1.2 + r() * 2, r()));
    }
    final vehicles = [
      Vehicle(
        const [
          (8, -5), (8, -2), (3, -2), (3, 3), (-2, 3), (-2, 8), (-7, 8), (-2, 8), (-2, 3), (-3, 3), (-3, -3), //
          (3, -3), (3, -2), (8, -2),
        ],
        0,
        0,
        0.22,
        0,
      ),
      Vehicle(const [(-3, -3), (-6, -3), (-6, -6), (-6, -3), (-3, -3), (3, -3), (3, 3), (-3, 3)], 2, 0.3, 0.26, 1),
      Vehicle(const [(3, 2), (6, 2), (3, 2), (3, 3), (-3, 3), (-3, -3), (3, -3), (3, 2)], 0, 0.6, 0.28, 2),
    ];
    final people = [for (var i = 0; i < 9; i++) Person(i / 9, 0.012 + (i % 3) * 0.004, i.isOdd ? 1 : -1, i % 5)];
    final clouds = [
      Cloud(-16, -12, 6.2, 2.2, 0.008), Cloud(-4, 4, 6.8, 1.8, 0.010), //
      Cloud(8, -10, 5.8, 2.6, 0.007), Cloud(14, 6, 6.4, 1.6, 0.009),
    ];
    return CityScene._(tufts, flowers, wild, meadow, vehicles, people, clouds, r);
  }

  /// Avanza la escena [dt] segundos (vehículos y nubes).
  void step(double dt) {
    for (final v in vehicles) {
      final a = v.route[v.i], b = v.route[(v.i + 1) % v.route.length];
      final len = math.sqrt((b.$1 - a.$1) * (b.$1 - a.$1) + (b.$2 - a.$2) * (b.$2 - a.$2));
      v.t += (v.speed * dt * 8) / math.max(0.5, len);
      if (v.t >= 1) {
        v.t = 0;
        v.i = (v.i + 1) % v.route.length;
      }
    }
    for (final c in clouds) {
      c.x += c.speed * dt * 60;
      c.y -= c.speed * 0.35 * dt * 60;
      if (c.x > 22) {
        c.x = -22;
        c.y = next() * 24 - 12;
      }
    }
  }
}

/// Punto del perímetro de la plaza (a 2,65 del centro) por donde caminan los peatones.
(double, double) ringPoint(double u) {
  const s = 2.65;
  final p = cityMod(u, 1) * 4, side = p.floor(), f = p - side;
  return switch (side) {
    0 => (-s + 2 * s * f, -s),
    1 => (s, -s + 2 * s * f),
    2 => (s - 2 * s * f, s),
    _ => (-s, s - 2 * s * f),
  };
}

/// Distritos de la ciudad (web: `DISTRICTS`). En el teléfono solo se usa Inicio («Plaza central»).
class District {
  const District(this.x, this.y, this.k, this.name, this.type);
  final double x, y, k;
  final String name, type;

  static const home = District(-0.5, -0.8, 1.08, 'Plaza central', 'Centro cívico');
}
