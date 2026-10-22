import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../app/app_services.dart';
import '../../../app/qr_scanner_sheet.dart';
import '../../../app/text_size_button.dart';
import '../../../app/theme_mode_button.dart';
import '../../../shared/dates.dart';
import '../../../shared/money.dart';
import '../../../shared/theme/pax_theme.dart';
import '../../../shared/theme/pax_tokens.dart';
import '../../../shared/widgets/pax_logo.dart';
import '../../../shared/widgets/pax_ui.dart';
import '../../campaigns/domain/campaign_progress.dart';
import '../../campaigns/domain/campaign_search.dart';
import '../../campaigns/presentation/campaign_search_view.dart';
import '../../campaigns/presentation/campaign_summary_card.dart';
import 'welcome_scene.dart';

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
  Color get tagFg => dark ? PaxTokens.brandGreen50 : PaxTokens.brandGreen900;
  Color get glass => dark ? PaxDarkTokens.surface.withValues(alpha: 0.84) : PaxTokens.white.withValues(alpha: 0.84);
  Color get glassEdge => dark ? PaxDarkTokens.neutral.withValues(alpha: 0.18) : PaxTokens.white.withValues(alpha: 0.7);
}

/// Una parada del recorrido (landing, "Desliza y acompaña su recorrido").
class _Stop {
  const _Stop({
    required this.scene,
    required this.label,
    required this.tag,
    required this.title,
    required this.accent,
    required this.text,
    this.facts = const [],
  });
  final WelcomeScene scene;
  final String label;
  final String tag;
  final String title;
  final String accent;
  final String text;
  final List<(String, String)> facts;
}

/// Pasos 04 y 05: redactados con lo que dice la documentación (ADR-039: huellas encadenadas, agrupadas y ancladas en
/// una red pública; los campos de referencia nunca piden nombres). PENDIENTES DE CONFIRMAR por el equipo.
const _stops = [
  _Stop(
    scene: WelcomeScene.donate,
    label: '01 / 05 · Donas',
    tag: 'Pago confirmado',
    title: 'Tu donación, ',
    accent: 'de principio a fin.',
    text:
        'Pagas por la pasarela. Cuando el pago se confirma, se abre el historial de tu donación y recibes un código '
        'para seguirla paso a paso.',
  ),
  _Stop(
    scene: WelcomeScene.warehouse,
    label: '02 / 05 · Se convierte en ayuda',
    tag: 'Fondos asignados → lote registrado',
    title: 'De saldo a ',
    accent: 'cajas reales.',
    text:
        'La organización compra los insumos y registra cada lote en la bodega. El dinero asignado y el lote quedan '
        'conectados, y cada lote recibe su propio QR.',
    facts: [('1 QR', 'por lote, no por cada unidad'), ('Fondos → lote', 'quedan conectados')],
  ),
  _Stop(
    scene: WelcomeScene.route,
    label: '03 / 05 · Viaja y se reparte',
    tag: 'Lote despachado · lote dividido',
    title: 'Sigue la caja, ',
    accent: 'aunque se divida.',
    text:
        'Cada despacho y cada recepción se registran al escanear el QR. Si el lote se reparte entre dos destinos, '
        'cada parte conserva el vínculo con su origen.',
    facts: [('Lote dividido', 'cada parte conserva su origen'), ('Puntos de control', 'solo paradas oficiales')],
  ),
  _Stop(
    scene: WelcomeScene.seal,
    label: '04 / 05 · Queda sellado',
    tag: 'Lote sellado · registro público',
    title: 'Una huella que ',
    accent: 'se puede comprobar.',
    text:
        'Cada registro lleva una huella digital encadenada a la anterior. Por lotes, esas huellas se resumen en una '
        'sola y se anclan en una red blockchain pública para poder verificarlas.',
    facts: [('Huella digital', 'en cada registro'), ('Red pública', 'donde se ancla la raíz')],
  ),
  _Stop(
    scene: WelcomeScene.delivery,
    label: '05 / 05 · Llega',
    tag: 'Entrega confirmada',
    title: 'Entregado, ',
    accent: 'y lo puedes comprobar.',
    text:
        'La entrega se registra con referencias, sin el nombre de quien recibe. Con tu código ves el recorrido '
        'completo, desde el pago hasta la comunidad.',
    facts: [('Sin nombres', 'de quien recibe'), ('5 de 5', 'pasos registrados')],
  ),
];

/// Momento del día de cada parada, como el landing: de día, atardecer, noche y vuelve a amanecer. En modo oscuro,
/// todo de noche.
DayTime _timeOf(int i, bool dark) =>
    dark ? DayTime.night : const [DayTime.day, DayTime.day, DayTime.dusk, DayTime.night, DayTime.day][i];

/// `/welcome`: bienvenida sin sesión (M-01/M-02), la adaptación del landing web (Enmienda 3 de ADR-043). Primera
/// pantalla sin sesión y base de la pila con LOGGED_OUT.
///
/// Fiel al landing: barra flotante en píldora, el recorrido en cinco paradas ilustradas con su tarjeta translúcida,
/// "Todo el recorrido", seguimiento, organizaciones y catálogo. Sin datos de ejemplo presentados como reales y sin
/// campo de código: el código de seguimiento solo se escribe en `/tracking`.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  late final AppServices _services = AppScope.of(context);
  final _howKey = GlobalKey();
  final _verifyKey = GlobalKey();
  final _trackingKey = GlobalKey();
  final _catalogKey = GlobalKey();
  late Future<List<CampaignSummary>> _campaigns = _fetch();

  Future<List<CampaignSummary>> _fetch() => _services.campaignSearch.search(const CampaignQuery());

  void _scrollTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return;
    final animate = !MediaQuery.disableAnimationsOf(context);
    Scrollable.ensureVisible(
      ctx,
      duration: animate ? const Duration(milliseconds: 450) : Duration.zero,
      curve: Curves.easeOutCubic,
      alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
      alignment: 0.08,
    );
  }

  void _openAll() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (page) => Scaffold(
        appBar: AppBar(title: const Text('Convocatorias')),
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

  Future<void> _menu() async {
    final ink = _Ink(Theme.of(context).brightness == Brightness.dark);
    final go = await showModalBottomSheet<VoidCallback>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheet) {
        Widget item(String key, IconData icon, String label, VoidCallback action) => ListTile(
          key: Key('welcome.menu.$key'),
          leading: Icon(icon),
          title: Text(label),
          onTap: () => Navigator.of(sheet).pop(action),
        );
        return ListView(
          shrinkWrap: true,
          children: [
            item('how', Icons.route_outlined, 'Cómo funciona', () => _scrollTo(_howKey)),
            item('verify', Icons.verified_user_outlined, 'Verificación', () => _scrollTo(_verifyKey)),
            item('campaigns', Icons.campaign_outlined, 'Convocatorias', () => _scrollTo(_catalogKey)),
            item('tracking', Icons.pin_outlined, 'Seguimiento', () => _scrollTo(_trackingKey)),
            const Divider(),
            item('scan', Icons.qr_code_scanner, 'Escanear un código QR', () => scanQr(context)),
            item('follow', Icons.search, 'Seguir donación', () => _services.router.push(AppRoutes.tracking)),
            item('login', Icons.login, 'Ingresar', () => _services.router.push(AppRoutes.login)),
            ListTile(
              leading: const Icon(Icons.format_size),
              title: const Text('Tamaño del texto'),
              trailing: const TextSizeButton(),
              textColor: ink.strong,
            ),
          ],
        );
      },
    );
    go?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = PaxTheme.welcome(Theme.of(context));
    final dark = theme.brightness == Brightness.dark;
    final ink = _Ink(dark);
    final top = MediaQuery.paddingOf(context).top;
    return Theme(
      data: theme,
      child: Scaffold(
        backgroundColor: ScenePalette.of(dark ? DayTime.night : DayTime.day).terrain,
        extendBody: true,
        body: Stack(
          children: [
            SingleChildScrollView(
              key: const Key('welcome.list'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, stop) in _stops.indexed)
                    KeyedSubtree(
                      key: i == 0 ? _howKey : (i == 3 ? _verifyKey : null),
                      child: _StopView(
                        key: Key('welcome.step.${i + 1}'),
                        stop: stop,
                        time: _timeOf(i, dark),
                        from: i == 0 ? null : _timeOf(i - 1, dark),
                        sceneHeight: i == 0 ? 250 + top : 280,
                        ink: ink,
                        extra: i == 0 ? _heroActions(ink) : null,
                      ),
                    ),
                  _OverviewView(ink: ink, from: _timeOf(4, dark), time: dark ? DayTime.night : DayTime.day),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        KeyedSubtree(
                          key: _trackingKey,
                          child: _TrackingCard(ink: ink, onOpen: () => _services.router.push(AppRoutes.tracking)),
                        ),
                        const SizedBox(height: 16),
                        _OrganizationCard(ink: ink, onOpen: () => _services.router.push(AppRoutes.register)),
                        const SizedBox(height: 36),
                        KeyedSubtree(key: _catalogKey, child: _catalogHeader(theme, ink)),
                        const SizedBox(height: 12),
                        _catalog(ink),
                        const SizedBox(height: 28),
                        Text(
                          'PaxFide · plataforma de trazabilidad de donaciones',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: ink.strong.withValues(alpha: 0.75)),
                        ),
                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              top: top + 8,
              child: _NavPill(ink: ink, onMenu: _menu),
            ),
          ],
        ),
        // M-02: "Ingresar" fijo, al alcance del pulgar, sobre una píldora translúcida.
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: _Glass(
            ink: ink,
            radius: 99,
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    button: true,
                    label: 'Seguir donación',
                    excludeSemantics: true,
                    child: OutlinedButton(
                      key: const Key('welcome.bar.tracking'),
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
                      onPressed: () => _services.router.push(AppRoutes.tracking),
                      child: const Text('Seguir donación', overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Semantics(
                    button: true,
                    label: 'Ingresar',
                    excludeSemantics: true,
                    child: FilledButton(
                      key: const Key('welcome.login'),
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
                      onPressed: () => _services.router.push(AppRoutes.login),
                      child: const Text('Ingresar'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Botones de la primera parada, como en el landing, más Escanear (M-01).
  Widget _heroActions(_Ink ink) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 18),
      Semantics(
        button: true,
        label: 'Donar a una convocatoria',
        excludeSemantics: true,
        child: FilledButton(
          key: const Key('welcome.donate'),
          onPressed: () => _scrollTo(_catalogKey),
          child: const Text('Donar a una convocatoria'),
        ),
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          Semantics(
            button: true,
            label: 'Seguir mi donación',
            excludeSemantics: true,
            child: OutlinedButton(
              key: const Key('welcome.tracking'),
              onPressed: () => _services.router.push(AppRoutes.tracking),
              child: const Text('Seguir mi donación'),
            ),
          ),
          Semantics(
            button: true,
            label: 'Escanear un código QR',
            excludeSemantics: true,
            child: OutlinedButton.icon(
              key: const Key('welcome.scan'),
              onPressed: () => scanQr(context),
              icon: const Icon(Icons.qr_code_scanner, size: 18),
              label: const Text('Escanear QR'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Container(
            width: 18,
            height: 28,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ink.body.withValues(alpha: 0.6), width: 2),
            ),
            alignment: const Alignment(0, -0.5),
            child: Container(width: 3, height: 6, color: ink.body.withValues(alpha: 0.6)),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text('Desliza y acompaña su recorrido', style: TextStyle(color: ink.body)),
          ),
        ],
      ),
    ],
  );

  Widget _catalogHeader(ThemeData theme, _Ink ink) => _Glass(
    ink: ink,
    child: Column(
      children: [
        _Tag('Catálogo oficial de convocatorias', ink: ink),
        const SizedBox(height: 12),
        _TwoTone('Causas abiertas con ', 'trazabilidad garantizada', ink: ink, center: true, size: 30),
        const SizedBox(height: 10),
        Text(
          'Explora las convocatorias abiertas. Cada donación queda registrada y puedes seguirla hasta su entrega.',
          textAlign: TextAlign.center,
          style: TextStyle(color: ink.body, height: 1.4),
        ),
        const SizedBox(height: 8),
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
        return _Glass(
          key: const Key('welcome.campaigns.error'),
          ink: ink,
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
        return _Glass(
          key: const Key('welcome.campaigns.empty'),
          ink: ink,
          child: Text('No hay convocatorias abiertas en este momento.', style: TextStyle(color: ink.strong)),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final c in items.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
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

/// Tarjeta translúcida (vidrio esmerilado) sobre la escena.
class _Glass extends StatelessWidget {
  const _Glass({super.key, required this.ink, required this.child, this.radius = 26, this.padding});
  final _Ink ink;
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
      child: Container(
        padding: padding ?? const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: ink.glass,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: ink.glassEdge),
        ),
        child: child,
      ),
    ),
  );
}

/// Etiqueta en mono y mayúsculas dentro de una píldora ("PAGO CONFIRMADO").
class _Tag extends StatelessWidget {
  const _Tag(this.text, {required this.ink});
  final String text;
  final _Ink ink;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(color: ink.tagBg, borderRadius: BorderRadius.circular(8)),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(fontFamily: 'monospace', fontSize: 12, letterSpacing: 0.8, color: ink.tagFg),
    ),
  );
}

/// Titular en dos tonos, grueso y apretado, como los títulos del landing.
class _TwoTone extends StatelessWidget {
  const _TwoTone(this.first, this.second, {required this.ink, this.size = 32, this.center = false});
  final String first;
  final String second;
  final _Ink ink;
  final double size;
  final bool center;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      style: TextStyle(fontSize: size, fontWeight: FontWeight.w800, letterSpacing: -0.9, height: 1.08),
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

/// Barra flotante en píldora: logo, "PaxFide." en tres colores, tema y menú.
class _NavPill extends StatelessWidget {
  const _NavPill({required this.ink, required this.onMenu});
  final _Ink ink;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) => _Glass(
    ink: ink,
    radius: 99,
    padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
    child: Row(
      children: [
        const PaxLogo(size: 34),
        const SizedBox(width: 10),
        Expanded(
          child: Text.rich(
            TextSpan(
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.6),
              children: [
                TextSpan(
                  text: 'Pax',
                  style: TextStyle(color: ink.strong),
                ),
                TextSpan(
                  text: 'Fide',
                  style: TextStyle(color: ink.dark ? PaxDarkTokens.blue : PaxTokens.brandBlue700),
                ),
                const TextSpan(
                  text: '.',
                  style: TextStyle(color: PaxTokens.brandYellow400),
                ),
              ],
            ),
            semanticsLabel: 'PaxFide',
          ),
        ),
        const ThemeModeButton(),
        IconButton(key: const Key('welcome.menu'), tooltip: 'Menú', icon: const Icon(Icons.menu), onPressed: onMenu),
      ],
    ),
  );
}

/// Una parada: la escena arriba y la tarjeta translúcida montada sobre su parte baja.
class _StopView extends StatelessWidget {
  const _StopView({
    super.key,
    required this.stop,
    required this.time,
    required this.from,
    required this.sceneHeight,
    required this.ink,
    this.extra,
  });
  final _Stop stop;
  final DayTime time;
  final DayTime? from;
  final double sceneHeight;
  final _Ink ink;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    // La tinta de la tarjeta sigue al modo de la app; la escena, al momento del día.
    return Stack(
      children: [
        Positioned.fill(
          child: WelcomeSceneView(scene: stop.scene, time: time, from: from),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, sceneHeight, 16, 28),
          child: _Glass(
            ink: ink,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stop.label.toUpperCase(),
                  style: TextStyle(fontFamily: 'monospace', fontSize: 12, letterSpacing: 0.8, color: ink.step),
                ),
                const SizedBox(height: 10),
                _Tag(stop.tag, ink: ink),
                const SizedBox(height: 14),
                _TwoTone(stop.title, stop.accent, ink: ink),
                const SizedBox(height: 12),
                Text(stop.text, style: TextStyle(fontSize: 16, height: 1.5, color: ink.body)),
                if (stop.facts.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Divider(color: ink.body.withValues(alpha: 0.2)),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final (head, caption) in stop.facts)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  head,
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: ink.strong,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(caption, style: TextStyle(fontSize: 13, color: ink.body)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
                ?extra,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// "Todo el recorrido": el mapa completo con la frase central.
class _OverviewView extends StatelessWidget {
  const _OverviewView({required this.ink, required this.from, required this.time});
  final _Ink ink;
  final DayTime from;
  final DayTime time;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(
        child: WelcomeSceneView(scene: WelcomeScene.overview, time: time, from: from),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 230, 16, 28),
        child: _Glass(
          key: const Key('welcome.overview'),
          ink: ink,
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 30),
          child: Column(
            children: [
              Text(
                'TODO EL RECORRIDO',
                style: TextStyle(fontFamily: 'monospace', fontSize: 12, letterSpacing: 1, color: ink.body),
              ),
              const SizedBox(height: 14),
              Text.rich(
                TextSpan(
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.8, height: 1.12),
                  children: [
                    TextSpan(
                      text: 'Cada paso queda ',
                      style: TextStyle(color: ink.strong),
                    ),
                    TextSpan(
                      text: 'registrado',
                      style: TextStyle(color: ink.accent),
                    ),
                    TextSpan(
                      text: '. Y tú lo puedes ',
                      style: TextStyle(color: ink.strong),
                    ),
                    TextSpan(
                      text: 'comprobar',
                      style: TextStyle(color: ink.accent),
                    ),
                    TextSpan(
                      text: ' cuando quieras.',
                      style: TextStyle(color: ink.strong.withValues(alpha: 0.45)),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

/// "¿Ya donaste? Sigue tu donación." Lleva a la pantalla real de seguimiento: sin campo ni códigos de ejemplo.
class _TrackingCard extends StatelessWidget {
  const _TrackingCard({required this.ink, required this.onOpen});
  final _Ink ink;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => _Glass(
    key: const Key('welcome.trackingCard'),
    ink: ink,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: ink.accent, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              'SEGUIMIENTO DE DONACIÓN',
              style: TextStyle(fontFamily: 'monospace', fontSize: 12, letterSpacing: 0.8, color: ink.strong),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _TwoTone('¿Ya donaste?\n', 'Sigue tu donación.', ink: ink, size: 30),
        const SizedBox(height: 10),
        Text(
          'Escribe o pega el código que recibiste al donar. Verás en qué punto va y cuándo quedó sellada.',
          style: TextStyle(fontSize: 16, height: 1.5, color: ink.body),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: Semantics(
            button: true,
            label: 'Ver recorrido',
            excludeSemantics: true,
            child: FilledButton(
              key: const Key('welcome.tracking.card'),
              style: FilledButton.styleFrom(
                backgroundColor: PaxTokens.brandYellow400,
                foregroundColor: PaxTokens.brandGreen900,
                minimumSize: const Size(0, 52),
              ),
              onPressed: onOpen,
              child: const Text('Ver recorrido →'),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text('Tu código es privado: no lo compartas ni lo publiques.', style: TextStyle(fontSize: 13, color: ink.body)),
      ],
    ),
  );
}

/// "¿Eres una organización?" En el móvil se crea la cuenta; la organización se registra y se verifica desde la web
/// (decisión 4: en el móvil solo se registran donantes).
class _OrganizationCard extends StatelessWidget {
  const _OrganizationCard({required this.ink, required this.onOpen});
  final _Ink ink;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    Widget point(String text) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check, size: 18, color: ink.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(color: ink.body)),
          ),
        ],
      ),
    );
    return _Glass(
      key: const Key('welcome.organizationCard'),
      ink: ink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: PaxTokens.brandGreen900, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.account_balance_outlined, color: PaxTokens.white),
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
            style: TextStyle(height: 1.45, color: ink.body),
          ),
          point('Convocatorias con meta y fechas'),
          point('Lotes con QR y recorrido visible'),
          point('Historial que se puede verificar'),
          const SizedBox(height: 16),
          Semantics(
            button: true,
            label: 'Crear mi cuenta',
            excludeSemantics: true,
            child: OutlinedButton(
              key: const Key('welcome.organization'),
              onPressed: onOpen,
              child: const Text('Crear mi cuenta →'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta de convocatoria del landing (variante 12, sin foto: portada ilustrada) con datos reales de
/// `GET /public/campaigns`: título, organización, fechas, recaudado y meta. Sin categorías, donantes ni insignias que
/// el contrato no trae.
class _CampaignCard extends StatelessWidget {
  const _CampaignCard(this.c, {super.key, required this.ink, required this.onOpen, this.detailsKey});
  final CampaignSummary c;
  final _Ink ink;
  final VoidCallback onOpen;
  final Key? detailsKey;

  @override
  Widget build(BuildContext context) {
    final p = CampaignProgress.of(
      target: int.tryParse(c.targetAmount ?? ''),
      cleared: int.tryParse(c.clearedAmount ?? ''),
      endDate: c.endDate,
    );
    final target = int.tryParse(c.targetAmount ?? '');
    final cleared = int.tryParse(c.clearedAmount ?? '');
    final closed = c.status.isNotEmpty && c.status != 'OPEN';
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Material(
        color: ink.dark ? PaxDarkTokens.surface : PaxTokens.white,
        child: InkWell(
          onTap: onOpen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 120,
                child: Stack(
                  children: [
                    const Positioned.fill(child: _CampaignCover()),
                    Positioned(
                      left: 12,
                      top: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: PaxTokens.brandGreen900.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          closed ? 'Cerrada' : (p.reached ? 'Meta alcanzada' : 'Convocatoria abierta'),
                          style: const TextStyle(color: PaxTokens.white, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
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
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: ink.strong,
                      ),
                    ),
                    if (c.organizationName.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(c.organizationName, style: TextStyle(color: ink.body)),
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
                        TextButton(key: detailsKey, onPressed: onOpen, child: const Text('Ver detalles')),
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

/// Portada ilustrada de una convocatoria sin foto: cajas isométricas sobre fondo verde (paleta).
class _CampaignCover extends StatelessWidget {
  const _CampaignCover();

  @override
  Widget build(BuildContext context) => const ExcludeSemantics(
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [PaxTokens.brandGreen800, PaxTokens.brandGreen900],
        ),
      ),
      child: Align(
        alignment: Alignment(0.75, 0.3),
        child: SizedBox(
          width: 140,
          height: 110,
          child: WelcomeSceneView(scene: WelcomeScene.overview, time: DayTime.night),
        ),
      ),
    ),
  );
}
