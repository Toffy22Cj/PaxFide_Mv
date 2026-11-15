import 'package:flutter/painting.dart';

/// Colores de la ciudad de Inicio, los mismos de la web (`components/background/cityPalette.ts`, de
/// `paxfide-home.html`), con su versión de día y de noche.
///
/// **Excepción a la regla de colores** (`test/architecture/design_tokens_test.dart`): la ciudad es una ilustración, no
/// interfaz; no lleva texto de la app encima ni comunica estados, así que sus colores viven solo en este archivo, como
/// en la web (D-P1, DF7-11). Nada fuera de la ciudad puede usar estos colores.

/// Las tres caras de una caja isométrica.
class CityBox {
  const CityBox(this.top, this.left, this.right);
  final Color top, left, right;
}

class CityTree {
  const CityTree(this.trunk, this.canopy);
  final Color trunk;
  final List<Color> canopy;
}

class CityLivery {
  const CityLivery(this.cargo, this.cab);
  final CityBox cargo, cab;
}

class CityPalette {
  const CityPalette({
    required this.sky,
    required this.grass,
    required this.soilLeft,
    required this.soilRight,
    required this.meadowLight,
    required this.meadowDark,
    required this.path,
    required this.sand,
    required this.water,
    required this.waterChannel,
    required this.stream,
    required this.roadEdge,
    required this.road,
    required this.roadLine,
    required this.bridge,
    required this.plazaOrg,
    required this.plazaHub,
    required this.plazaHome,
    required this.plazaHomeInner,
    required this.plazaVilla,
    required this.plazaSchool,
    required this.plazaRiver,
    required this.tuftBlades,
    required this.trees,
    required this.palmTrunk,
    required this.palmLeaves,
    required this.bush,
    required this.bushHighlight,
    required this.lampPole,
    required this.lampBulb,
    required this.windowOff,
    required this.personBody,
    required this.personHead,
    required this.cloud,
    required this.cloudShadow,
    required this.orgBase,
    required this.orgTop,
    required this.mill,
    required this.hubBase,
    required this.hall,
    required this.hallTower,
    required this.house,
    required this.school,
    required this.riverHouse,
    required this.bird,
  });

  final List<(double, Color)> sky;
  final Color grass, soilLeft, soilRight, meadowLight, meadowDark, path, sand, water, waterChannel;

  /// Brillos del río (blanco de día, azul de noche); el alfa lo pone quien dibuja.
  final Color stream;
  final Color roadEdge, road, roadLine;
  final CityBox bridge, plazaOrg, plazaHub, plazaHome, plazaHomeInner, plazaVilla, plazaSchool, plazaRiver;
  final List<Color> tuftBlades;
  final Map<TreeKind, CityTree> trees;
  final Color palmTrunk;
  final List<Color> palmLeaves;
  final Color bush, bushHighlight, lampPole, lampBulb, windowOff;
  final Color? personBody;
  final Color personHead, cloud;
  final double cloudShadow;
  final CityBox orgBase, orgTop;
  final Color mill;
  final CityBox hubBase, hall, hallTower, house, school, riverHouse;
  final Color bird;

  // Lo que no cambia entre el día y la noche.
  static const star = Color(0xFFEEF6EF);
  static const shadow = Color(0xFF12261C);
  static const lampGlow = Color(0xFFF9C75E);
  static const windowLit = Color(0xFFF9C75E);
  static const headlight = Color(0xFFFFF5BE);
  static const people = [Color(0xFFF3B544), Color(0xFF327DA2), Color(0xFFE86A5C), Color(0xFF4E9155), Color(0xFFB395E0)];
  static const court = Color(0xFF327DA2);
  static const courtLine = Color(0xFFEBF5F9);
  static const deck = CityBox(Color(0xFFC68B59), Color(0xFF8B5A2B), Color(0xFF6E4720));
  static const millBlade = Color(0xFFF8FAFA);
  static const millHub = Color(0xFFF3B544);
  static const hubPanel = CityBox(Color(0xFF8CC3DE), Color(0xFF255E79), Color(0xFF3688B0));
  static const crateGate = CityBox(Color(0xFFF3B544), Color(0xFFD9962C), Color(0xFF785008));
  static const crate1 = CityBox(Color(0xFFF8CF7E), Color(0xFFD9962C), Color(0xFFF3B544));
  static const crate2 = CityBox(Color(0xFFA8D5AE), Color(0xFF20604C), Color(0xFF4E9155));
  static const crate3 = CityBox(Color(0xFF8CC3DE), Color(0xFF255E79), Color(0xFF327DA2));
  static const tower = CityBox(Color(0xFF255E79), Color(0xFF1B5141), Color(0xFF133B2F));
  static const towerBlock = CityBox(Color(0xFFF8CF7E), Color(0xFFF3B544), Color(0xFFD9962C));
  static const wave = Color(0xFFF3B544);
  static const hallRoof = CityBox(Color(0xFFF3B544), Color(0xFFD9962C), Color(0xFF9E6B14));
  static const hallTowerRoof = CityBox(Color(0xFFF8CF7E), Color(0xFFF3B544), Color(0xFFB87D19));
  static const clockFace = Color(0xFFFFFFFF);
  static const clockHands = Color(0xFF1B5141);
  static const fountain = CityBox(Color(0xFF3688B0), Color(0xFF20604C), Color(0xFF1B5141));
  static const fountainInner = CityBox(Color(0xFF79BFDF), Color(0xFF255E79), Color(0xFF1E4E63));
  static const jet = Color(0xFFEBF5F9);
  static const drops = Color(0xE6EBF5F9);
  static const houseRoof = CityBox(Color(0xFF4E9155), Color(0xFF2E7550), Color(0xFF1B5141));
  static const smoke = Color(0xFFF0F5F0);
  static const schoolPanel = CityBox(Color(0xFF3688B0), Color(0xFF255E79), Color(0xFF1B4357));
  static const ball = Color(0xFFF3B544);
  static const mast = Color(0xFF8FAFAF);
  static const tank = CityBox(Color(0xFF79BFDF), Color(0xFF327DA2), Color(0xFF255E79));
  static const riverHouseRoof = CityBox(Color(0xFFF3B544), Color(0xFFD9962C), Color(0xFF9E6B14));
  static const boatWake = Color(0x99EBF5F9);
  static const boatHull = CityBox(Color(0xFFFAFDF9), Color(0xFF255E79), Color(0xFF1B5141));
  static const boatCabin = CityBox(Color(0xFFF8CF7E), Color(0xFFD9962C), Color(0xFFF3B544));
  static const butterflies = [Color(0xFFF3B544), Color(0xFFFFFFFF), Color(0xFFB395E0), Color(0xFFE86A5C)];
  static const leaves = [Color(0xFFF3B544), Color(0xFF5CB868), Color(0xFFF8CF7E)];
  static const firefly = Color(0xFFFFEB78);
  static const tuftGlint = Color(0xD9ECFFD2);
  static const bushAlt = Color(0xFF59B36C);
  static const flowers = [
    Color(0xFFF3B544),
    Color(0xFFFFFFFF),
    Color(0xFFE86A5C),
    Color(0xFFB395E0),
    Color(0xFFF8CF7E),
  ];
  static const tagYellow = Color(0xFFF3B544);
  static const tagDarkBg = Color(0xD910261D);
  static const tagBorder = Color(0x40FFFFFF);
  static const tagTextLight = Color(0xFFFFFFFF);
  static const tagTextDark = Color(0xFF1B5141);

  static const liveries = [
    CityLivery(
      CityBox(Color(0xFFF8CF7E), Color(0xFFD9962C), Color(0xFFF3B544)),
      CityBox(Color(0xFF4E9155), Color(0xFF1B5141), Color(0xFF20604C)),
    ),
    CityLivery(
      CityBox(Color(0xFF8CC3DE), Color(0xFF255E79), Color(0xFF327DA2)),
      CityBox(Color(0xFFEBF5F9), Color(0xFFB8D4E3), Color(0xFF9BC0D4)),
    ),
    CityLivery(
      CityBox(Color(0xFFA8D5AE), Color(0xFF2E7550), Color(0xFF4E9155)),
      CityBox(Color(0xFFF3B544), Color(0xFFD9962C), Color(0xFF785008)),
    ),
  ];

  static CityBox _plaza(Color top, [Color left = const Color(0xFF20604C), Color right = const Color(0xFF1B5141)]) =>
      CityBox(top, left, right);

  static final day = CityPalette(
    sky: const [(0, Color(0xFFE4F2F7)), (0.55, Color(0xFFE6F2DE)), (1, Color(0xFFC6DEBB))],
    grass: const Color(0xFF5DAE69),
    soilLeft: const Color(0xFF8A6B47),
    soilRight: const Color(0xFF6E5236),
    meadowLight: const Color(0x8C78C46E),
    meadowDark: const Color(0x733A8246),
    path: const Color(0xFFD6C6A3),
    sand: const Color(0xFFCDBF9F),
    water: const Color(0xFF2D81AA),
    waterChannel: const Color(0x5979BFDF),
    stream: const Color(0xFFFFFFFF),
    roadEdge: const Color(0xFFC7D4CA),
    road: const Color(0xFF556960),
    roadLine: const Color(0xB3FFFFFF),
    bridge: const CityBox(Color(0xFF33473C), Color(0xFF255E79), Color(0xFF1B5141)),
    plazaOrg: _plaza(const Color(0xFFC9E0C1)),
    plazaHub: _plaza(const Color(0xFFD5E0E3), const Color(0xFF255E79), const Color(0xFF1B4357)),
    plazaHome: _plaza(const Color(0xFFEBF3E6)),
    plazaHomeInner: _plaza(const Color(0xFFDCEAD5), const Color(0xFF4E9155), const Color(0xFF20604C)),
    plazaVilla: _plaza(const Color(0xFFD6E8CE)),
    plazaSchool: _plaza(const Color(0xFFD9EAD2)),
    plazaRiver: _plaza(const Color(0xFFD5E8CE)),
    tuftBlades: const [Color(0xFF3E8C47), Color(0xFF6BBE72), Color(0xFF4FA058)],
    trees: const {
      TreeKind.shade: CityTree(Color(0xFF6B482A), [Color(0xFF2E723D), Color(0xFF419652), Color(0xFF59B36C)]),
      TreeKind.guayacan: CityTree(Color(0xFF5E3E20), [Color(0xFFD9962C), Color(0xFFF3B544), Color(0xFFF8CF7E)]),
      TreeKind.jacaranda: CityTree(Color(0xFF4A3326), [Color(0xFF6C4F94), Color(0xFF8E6CBF), Color(0xFFB395E0)]),
      TreeKind.pine: CityTree(Color(0xFF5B3A1E), [Color(0xFF1F5E3A), Color(0xFF2E7550), Color(0xFF3E8C5A)]),
    },
    palmTrunk: const Color(0xFF8B5A2B),
    palmLeaves: const [Color(0xFF4E9155), Color(0xFF2E7550), Color(0xFF74B56C), Color(0xFF20604C)],
    bush: const Color(0xFF4E9155),
    bushHighlight: const Color(0x2EFFFFFF),
    lampPole: const Color(0xFF405656),
    lampBulb: const Color(0xFFFFFFFF),
    windowOff: const Color(0xEBD7EBF5),
    personBody: null,
    personHead: const Color(0xFF8B5A3C),
    cloud: const Color(0xE0FFFFFF),
    cloudShadow: 0.07,
    orgBase: const CityBox(Color(0xFF4E9155), Color(0xFFEBF5EC), Color(0xFFCFE3D1)),
    orgTop: const CityBox(Color(0xFF74B56C), Color(0xFFD9ECF2), Color(0xFFB7D8E6)),
    mill: const Color(0xFFFFFFFF),
    hubBase: const CityBox(Color(0xFF327DA2), Color(0xFFEBF2F5), Color(0xFFC9D9E0)),
    hall: const CityBox(Color(0xFFFAFDF9), Color(0xFFF4F9F2), Color(0xFFDAE6D6)),
    hallTower: const CityBox(Color(0xFFFAFDF9), Color(0xFFFFFFFF), Color(0xFFE2ECE0)),
    house: const CityBox(Color(0xFFFAFDF9), Color(0xFFF7FAF5), Color(0xFFDCE8D8)),
    school: const CityBox(Color(0xFF255E79), Color(0xFFFDF4E2), Color(0xFFE8D6B5)),
    riverHouse: const CityBox(Color(0xFFFAFDF9), Color(0xFFF4F9F2), Color(0xFFD8E6D4)),
    bird: const Color(0xFF20604C),
  );

  static final night = CityPalette(
    sky: const [(0, Color(0xFF06110C)), (1, Color(0xFF0E2419))],
    grass: const Color(0xFF10291E),
    soilLeft: const Color(0xFF2A1E14),
    soilRight: const Color(0xFF1E150E),
    meadowLight: const Color(0x59285A3C),
    meadowDark: const Color(0x6605140E),
    path: const Color(0xFF1F3529),
    sand: const Color(0xFF1E382C),
    water: const Color(0xFF14384A),
    waterChannel: const Color(0x59286482),
    stream: const Color(0x8079BFDF),
    roadEdge: const Color(0xFF13281E),
    road: const Color(0xFF1C382C),
    roadLine: const Color(0x73F3B544),
    bridge: const CityBox(Color(0xFF20382D), Color(0xFF255E79), Color(0xFF1B5141)),
    plazaOrg: _plaza(const Color(0xFF1B3F2F)),
    plazaHub: _plaza(const Color(0xFF1B333E), const Color(0xFF255E79), const Color(0xFF1B4357)),
    plazaHome: _plaza(const Color(0xFF1B3B2E)),
    plazaHomeInner: _plaza(const Color(0xFF234B3B), const Color(0xFF4E9155), const Color(0xFF20604C)),
    plazaVilla: _plaza(const Color(0xFF1B3A2D)),
    plazaSchool: _plaza(const Color(0xFF1D3B2E)),
    plazaRiver: _plaza(const Color(0xFF1B3D2F)),
    tuftBlades: const [Color(0xFF1E4A35), Color(0xFF2B6145), Color(0xFF22553C)],
    trees: const {
      TreeKind.shade: CityTree(Color(0xFF4A3423), [Color(0xFF143B29), Color(0xFF1C4E37), Color(0xFF255E44)]),
      TreeKind.guayacan: CityTree(Color(0xFF3E2914), [Color(0xFF8B6816), Color(0xFFB88B22), Color(0xFFD9A42C)]),
      TreeKind.jacaranda: CityTree(Color(0xFF33231A), [Color(0xFF3D2D54), Color(0xFF583F7A), Color(0xFF74569C)]),
      TreeKind.pine: CityTree(Color(0xFF3A2614), [Color(0xFF0F2E1E), Color(0xFF163D29), Color(0xFF1E4D34)]),
    },
    palmTrunk: const Color(0xFF5A3A1C),
    palmLeaves: const [Color(0xFF1E4A35), Color(0xFF173D2B), Color(0xFF2B6145), Color(0xFF123325)],
    bush: const Color(0xFF1C4A33),
    bushHighlight: const Color(0x0DFFFFFF),
    lampPole: const Color(0xFF8FAFAF),
    lampBulb: const Color(0xFFF9C75E),
    windowOff: const Color(0xE6284650),
    personBody: const Color(0xFF9FB8AE),
    personHead: const Color(0xFFC9D9D2),
    cloud: const Color(0x24DCEBE6),
    cloudShadow: 0.03,
    orgBase: const CityBox(Color(0xFF4E9155), Color(0xFF1F4B38), Color(0xFF153628)),
    orgTop: const CityBox(Color(0xFF74B56C), Color(0xFF255E79), Color(0xFF1B465B)),
    mill: const Color(0xFFB8D0C5),
    hubBase: const CityBox(Color(0xFF327DA2), Color(0xFF1D3E4F), Color(0xFF142C38)),
    hall: const CityBox(Color(0xFFFAFDF9), Color(0xFF214838), Color(0xFF163327)),
    hallTower: const CityBox(Color(0xFFFAFDF9), Color(0xFF265340), Color(0xFF1A3B2D)),
    house: const CityBox(Color(0xFFFAFDF9), Color(0xFF244D3C), Color(0xFF18362A)),
    school: const CityBox(Color(0xFF255E79), Color(0xFF2D3E35), Color(0xFF1F2C25)),
    riverHouse: const CityBox(Color(0xFFFAFDF9), Color(0xFF234D3C), Color(0xFF173629)),
    bird: const Color(0xFFA8D5AE),
  );

  /// Como la web: el día y la noche se cortan en 0,5; los brillos usan la mezcla continua.
  static CityPalette of(double night) => night > 0.5 ? CityPalette.night : CityPalette.day;
}

/// Árboles con copa (la palmera y el arbusto se dibujan aparte).
enum TreeKind { shade, guayacan, jacaranda, pine }
