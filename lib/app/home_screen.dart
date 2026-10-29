import 'package:flutter/material.dart';

import '../core/errors/app_exceptions.dart';
import '../core/offline/outbox_status.dart';
import '../features/account/data/account_api.dart';
import '../features/account/presentation/first_steps_screen.dart';
import '../features/auth/domain/session_controller.dart';
import '../features/campaigns/domain/campaign_search.dart';
import '../features/campaigns/presentation/campaign_search_view.dart';
import '../features/campaigns/presentation/campaign_summary_card.dart';
import '../features/donations/data/account_donations_api.dart';
import '../features/donations/presentation/my_donations_screen.dart';
import '../features/tracking/presentation/tracking_screen.dart';
import '../shared/city/city_background.dart';
import '../shared/city/city_pause_controller.dart';
import '../shared/city/city_scene.dart';
import '../shared/dates.dart';
import '../shared/money.dart';
import '../shared/motion/pax_motion.dart';
import '../shared/motion/pax_route.dart';
import '../shared/theme/pax_theme.dart';
import '../shared/theme/pax_tokens.dart';
import '../shared/widgets/loaders.dart';
import '../shared/widgets/pax_app_bar.dart';
import 'app_routes.dart';
import 'app_services.dart';
import 'app_shell.dart';
import 'qr_scanner_sheet.dart';

/// Cuántas donaciones y convocatorias muestra cada tarjeta; el resto, en su pantalla (web: `HOME_ITEMS`).
const homeItems = 3;

/// Saludo por la hora del teléfono (web: `greetingFor`).
String greetingFor(int hour) => hour < 12 ? 'Buenos días' : (hour < 19 ? 'Buenas tardes' : 'Buenas noches');

/// Abierta y cierra en 7 días o menos (web: `isClosingSoon`).
bool isClosingSoon(CampaignSummary c, DateTime now) {
  if (c.status != 'OPEN') return false;
  final end = DateTime.tryParse(c.endDate);
  if (end == null) return false;
  final left = end.difference(now);
  return !left.isNegative && left <= const Duration(days: 7);
}

/// `/home`, como el Inicio de la web (`HomeScreen.tsx`, `paxfide-home.html`) en el teléfono: saludo con el nombre,
/// aviso para completar el perfil, «Seguir una donación», «Sellado en blockchain», las convocatorias (primero las que
/// cierran pronto) y «Tus donaciones». Del panel de la organización solo queda lo del operador de campo
/// (Operaciones) y la Predicción, que es la excepción del ADR-043. Las tarjetas entran escalonadas.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.now});

  /// Reloj de las pruebas (saludo y «Cierran pronto»).
  final DateTime Function()? now;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final AppServices _services = AppScope.of(context);
  final _donationsKey = GlobalKey<_DonationsCardState>();
  final _campaignsKey = GlobalKey<_CampaignsCardState>();
  AccountProfile? _profile;
  bool _profileLoaded = false;
  bool _nudgeHidden = false;
  bool _wasCurrent = false;

  /// Alto de la franja de la ciudad que se ve sobre el contenido.
  static const _cityBand = 220.0;
  final _scroll = ScrollController();

  /// La ciudad se mueve solo mientras se ve: al desplazar Inicio hasta taparla, se queda quieta.
  final _cityVisible = ValueNotifier(true);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() => _cityVisible.value = _scroll.offset < _cityBand - 8);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _cityVisible.dispose();
    super.dispose();
  }

  DateTime get _now => (widget.now ?? DateTime.now)();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Al volver a Inicio (desde Cuenta, por ejemplo) se relee el perfil: el saludo lleva el nombre recién puesto.
    final current = ModalRoute.of(context)?.isCurrent ?? true;
    if (current && !_wasCurrent) _loadProfile();
    _wasCurrent = current;
    // Primera vez tras crear la cuenta: la bienvenida y «¿Cómo te llamamos?» (web: `justRegistered`).
    if (current && _services.session.consumeJustRegistered()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context)
            .push(PaxPageRoute<void>(fullscreenDialog: true, builder: (_) => const FirstStepsScreen()));
      });
    }
  }

  Future<void> _loadProfile() async {
    try {
      final p = await AccountApi(_services.apiClient).profile();
      if (mounted) {
        setState(() {
          _profile = p;
          _profileLoaded = true;
        });
      }
    } on AppException {
      // Sin perfil: saludo sin nombre y sin aviso (no se sabe si falta el nombre).
    }
  }

  Future<void> _refresh() async {
    await Future.wait([_loadProfile(), ?_donationsKey.currentState?.reload(), ?_campaignsKey.currentState?.reload()]);
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      location: AppRoutes.home,
      title: 'Inicio',
      body: ListenableBuilder(
        listenable: _services.session,
        builder: (context, _) {
          final p = _services.session.principal;
          final given = _profile?.givenName;
          var i = 0;
          final cards = <Widget>[
            // El operador de campo ve primero su trabajo.
            if (p?.showsOperatorActions ?? false) const _OperationsCard(),
            const _TrackCard(),
            const _SealCard(),
            if (p?.showsPrediction ?? false) const _PredictionCard(),
            _CampaignsCard(key: _campaignsKey, now: _now),
            _DonationsCard(key: _donationsKey),
          ];
          final page = PaxTheme.pageBackground(Theme.of(context).colorScheme);
          return Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: _cityBand + 24,
                child: CityBackground(paused: _services.cityPause, visible: _cityVisible),
              ),
              RefreshIndicator(
                onRefresh: _refresh,
                child: CustomScrollView(
                  controller: _scroll,
                  slivers: [
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: _cityBand,
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: _CityHud(pause: _services.cityPause),
                          ),
                        ),
                      ),
                    ),
                    // El contenido sube como una hoja sobre la ciudad.
                    DecoratedSliver(
                      decoration: BoxDecoration(
                        color: page,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      sliver: SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                        sliver: SliverList.list(
                          children: [
                            if (_services.session.profileStatus == ProfileStatus.loading)
                              const LinearProgressIndicator(),
                            _Header(
                              greeting: greetingFor(_now.hour),
                              givenName: given,
                              familyName: _profile?.familyName,
                            ),
                            if (_profileLoaded && (given == null || given.isEmpty) && !_nudgeHidden) ...[
                              const SizedBox(height: 16),
                              _ProfileNudge(
                                onAdd: () => _services.router.go(AppRoutes.account),
                                onHide: () => setState(() => _nudgeHidden = true),
                              ),
                            ],
                            for (final c in cards) ...[const SizedBox(height: 16), RiseIn(index: i++, child: c)],
                          ],
                        ),
                      ),
                    ),
                    SliverFillRemaining(hasScrollBody: false, child: ColoredBox(color: page)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Dónde está la cámara de la ciudad (web: `CityHud`) y el botón para pausarla (web: `PauseButton`).
class _CityHud extends StatelessWidget {
  const _CityHud({required this.pause});
  final CityPauseController pause;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme.labelMedium?.copyWith(color: s.onSurface);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: s.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: s.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(color: PaxTokens.brandGreen500, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'Sector: '),
                    TextSpan(
                      text: District.home.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(
                      text: ' · ${District.home.type}',
                      style: TextStyle(color: s.onSurfaceVariant),
                    ),
                  ],
                ),
                style: text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: pause,
              builder: (context, paused, _) => IconButton(
                key: const Key('home.city.pause'),
                visualDensity: VisualDensity.compact,
                tooltip: paused ? 'Reanudar la animación' : 'Pausar la animación',
                onPressed: pause.toggle,
                icon: Icon(paused ? Icons.play_arrow_rounded : Icons.pause_rounded, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Avatar con las iniciales (o el de persona) y el saludo.
class _Header extends StatelessWidget {
  const _Header({required this.greeting, this.givenName, this.familyName});
  final String greeting;
  final String? givenName;
  final String? familyName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final first = givenName?.trim().characters.firstOrNull;
    final last = familyName?.trim().characters.firstOrNull ?? '';
    final fg = dark ? PaxDarkTokens.green : PaxTokens.brandGreen800;
    return Row(
      children: [
        Container(
          key: const Key('home.avatar'),
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: dark ? PaxTokens.brandGreen900 : PaxTokens.brandGreen50,
          ),
          child: first == null
              ? Icon(Icons.person_outline, color: fg)
              : Text(
                  '$first$last'.toUpperCase(),
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: fg),
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                givenName == null || givenName!.isEmpty ? greeting : '$greeting, $givenName',
                key: const Key('home.greeting'),
                style: theme.textTheme.headlineSmall?.copyWith(height: 1.15),
              ),
              const SizedBox(height: 4),
              Text(
                'Qué bueno verte por aquí.',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// «Completa tu perfil» (azul informativo, como la web).
class _ProfileNudge extends StatelessWidget {
  const _ProfileNudge({required this.onAdd, required this.onHide});
  final VoidCallback onAdd;
  final VoidCallback onHide;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Container(
      key: const Key('home.profileNudge'),
      padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
      decoration: BoxDecoration(color: s.secondaryContainer, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(Icons.person_outline, color: s.onSecondaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Completa tu perfil',
                  style: TextStyle(fontWeight: FontWeight.w600, color: s.onSecondaryContainer),
                ),
                Text(
                  'Agrega tu nombre para que te saludemos como se debe.',
                  style: TextStyle(color: s.onSecondaryContainer),
                ),
              ],
            ),
          ),
          TextButton(key: const Key('home.profileNudge.add'), onPressed: onAdd, child: const Text('Agregar')),
          IconButton(
            key: const Key('home.profileNudge.hide'),
            tooltip: 'Ocultar aviso',
            onPressed: onHide,
            icon: Icon(Icons.close, size: 18, color: s.onSecondaryContainer),
          ),
        ],
      ),
    );
  }
}

/// Título de tarjeta con su icono (web: `.cardTitle`), y «Ver todas» a la derecha si hay [action].
class _CardHead extends StatelessWidget {
  const _CardHead({required this.icon, required this.title, this.action, this.color, this.iconColor});
  final IconData icon;
  final String title;
  final Widget? action;
  final Color? color;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 22, color: iconColor ?? theme.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(title, style: theme.textTheme.titleMedium?.copyWith(color: color)),
        ),
        ?action,
      ],
    );
  }
}

/// Tarjeta con el estilo de las de Inicio (radio 12, borde fino, relleno 20).
class _HomeCard extends StatelessWidget {
  const _HomeCard({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    ),
  );
}

// ------------------------------------------------------------------------------------------- Seguir una donación

/// La tarjeta destacada en verde: escribir el código y ver la ruta. El código viaja en memoria hasta el seguimiento,
/// nunca en una ruta (DW-16).
class _TrackCard extends StatefulWidget {
  const _TrackCard();

  @override
  State<_TrackCard> createState() => _TrackCardState();
}

class _TrackCardState extends State<_TrackCard> {
  final _code = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _code.text.trim();
    if (value.isEmpty) {
      setState(() => _error = 'Este campo es obligatorio.');
      return;
    }
    FocusScope.of(context).unfocus();
    _code.clear();
    Navigator.of(context).push(PaxPageRoute<void>(builder: (_) => TrackingScreen(initialCode: value)));
  }

  @override
  Widget build(BuildContext context) {
    const white = PaxTokens.white;
    final soft = white.withValues(alpha: 0.84);
    final field = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: white.withValues(alpha: 0.5)),
    );
    return Container(
      key: const Key('home.track'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [PaxTokens.brandGreen900, PaxTokens.brandGreen800],
        ),
        boxShadow: [
          BoxShadow(
            color: PaxTokens.brandGreen900.withValues(alpha: 0.22),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        children: [
          // El círculo amarillo de la esquina (web: `.hero::after`).
          Positioned(
            right: -60,
            top: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: PaxTokens.brandYellow400.withValues(alpha: 0.16),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _CardHead(
                  icon: Icons.route_outlined,
                  title: 'Seguir una donación',
                  color: white,
                  iconColor: PaxTokens.brandYellow400,
                ),
                const SizedBox(height: 4),
                Text('Escribe el código que recibiste al donar.', style: TextStyle(color: soft)),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('home.track.code'),
                  controller: _code,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.go,
                  onSubmitted: (_) => _submit(),
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                  style: const TextStyle(color: white, fontFamily: 'monospace'),
                  cursorColor: PaxTokens.brandYellow400,
                  decoration: InputDecoration(
                    labelText: 'Código de seguimiento',
                    labelStyle: TextStyle(color: soft),
                    floatingLabelStyle: const TextStyle(color: white),
                    fillColor: white.withValues(alpha: 0.08),
                    enabledBorder: field,
                    border: field,
                    focusedBorder: field.copyWith(
                      borderSide: const BorderSide(color: PaxTokens.brandYellow400, width: 2),
                    ),
                    errorText: _error,
                    errorStyle: const TextStyle(color: PaxTokens.brandYellow400),
                    errorBorder: field.copyWith(borderSide: const BorderSide(color: PaxTokens.brandYellow400)),
                    focusedErrorBorder: field.copyWith(
                      borderSide: const BorderSide(color: PaxTokens.brandYellow400, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton(
                  key: const Key('home.track.submit'),
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: PaxTokens.brandYellow400,
                    foregroundColor: PaxTokens.brandGreen900,
                  ),
                  child: const Text('Ver ruta'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.lock_outline, size: 16, color: soft),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'El código es la llave de la donación: no lo publiques.',
                        style: TextStyle(fontSize: 12, color: soft),
                      ),
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const Key('home.scan'),
                    onPressed: () => scanQr(context),
                    style: TextButton.styleFrom(foregroundColor: white, padding: EdgeInsets.zero),
                    icon: const Icon(Icons.qr_code_scanner, size: 18),
                    label: const Text('O escanea un código QR'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------------------------------- Sellado en blockchain

class _SealCard extends StatelessWidget {
  const _SealCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _HomeCard(
      key: const Key('home.seal'),
      children: [
        const _CardHead(icon: Icons.lock_outline, title: 'Sellado en blockchain'),
        const SizedBox(height: 12),
        Row(
          children: [
            const ExcludeSemantics(
              child: RepaintBoundary(
                child: CustomPaint(size: Size(120, 51), painter: _SealTreePainter()),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'Cada paso deja una huella. Las huellas se juntan en una sola y esa se ancla, para que nadie cambie la '
                'historia sin que se note.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.5),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Árbol de huellas que se juntan en una raíz dorada (web: `SealTree`, viewBox 260 × 110). Estático.
class _SealTreePainter extends CustomPainter {
  const _SealTreePainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 260);
    final edge = Paint()
      ..color = PaxTokens.brandBlue700
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    canvas.drawPath(
      Path()
        ..moveTo(40, 92)
        ..lineTo(80, 60)
        ..moveTo(100, 92)
        ..lineTo(80, 60)
        ..moveTo(160, 92)
        ..lineTo(180, 60)
        ..moveTo(220, 92)
        ..lineTo(180, 60)
        ..moveTo(80, 60)
        ..lineTo(130, 26)
        ..moveTo(180, 60)
        ..lineTo(130, 26),
      edge,
    );
    final fill = Paint();
    void node(double x, double y, double w, double h, double r, Color c) =>
        canvas.drawRRect(RRect.fromLTRBR(x, y, x + w, y + h, Radius.circular(r)), fill..color = c);
    for (final x in [40.0, 100.0, 160.0, 220.0]) {
      node(x - 11, 84, 22, 18, 4, PaxTokens.brandBlue700);
    }
    node(69, 50, 22, 20, 5, PaxTokens.brandBlue800);
    node(169, 50, 22, 20, 5, PaxTokens.brandBlue800);
    node(116, 12, 28, 26, 6, PaxTokens.brandYellow400);
  }

  @override
  bool shouldRepaint(_SealTreePainter oldDelegate) => false;
}

// ------------------------------------------------------------------------------------------- Convocatorias

/// «Cierran pronto» (las que cierran en 7 días o menos, primero la más próxima) o, si no hay, «Convocatorias
/// abiertas». «Ver todas» abre la búsqueda (M-10). Tocar una abre la convocatoria, desde donde se dona.
class _CampaignsCard extends StatefulWidget {
  const _CampaignsCard({super.key, required this.now});
  final DateTime now;

  @override
  State<_CampaignsCard> createState() => _CampaignsCardState();
}

class _CampaignsCardState extends State<_CampaignsCard> {
  late final AppServices _services = AppScope.of(context);
  late Future<List<CampaignSummary>> _future = _fetch();

  Future<List<CampaignSummary>> _fetch() => _services.campaignSearch.search(const CampaignQuery());

  Future<void> reload() {
    final next = _fetch();
    setState(() {
      _future = next;
    });
    return next.then((_) {}, onError: (_) {});
  }

  void _openAll() => Navigator.of(context).push(
    PaxPageRoute<void>(
      builder: (page) => Scaffold(
        appBar: PaxAppBar(title: const Text('Convocatorias')),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<List<CampaignSummary>>(
      future: _future,
      builder: (context, snap) {
        final items = snap.data ?? const <CampaignSummary>[];
        final soon = items.where((c) => isClosingSoon(c, widget.now)).toList()
          ..sort((a, b) => DateTime.parse(a.endDate).compareTo(DateTime.parse(b.endDate)));
        final shown = (soon.isNotEmpty ? soon : items).take(homeItems).toList();
        final Widget body;
        if (snap.connectionState != ConnectionState.done) {
          body = const CampaignSkeletonCard();
        } else if (snap.hasError) {
          body = Row(
            children: [
              const Expanded(child: Text('No pudimos cargar las convocatorias.')),
              TextButton(onPressed: reload, child: const Text('Reintentar')),
            ],
          );
        } else if (shown.isEmpty) {
          body = const Text('No hay convocatorias abiertas en este momento.');
        } else {
          body = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final c in shown)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: CampaignSummaryCard(
                    c,
                    key: Key('home.campaign.${c.publicCode}'),
                    onTap: () => _services.router.push(AppRoutes.campaignPath(c.publicCode)),
                  ),
                ),
            ],
          );
        }
        return _HomeCard(
          key: const Key('home.campaigns'),
          children: [
            _CardHead(
              icon: Icons.campaign_outlined,
              title: soon.isNotEmpty ? 'Cierran pronto' : 'Convocatorias abiertas',
              action: TextButton(
                key: const Key('home.campaigns.all'),
                onPressed: _openAll,
                child: const Text('Ver todas'),
              ),
            ),
            Text(
              'Convocatorias que todavía puedes apoyar.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            AnimatedSwitcher(duration: PaxMotion.of(context, PaxMotion.normal), child: body),
          ],
        );
      },
    );
  }
}

// ------------------------------------------------------------------------------------------- Tus donaciones

class _DonationsCard extends StatefulWidget {
  const _DonationsCard({super.key});

  @override
  State<_DonationsCard> createState() => _DonationsCardState();
}

class _DonationsCardState extends State<_DonationsCard> {
  late final AppServices _services = AppScope.of(context);
  List<AccountDonation>? _items;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => reload());
  }

  Future<void> reload() async {
    if (!mounted) return;
    setState(() => _failed = false);
    try {
      final d = await AccountDonationsApi(_services.apiClient).list();
      if (mounted) setState(() => _items = d);
    } on AppException {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = _items;
    final Widget body;
    if (d == null && !_failed) {
      body = Skeleton.list(label: 'Cargando tus donaciones');
    } else if (d == null) {
      body = Row(
        children: [
          const Expanded(child: Text('No pudimos cargar tus donaciones.')),
          TextButton(onPressed: reload, child: const Text('Reintentar')),
        ],
      );
    } else if (d.isEmpty) {
      body = const Text('Todavía no tienes donaciones hechas con esta cuenta.');
    } else {
      body = Column(
        children: [
          for (final (i, x) in d.take(homeItems).indexed) ...[
            if (i > 0) const Divider(height: 20),
            _DonationRow(x, key: Key('home.donation.$i')),
          ],
        ],
      );
    }
    return _HomeCard(
      key: const Key('home.donations'),
      children: [
        _CardHead(
          icon: Icons.favorite_outline,
          title: 'Tus donaciones',
          action: TextButton(
            key: const Key('home.allDonations'),
            onPressed: () => _services.router.go(AppRoutes.donations),
            child: const Text('Ver todas'),
          ),
        ),
        Text(
          'Solo tú y la organización las ven.',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(duration: PaxMotion.of(context, PaxMotion.normal), child: body),
      ],
    );
  }
}

class _DonationRow extends StatelessWidget {
  const _DonationRow(this.d, {super.key});
  final AccountDonation d;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final services = AppScope.of(context);
    final meta = [
      if (d.createdAt case final c?) shortDate(c),
      ?d.organizationName,
      if (d.paymentMethod case final m?) paymentMethodLabel(m),
    ].join(' · ');
    final code = d.trackingCode;
    final publicCode = d.publicCode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                d.campaignTitle.isEmpty ? 'Convocatoria' : d.campaignTitle,
                style: theme.textTheme.titleSmall,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              formatMinorUnits(d.amount, d.currency.isEmpty ? null : d.currency),
              style: theme.textTheme.titleSmall?.copyWith(fontFamily: 'monospace'),
            ),
          ],
        ),
        if (meta.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(meta, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ],
        const SizedBox(height: 6),
        donationStatusChip(d.status),
        if (code != null || publicCode != null)
          Wrap(
            spacing: 4,
            children: [
              if (code != null)
                TextButton(
                  onPressed: () =>
                      Navigator.of(context).push(PaxPageRoute<void>(builder: (_) => TrackingScreen(initialCode: code))),
                  child: const Text('Ver recorrido'),
                ),
              if (publicCode != null)
                TextButton(
                  onPressed: () => services.router.push(AppRoutes.campaignPath(publicCode)),
                  child: const Text('Ver convocatoria'),
                ),
            ],
          ),
      ],
    );
  }
}

// ------------------------------------------------------------------------------------------- Operador y predicción

/// Empleado: cuántas operaciones tiene guardadas en el teléfono y el atajo para escanear un activo.
class _OperationsCard extends StatelessWidget {
  const _OperationsCard();

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final account = services.session.principal?.accountId;
    return _HomeCard(
      key: const Key('home.operations'),
      children: [
        const _CardHead(icon: Icons.inventory_2_outlined, title: 'Operaciones'),
        const SizedBox(height: 8),
        ListenableBuilder(
          listenable: services.syncEngine,
          builder: (context, _) => FutureBuilder<int>(
            future: account == null
                ? Future.value(0)
                : services.syncEngine
                      .entriesFor(account)
                      .then((all) => all.where((i) => i.status != OutboxStatus.acknowledged).length)
                      .catchError((_) => 0),
            builder: (context, snap) {
              final n = snap.data ?? 0;
              return Text(
                n == 0
                    ? 'No hay operaciones pendientes en este dispositivo'
                    : '$n ${n == 1 ? 'operación pendiente' : 'operaciones pendientes'} en este dispositivo',
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => scanQr(context),
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Escanear activo'),
        ),
        TextButton(onPressed: () => services.router.go(AppRoutes.operator), child: const Text('Ir a Mi día')),
      ],
    );
  }
}

class _PredictionCard extends StatelessWidget {
  const _PredictionCard();

  @override
  Widget build(BuildContext context) => _HomeCard(
    key: const Key('home.prediction'),
    children: [
      const _CardHead(icon: Icons.insights_outlined, title: 'Predicción'),
      const SizedBox(height: 4),
      Text(
        'Estimación de una convocatoria · modelo con datos sintéticos',
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      const SizedBox(height: 12),
      OutlinedButton(
        onPressed: () => AppScope.of(context).router.go(AppRoutes.prediction),
        child: const Text('Ver predicción'),
      ),
    ],
  );
}
