import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../../app/app_routes.dart';
import '../../../app/app_services.dart';
import '../../../app/qr_scanner_sheet.dart';
import '../../../app/text_size_button.dart';
import '../../../app/theme_mode_button.dart';
import '../../../shared/dates.dart';
import '../../../shared/money.dart';
import '../../../shared/theme/pax_theme.dart';
import '../../../shared/theme/pax_tokens.dart';
import '../../../shared/widgets/pax_app_bar.dart';
import '../../../shared/widgets/pax_logo.dart';
import '../../../shared/widgets/pax_ui.dart';
import '../../campaigns/data/campaign_api.dart';
import '../../campaigns/domain/campaign_progress.dart';
import '../../campaigns/domain/campaign_search.dart';
import '../../campaigns/presentation/campaign_search_view.dart';
import '../../campaigns/presentation/campaign_summary_card.dart';
import 'welcome_world.dart';
import '../../../shared/motion/pax_route.dart';

/// Colores de texto de la bienvenida, como en el landing: titular en dos tonos de verde, etiquetas en mono ámbar.
/// Todo de la paleta (en oscuro, sus inversos).
class _Ink {
  _Ink(this.dark);
  final bool dark;
  Color get strong => dark ? PaxTokens.brandGreen50 : PaxTokens.brandGreen900;
  Color get accent => dark ? PaxDarkTokens.green : PaxTokens.brandGreen500;
  Color get body => dark ? PaxDarkTokens.neutral : PaxTokens.brandNeutral700;
  Color get step => dark ? PaxDarkTokens.yellow : PaxTokens.brandYellow900;
  Color get tagBg => dark ? PaxTokens.brandGreen900 : PaxTokens.brandGreen50;
  Color get tagFg => dark ? PaxTokens.brandGreen50 : PaxTokens.brandGreen800;
}

/// Una parada del recorrido.
class _Stop {
  const _Stop({
    required this.label,
    required this.tag,
    required this.title,
    required this.accent,
    required this.text,
    this.facts = const [],
  });
  final String label;
  final String tag;
  final String title;
  final String accent;
  final String text;
  final List<(String, String)> facts;
}

/// Textos del landing. Los datos de ejemplo (120 kits, Lorica, SHA-256…) se cambian por hechos del sistema; los pasos
/// 04 y 05 siguen lo que dice la documentación (ADR-039) y están PENDIENTES DE CONFIRMAR por el equipo.
const _stops = [
  _Stop(
    label: '01 / 05 · Donas',
    tag: 'Pago confirmado',
    title: 'Tu donación, ',
    accent: 'de principio a fin.',
    text:
        'Pagas por la pasarela. Cuando el pago se confirma, se abre el historial de tu donación y recibes un código '
        'para seguirla paso a paso.',
  ),
  _Stop(
    label: '02 / 05 · Se convierte en ayuda',
    tag: 'Fondos asignados → lote registrado',
    title: 'De saldo a ',
    accent: 'cajas reales.',
    text:
        'La organización compra los insumos y registra cada lote en la bodega. El dinero asignado y el lote quedan '
        'conectados, y cada lote recibe su propio QR.',
    facts: [('1 lote', 'registrado y trazable'), ('1 QR', 'por lote, no por cada unidad')],
  ),
  _Stop(
    label: '03 / 05 · Viaja y se reparte',
    tag: 'Lote despachado · lote dividido',
    title: 'Sigue la caja, ',
    accent: 'aunque se divida.',
    text:
        'Cada despacho y cada recepción se registran al escanear el QR. Si el lote se reparte entre dos destinos, '
        'cada parte conserva el vínculo con su origen.',
    facts: [('Lote dividido', 'el lote original sigue existiendo'), ('Puntos de control', 'solo paradas oficiales')],
  ),
  _Stop(
    label: '04 / 05 · Queda sellado',
    tag: 'Lote sellado · registro público',
    title: 'Una huella que ',
    accent: 'se puede comprobar.',
    text:
        'Cada registro lleva una huella digital encadenada a la anterior. Por lotes, esas huellas se resumen en una '
        'sola y se anclan en una red blockchain pública para poder verificarlas.',
    facts: [('Huella digital', 'en cada registro'), ('Sin datos personales', 'en la red pública')],
  ),
  _Stop(
    label: '05 / 05 · Llega',
    tag: 'Entrega confirmada',
    title: 'Entregado, ',
    accent: 'y lo puedes comprobar.',
    text:
        'La entrega se registra sin exponer la identidad de quien recibe. Con tu código ves el recorrido completo, '
        'desde el pago hasta la comunidad.',
    facts: [('Centro comunitario', 'el destino de la entrega'), ('5 de 5 pasos', 'registrados y verificables')],
  ),
];

const _manifesto = 'Cada paso queda registrado. Y tú lo puedes comprobar cuando quieras.';
const _manifestoHighlight = {'registrado.', 'comprobar'};

/// `/welcome`: bienvenida sin sesión (M-01/M-02), la adaptación del landing web (Enmienda 3 de ADR-043). Primera
/// pantalla sin sesión y base de la pila con LOGGED_OUT.
///
/// Como el landing: el mundo ilustrado queda fijo detrás y, al deslizar, la cámara recorre la carretera parada por
/// parada mientras el día se vuelve noche y amanece otra vez; cada tarjeta aparece al llegar a su parada y se desvanece
/// al irse; en "Todo el recorrido" las palabras se encienden al avanzar; al llegar al catálogo el mundo se desenfoca.
/// Sin datos de ejemplo presentados como reales y sin campo de código: el código solo se escribe en `/tracking`.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with SingleTickerProviderStateMixin {
  late final AppServices _services = AppScope.of(context);
  final _scroll = ScrollController();
  final _clock = WorldClock();
  final _sections = List.generate(6, (_) => GlobalKey());
  final _maniKey = GlobalKey();
  final _trackingKey = GlobalKey();
  final _catalogKey = GlobalKey();

  /// Posición en el recorrido según el scroll (0…5, sin suavizar). Mueve las tarjetas y el día/noche.
  final _sRaw = ValueNotifier<double>(0);

  /// Cuánto se ha encendido la frase de "Todo el recorrido" (0…1).
  final _mani = ValueNotifier<double>(0);

  /// El mundo se desenfoca al llegar al catálogo.
  final _blur = ValueNotifier<bool>(false);

  bool _menuOpen = false;
  late final Ticker _ticker = createTicker(_tick);
  Duration _last = Duration.zero;
  double _target = 0, _camS = 0, _t = 0, _night = 0;
  bool _reduced = false, _dark = false;
  late Future<List<CampaignSummary>> _campaigns = _fetch();

  Future<List<CampaignSummary>> _fetch() => _services.campaignSearch.search(const CampaignQuery());

  bool get _ambient => WelcomeWorld.ambientMotion && !_reduced;
  bool get _animateWorld => _ambient && !_blur.value;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_readScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    _dark = Theme.of(context).brightness == Brightness.dark;
    WidgetsBinding.instance.addPostFrameCallback((_) => _readScroll());
  }

  @override
  void dispose() {
    _ticker.dispose();
    _scroll.dispose();
    _clock.dispose();
    _sRaw.dispose();
    _mani.dispose();
    _blur.dispose();
    super.dispose();
  }

  RenderBox? _box(GlobalKey key) {
    final box = key.currentContext?.findRenderObject();
    return box is RenderBox && box.attached && box.hasSize ? box : null;
  }

  /// Landing: `readScroll`. Lee dónde está cada parada en la pantalla y fija hacia dónde va la cámara.
  void _readScroll() {
    if (!mounted) return;
    final h = MediaQuery.sizeOf(context).height;
    final centers = <double>[];
    for (final k in _sections) {
      final box = _box(k);
      if (box == null) return;
      centers.add(box.localToGlobal(Offset.zero).dy + box.size.height / 2);
    }
    // Centro de la pantalla frente al centro de cada parada.
    final y = h / 2;
    var s = 0.0;
    if (y >= centers.last) {
      s = centers.length - 1.0;
    } else if (y > centers.first) {
      for (var i = 0; i < centers.length - 1; i++) {
        if (y < centers[i + 1]) {
          s = i + (y - centers[i]) / (centers[i + 1] - centers[i]);
          break;
        }
      }
    }
    _sRaw.value = s;
    final i = s.floor();
    _target = math.min(5, i + WelcomeWorld.smooth(0.28, 0.72, s - i));
    _night = _dark ? 1 : WelcomeWorld.autoNight(s);
    final mani = _box(_maniKey);
    if (mani != null) _mani.value = ((h * 0.78 - mani.localToGlobal(Offset.zero).dy) / (h * 0.45)).clamp(0.0, 1.0);
    final catalog = _box(_catalogKey);
    _blur.value = catalog != null && catalog.localToGlobal(Offset.zero).dy <= h * 0.82;
    if (_reduced) {
      _camS = _target;
      _clock.set(camS: _camS, t: _t, night: _night);
    } else if (!_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  /// Landing: `frame`. La cámara alcanza su destino con suavidad y el mundo sigue en movimiento.
  ///
  /// Rendimiento: mientras la cámara se mueve (al deslizar) el mundo se pinta en cada fotograma; con la cámara quieta
  /// solo se mueven nubes, pasto y agua, que son lentos, y basta con 30 fotogramas por segundo. Pintarlo a 60 o 120
  /// sin que nadie lo moviera gastaba el teléfono entero en el fondo.
  void _tick(Duration elapsed) {
    final dt = math.min(0.05, (elapsed - _last).inMicroseconds / 1e6);
    _last = elapsed;
    if (_animateWorld) _t += dt;
    _sinceFrame += dt;
    final moving = _camS != _target;
    _camS += (_target - _camS) * math.min(1, dt * 5.5);
    if ((_target - _camS).abs() < 1e-4) _camS = _target;
    if (moving || _sinceFrame >= _ambientFrame) {
      _sinceFrame = 0;
      _clock.set(camS: _camS, t: _t, night: _night);
    }
    if (!_animateWorld && _camS == _target) _ticker.stop();
  }

  static const _ambientFrame = 1 / 30;
  double _sinceFrame = 0;

  void _scrollTo(GlobalKey key) {
    setState(() => _menuOpen = false);
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: _reduced ? Duration.zero : const Duration(milliseconds: 650),
      curve: Curves.easeInOutCubic,
      alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
      alignment: 0.12,
    );
  }

  void _go(VoidCallback action) {
    setState(() => _menuOpen = false);
    action();
  }

  void _openAll() => Navigator.of(context).push(
    PaxPageRoute<void>(
      builder: (page) => Scaffold(
        appBar: const PaxAppBar(title: Text('Convocatorias')),
        body: CampaignSearchView(
          search: _services.campaignSearch,
          onOpen: (code) {
            Navigator.of(page).pop();
            _services.router.push(AppRoutes.campaignPath(code));
          },
        ),
      ),
    ),
  );

  void _openCampaign(String code) => _services.router.push(AppRoutes.campaignPath(code));

  @override
  Widget build(BuildContext context) {
    final theme = PaxTheme.welcome(Theme.of(context));
    final dark = theme.brightness == Brightness.dark;
    final ink = _Ink(dark);
    // Solo lo que se usa: MediaQuery.of haría reconstruir toda la bienvenida en cada fotograma del teclado.
    final h = MediaQuery.sizeOf(context).height;
    final pad = MediaQuery.paddingOf(context);
    return Theme(
      data: theme,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        child: Scaffold(
          extendBody: true,
          body: Stack(
            children: [
              // El mundo, en su propia capa. Al llegar al catálogo se cubre con un velo del color de la página en vez de
              // desenfocarse: un desenfoque a pantalla completa se recalcula en cada fotograma y era lo más caro de la
              // app; el velo es un color con transparencia.
              Positioned.fill(child: WelcomeWorldView(clock: _clock)),
              Positioned.fill(
                child: IgnorePointer(
                  child: ValueListenableBuilder<bool>(
                    valueListenable: _blur,
                    builder: (context, veiled, _) => TweenAnimationBuilder<double>(
                      tween: Tween(end: veiled ? 1 : 0),
                      duration: _reduced ? Duration.zero : const Duration(milliseconds: 500),
                      builder: (context, v, _) => v < 0.01
                          ? const SizedBox.shrink()
                          : ColoredBox(
                              key: const Key('welcome.veil'),
                              color: theme.scaffoldBackgroundColor.withValues(alpha: 0.55 * v),
                            ),
                    ),
                  ),
                ),
              ),
              NotificationListener<ScrollMetricsNotification>(
                onNotification: (_) {
                  WidgetsBinding.instance.addPostFrameCallback((_) => _readScroll());
                  return false;
                },
                child: SingleChildScrollView(
                  key: const Key('welcome.list'),
                  controller: _scroll,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (i, stop) in _stops.indexed)
                        ConstrainedBox(
                          key: _sections[i],
                          constraints: BoxConstraints(minHeight: i == 0 ? h : h * 1.5),
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              16,
                              i == 0 ? pad.top + 96 : h * 0.12,
                              16,
                              i == 0 ? 24 : h * 0.12,
                            ),
                            child: Center(
                              child: _Fade(
                                index: i,
                                position: _sRaw,
                                child: _StopCard(
                                  key: Key('welcome.step.${i + 1}'),
                                  stop: stop,
                                  ink: ink,
                                  extra: i == 0 ? _heroActions(ink) : null,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ConstrainedBox(
                        key: _sections[5],
                        constraints: BoxConstraints(minHeight: h * 1.7),
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: h * 0.1),
                          child: Center(
                            child: KeyedSubtree(
                              key: _maniKey,
                              child: _Manifesto(ink: ink, progress: _mani),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            KeyedSubtree(
                              key: _trackingKey,
                              child: _Island(
                                ink: ink,
                                onTrack: () => _services.router.push(AppRoutes.tracking),
                                onRegister: () => _services.router.push(AppRoutes.register),
                              ),
                            ),
                            const SizedBox(height: 64),
                            KeyedSubtree(key: _catalogKey, child: _catalogHeader(ink)),
                            const SizedBox(height: 22),
                            _catalog(ink),
                            const SizedBox(height: 28),
                            PaxGlass(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              child: Text(
                                'PaxFide · plataforma de trazabilidad de donaciones',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: ink.body),
                              ),
                            ),
                            SizedBox(height: 110 + pad.bottom),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_menuOpen)
                Positioned.fill(
                  child: Semantics(
                    button: true,
                    label: 'Cerrar menú de navegación',
                    child: GestureDetector(
                      key: const Key('welcome.menu.backdrop'),
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _menuOpen = false),
                      // Velo sin desenfoque (el desenfoque se recalculaba en cada fotograma del mundo animado).
                      child: ColoredBox(
                        color: Theme.of(context).colorScheme.scrim.withValues(alpha: dark ? 0.45 : 0.32),
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                    child: _Nav(
                      ink: ink,
                      open: _menuOpen,
                      onToggle: () => setState(() => _menuOpen = !_menuOpen),
                      onTop: () => _scrollTo(_sections[0]),
                      links: [
                        ('how', 'Cómo funciona', () => _scrollTo(_sections[0])),
                        ('verify', 'Verificación', () => _scrollTo(_sections[3])),
                        ('campaigns', 'Convocatorias', () => _scrollTo(_catalogKey)),
                        ('tracking', 'Seguimiento', () => _scrollTo(_trackingKey)),
                      ],
                      onLogin: () => _go(() => _services.router.push(AppRoutes.login)),
                      onFollow: () => _go(() => _services.router.push(AppRoutes.tracking)),
                      onDonate: () => _scrollTo(_catalogKey),
                      onScan: () => _go(() => scanQr(context)),
                    ),
                  ),
                ),
              ),
            ],
          ),
          // M-02: "Ingresar" fijo, al alcance del pulgar, sobre una píldora de vidrio como la barra de arriba.
          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: PaxGlass(
              radius: 999,
              padding: const EdgeInsets.all(6),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('welcome.bar.tracking'),
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
                      onPressed: () => _services.router.push(AppRoutes.tracking),
                      child: const Text('Seguir donación', overflow: TextOverflow.ellipsis),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: FilledButton(
                      key: const Key('welcome.login'),
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
                      onPressed: () => _services.router.push(AppRoutes.login),
                      child: const Text('Ingresar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Botones de la primera parada, como en el landing, más Escanear (M-01) y la pista de deslizar.
  Widget _heroActions(_Ink ink) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 20),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          FilledButton(
            key: const Key('welcome.donate'),
            onPressed: () => _scrollTo(_catalogKey),
            child: const Text('Donar a una convocatoria'),
          ),
          OutlinedButton(
            key: const Key('welcome.tracking'),
            onPressed: () => _services.router.push(AppRoutes.tracking),
            child: const Text('Seguir mi donación'),
          ),
          OutlinedButton.icon(
            key: const Key('welcome.scan'),
            onPressed: () => scanQr(context),
            icon: const Icon(Icons.qr_code_scanner, size: 18),
            label: const Text('Escanear un código QR'),
          ),
        ],
      ),
      const SizedBox(height: 18),
      Row(
        children: [
          _Wheel(clock: _clock, color: ink.body),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Desliza y acompaña su recorrido',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: ink.body),
            ),
          ),
        ],
      ),
    ],
  );

  Widget _catalogHeader(_Ink ink) => PaxGlass(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 14),
    child: Column(
      children: [
        _Tag('Convocatorias abiertas', ink: ink),
        const SizedBox(height: 14),
        _TwoTone('Causas abiertas que ', 'puedes seguir paso a paso', ink: ink, center: true, size: 30),
        const SizedBox(height: 10),
        Text(
          'Explora las convocatorias abiertas. Cada donación queda registrada y puedes seguirla hasta su entrega.',
          textAlign: TextAlign.center,
          style: TextStyle(color: ink.body, height: 1.5),
        ),
        const SizedBox(height: 6),
        TextButton(key: const Key('welcome.campaigns.all'), onPressed: _openAll, child: const Text('Ver todas')),
      ],
    ),
  );

  Widget _catalog(_Ink ink) => FutureBuilder<List<CampaignSummary>>(
    future: _campaigns,
    builder: (context, snap) {
      if (snap.connectionState != ConnectionState.done) {
        return const Column(
          key: Key('welcome.campaigns.loading'),
          children: [CampaignSkeletonCard(), CampaignSkeletonCard(), CampaignSkeletonCard()],
        );
      }
      if (snap.hasError) {
        return PaxGlass(
          key: const Key('welcome.campaigns.error'),
          padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
          child: Row(
            children: [
              Expanded(
                child: Text('No pudimos cargar las convocatorias.', style: TextStyle(color: ink.strong)),
              ),
              TextButton(
                key: const Key('welcome.campaigns.retry'),
                onPressed: () => setState(() {
                  _campaigns = _fetch();
                }),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        );
      }
      final items = snap.data ?? const <CampaignSummary>[];
      if (items.isEmpty) {
        return PaxGlass(
          key: const Key('welcome.campaigns.empty'),
          padding: const EdgeInsets.all(20),
          child: Text('No hay convocatorias abiertas en este momento.', style: TextStyle(color: ink.strong)),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final c in items.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _CampaignCard(
                c,
                key: Key('welcome.campaign.${c.publicCode}'),
                ink: ink,
                detailsKey: Key('welcome.campaign.${c.publicCode}.details'),
                onOpen: () => _openCampaign(c.publicCode),
              ),
            ),
        ],
      );
    },
  );
}

// --- piezas de diseño del landing ---------------------------------------------------------------------------------

/// La tarjeta de una parada aparece al llegar y se desvanece al irse (landing: opacidad según la distancia al centro).
class _Fade extends StatelessWidget {
  const _Fade({required this.index, required this.position, required this.child});
  final int index;
  final ValueNotifier<double> position;
  final Widget child;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<double>(
    valueListenable: position,
    builder: (context, s, child) =>
        Opacity(opacity: 1 - WelcomeWorld.smooth(0.22, 0.44, (s - index).abs()), child: child),
    child: child,
  );
}

/// Ruedita del ratón que baja una y otra vez ("Desliza y acompaña su recorrido").
class _Wheel extends StatelessWidget {
  const _Wheel({required this.clock, required this.color});
  final WorldClock clock;
  final Color color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      width: 18,
      height: 28,
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.6), width: 2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: AnimatedBuilder(
        animation: clock,
        builder: (context, _) {
          final p = (clock.t % 1.6) / 1.6;
          final opacity = p < 0.3 ? p / 0.3 : 1 - (p - 0.3) / 0.7;
          return Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.only(top: 3 + 8 * p),
              child: Opacity(
                opacity: clock.t == 0 ? 1 : opacity.clamp(0.0, 1.0),
                child: Container(
                  width: 3,
                  height: 6,
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}

/// Etiqueta en mono dentro de una píldora ("PAGO CONFIRMADO").
class _Tag extends StatelessWidget {
  const _Tag(this.text, {required this.ink});
  final String text;
  final _Ink ink;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(color: ink.tagBg, borderRadius: BorderRadius.circular(7)),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(fontFamily: 'monospace', fontSize: 12, letterSpacing: 0.3, color: ink.tagFg),
    ),
  );
}

/// Titular en dos tonos, grueso y apretado, como los títulos del landing.
class _TwoTone extends StatelessWidget {
  const _TwoTone(this.first, this.second, {required this.ink, this.size = 34, this.center = false});
  final String first;
  final String second;
  final _Ink ink;
  final double size;
  final bool center;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      style: TextStyle(fontSize: size, fontWeight: FontWeight.w800, letterSpacing: -0.025 * size, height: 1.04),
      children: [
        TextSpan(
          text: first,
          style: TextStyle(color: ink.strong),
        ),
        TextSpan(
          text: second,
          style: TextStyle(color: ink.accent),
        ),
      ],
    ),
    textAlign: center ? TextAlign.center : TextAlign.start,
  );
}

/// Barra flotante del landing: logo y "PaxFide." en la píldora; la hamburguesa la abre hacia abajo con los enlaces y
/// las acciones (tema, tamaño del texto, Ingresar, Seguir donación, Donar y Escanear).
class _Nav extends StatelessWidget {
  const _Nav({
    required this.ink,
    required this.open,
    required this.onToggle,
    required this.onTop,
    required this.links,
    required this.onLogin,
    required this.onFollow,
    required this.onDonate,
    required this.onScan,
  });
  final _Ink ink;
  final bool open;
  final VoidCallback onToggle;
  final VoidCallback onTop;
  final List<(String, String, VoidCallback)> links;
  final VoidCallback onLogin;
  final VoidCallback onFollow;
  final VoidCallback onDonate;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return PaxGlass(
      key: const Key('welcome.navigation.surface'),
      radius: open ? 24 : 999,
      opacity: open ? 1 : 0.84,
      padding: const EdgeInsets.fromLTRB(6, 4, 4, 4),
      child: AnimatedSize(
        duration: reduced ? Duration.zero : const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 52,
              child: Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Semantics(
                        button: true,
                        label: 'PaxFide, inicio',
                        excludeSemantics: true,
                        child: InkWell(
                          key: const Key('welcome.brand'),
                          borderRadius: BorderRadius.circular(99),
                          onTap: onTop,
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                PaxLogo(size: 34),
                                SizedBox(width: 10),
                                Flexible(
                                  child: FittedBox(fit: BoxFit.scaleDown, child: PaxWordmark()),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('welcome.menu'),
                    tooltip: open ? 'Cerrar menú de navegación' : 'Abrir menú de navegación',
                    color: ink.strong,
                    onPressed: onToggle,
                    icon: AnimatedSwitcher(
                      duration: reduced ? Duration.zero : const Duration(milliseconds: 200),
                      transitionBuilder: (child, a) => RotationTransition(turns: a, child: child),
                      child: Icon(open ? Icons.close : Icons.menu, key: ValueKey(open)),
                    ),
                  ),
                ],
              ),
            ),
            if (open)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (key, label, action) in links)
                      InkWell(
                        key: Key('welcome.menu.$key'),
                        borderRadius: BorderRadius.circular(12),
                        onTap: action,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 44),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                              child: Text(
                                label,
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: ink.body),
                              ),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 6),
                    Divider(height: 1, color: ink.strong.withValues(alpha: 0.12)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text('Tema y tamaño del texto', style: TextStyle(color: ink.body, fontSize: 13)),
                        ),
                        const ThemeModeButton(),
                        const TextSizeButton(),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          key: const Key('welcome.menu.login'),
                          onPressed: onLogin,
                          icon: const Icon(Icons.login, size: 18),
                          label: const Text('Ingresar'),
                        ),
                        OutlinedButton(
                          key: const Key('welcome.menu.follow'),
                          onPressed: onFollow,
                          child: const Text('Seguir donación'),
                        ),
                        FilledButton(
                          key: const Key('welcome.menu.donate'),
                          onPressed: onDonate,
                          child: const Text('Donar'),
                        ),
                        OutlinedButton.icon(
                          key: const Key('welcome.menu.scan'),
                          onPressed: onScan,
                          icon: const Icon(Icons.qr_code_scanner, size: 18),
                          label: const Text('Escanear QR'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// La tarjeta de vidrio de una parada (landing: `.stop .card`).
class _StopCard extends StatelessWidget {
  const _StopCard({super.key, required this.stop, required this.ink, this.extra});
  final _Stop stop;
  final _Ink ink;
  final Widget? extra;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 470),
    child: PaxGlass(
      radius: 24,
      opacity: 0.86,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                stop.label.toUpperCase(),
                style: TextStyle(fontFamily: 'monospace', fontSize: 12, letterSpacing: 0.5, color: ink.step),
              ),
              _Tag(stop.tag, ink: ink),
            ],
          ),
          const SizedBox(height: 14),
          _TwoTone(stop.title, stop.accent, ink: ink, size: extra != null ? 40 : 32),
          const SizedBox(height: 14),
          Text(stop.text, style: TextStyle(fontSize: 16.5, height: 1.6, color: ink.body)),
          if (stop.facts.isNotEmpty) ...[
            const SizedBox(height: 20),
            Divider(height: 1, color: ink.body.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (i, (head, caption)) in stop.facts.indexed) ...[
                  if (i > 0) const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          head,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: ink.strong,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(caption, style: TextStyle(fontSize: 13, height: 1.4, color: ink.body)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
          ?extra,
        ],
      ),
    ),
  );
}

/// "Todo el recorrido": la frase se enciende palabra por palabra al deslizar (landing: `#mani`).
class _Manifesto extends StatelessWidget {
  const _Manifesto({required this.ink, required this.progress});
  final _Ink ink;
  final ValueNotifier<double> progress;

  @override
  Widget build(BuildContext context) {
    final words = _manifesto.split(' ');
    return PaxGlass(
      key: const Key('welcome.overview'),
      radius: 28,
      opacity: 0.82,
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      child: Column(
        children: [
          _Tag('Todo el recorrido', ink: ink),
          const SizedBox(height: 18),
          ValueListenableBuilder<double>(
            valueListenable: progress,
            builder: (context, p, _) {
              final lit = (p * words.length).round();
              return Text.rich(
                TextSpan(
                  style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.75, height: 1.12),
                  children: [
                    for (final (i, w) in words.indexed)
                      TextSpan(
                        text: i == words.length - 1 ? w : '$w ',
                        style: TextStyle(
                          color: i >= lit
                              ? ink.strong.withValues(alpha: 0.2)
                              : (_manifestoHighlight.contains(w) ? ink.accent : ink.strong),
                        ),
                      ),
                  ],
                ),
                textAlign: TextAlign.center,
                semanticsLabel: _manifesto,
              );
            },
          ),
        ],
      ),
    );
  }
}

/// La isla de seguimiento del landing: "¿Ya donaste? Sigue tu donación." y, debajo en el móvil,
/// "¿Eres una organización?". Sin campo ni códigos de ejemplo: el botón lleva a la pantalla real de seguimiento.
class _Island extends StatelessWidget {
  const _Island({required this.ink, required this.onTrack, required this.onRegister});
  final _Ink ink;
  final VoidCallback onTrack;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    Widget point(String text) => Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: ink.tagBg, shape: BoxShape.circle),
            child: Icon(Icons.check, size: 13, color: ink.tagFg),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(color: ink.body, height: 1.4)),
          ),
        ],
      ),
    );
    return PaxGlass(
      radius: 28,
      opacity: 0.88,
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            key: const Key('welcome.trackingCard'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(color: ink.tagBg, borderRadius: BorderRadius.circular(7)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: PaxTokens.brandGreen500,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: PaxTokens.brandGreen500.withValues(alpha: 0.22), spreadRadius: 3)],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'SEGUIMIENTO DE DONACIÓN',
                        style: TextStyle(fontFamily: 'monospace', fontSize: 12, letterSpacing: 0.3, color: ink.tagFg),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _TwoTone('¿Ya donaste? ', 'Sigue tu donación.', ink: ink, size: 32),
              const SizedBox(height: 12),
              Text(
                'Escribe o pega el código que recibiste al donar. Verás en qué punto va y cuándo quedó sellada.',
                style: TextStyle(fontSize: 16, height: 1.55, color: ink.body),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const Key('welcome.tracking.card'),
                  style: FilledButton.styleFrom(
                    backgroundColor: PaxTokens.brandYellow400,
                    foregroundColor: PaxTokens.brandGreen900,
                    minimumSize: const Size(0, 52),
                  ),
                  onPressed: onTrack,
                  child: const Text('Ver recorrido →'),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Tu código es privado: no lo compartas ni lo publiques.',
                style: TextStyle(fontSize: 13, color: ink.body),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Divider(height: 1, color: ink.strong.withValues(alpha: 0.12)),
          const SizedBox(height: 22),
          Column(
            key: const Key('welcome.organizationCard'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: PaxTokens.brandGreen900, borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.home_work_outlined, color: PaxTokens.white),
              ),
              const SizedBox(height: 14),
              Text(
                '¿Eres una organización?',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: ink.strong),
              ),
              const SizedBox(height: 8),
              Text(
                'Crea tu cuenta y registra la organización desde la web de PaxFide. Un administrador la verifica antes de '
                'que publique convocatorias.',
                style: TextStyle(height: 1.5, color: ink.body),
              ),
              point('Convocatorias con meta y fechas'),
              point('Lotes con QR y recorrido visible'),
              point('Historial que se puede verificar'),
              const SizedBox(height: 18),
              OutlinedButton(
                key: const Key('welcome.organization'),
                onPressed: onRegister,
                child: const Text('Crear mi cuenta →'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Tarjeta de convocatoria del landing (variante 12) con datos reales de
/// `GET /public/campaigns`: portada (si la hay), logo con iniciales de reserva, sello de verificación (si está
/// verificada), título, fechas, recaudado y meta.
class _CampaignCard extends StatelessWidget {
  const _CampaignCard(this.c, {super.key, required this.ink, required this.onOpen, this.detailsKey});
  final CampaignSummary c;
  final _Ink ink;
  final VoidCallback onOpen;
  final Key? detailsKey;

  @override
  Widget build(BuildContext context) {
    final target = int.tryParse(c.targetAmount ?? '');
    final cleared = int.tryParse(c.clearedAmount ?? '');
    final p = CampaignProgress.of(target: target, cleared: cleared, endDate: c.endDate);
    final closed = c.status.isNotEmpty && c.status != 'OPEN';
    final baseUrl = AppScope.maybeOf(context)?.config.apiBaseUrl;
    final coverUrl = resolveApiMediaUrl(baseUrl, c.coverImageUrl);
    final logoUrl = resolveApiMediaUrl(baseUrl, c.organizationLogoUrl);

    Widget header() {
      final statusBadge = Positioned(
        left: 12,
        top: 12,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: PaxTokens.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: PaxTokens.white.withValues(alpha: 0.3)),
          ),
          child: Text(
            closed ? 'Cerrada' : (p.reached ? 'Meta alcanzada' : 'Convocatoria abierta'),
            style: const TextStyle(color: PaxTokens.white, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
      );

      if (coverUrl != null) {
        return Stack(
          children: [
            CampaignCoverImage(coverUrl: coverUrl),
            statusBadge,
          ],
        );
      }

      return SizedBox(
        height: 132,
        child: Stack(
          children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [PaxTokens.brandGreen800, PaxTokens.brandGreen900],
                  ),
                ),
              ),
            ),
            const Positioned(right: 16, top: 10, bottom: 6, width: 150, child: CrateArt()),
            statusBadge,
          ],
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Material(
        color: ink.dark ? PaxDarkTokens.surface : PaxTokens.white,
        child: InkWell(
          onTap: onOpen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (c.startDate.isNotEmpty || c.endDate.isNotEmpty)
                      Text(
                        [
                          if (c.startDate.isNotEmpty) shortDate(c.startDate),
                          if (c.endDate.isNotEmpty) shortDate(c.endDate),
                        ].join(' — '),
                        style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: ink.body),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      c.title,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: ink.strong,
                      ),
                    ),
                    if (c.organizationName.isNotEmpty || c.organizationVerified) ...[
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          OrganizationLogo(organizationName: c.organizationName, logoUrl: logoUrl, size: 32),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (c.organizationName.isNotEmpty)
                                  Text(c.organizationName, style: TextStyle(color: ink.body)),
                                if (c.organizationVerified) ...[
                                  const SizedBox(height: 2),
                                  const OrganizationVerifiedBadge(),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    if (cleared != null && target != null)
                      Text.rich(
                        TextSpan(
                          style: TextStyle(fontFamily: 'monospace', fontSize: 13, color: ink.body),
                          children: [
                            TextSpan(
                              text: formatMinorUnits(cleared, c.currency),
                              style: TextStyle(fontWeight: FontWeight.w700, color: ink.strong),
                            ),
                            TextSpan(text: ' de ${formatMinorUnits(target, c.currency)}'),
                          ],
                        ),
                      )
                    else
                      Text('Sin meta en dinero', style: TextStyle(color: ink.body)),
                    if (p.fraction != null) ...[
                      const SizedBox(height: 8),
                      SlimProgress(p.fraction!, semanticsLabel: p.percentText),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      [if (p.percentText != null) p.percentText!, if (p.daysText != null) p.daysText!].join(' · '),
                      style: TextStyle(fontSize: 13, color: ink.accent, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(onPressed: closed ? null : onOpen, child: const Text('Donar')),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(key: detailsKey, onPressed: onOpen, child: const Text('Ver detalles')),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
