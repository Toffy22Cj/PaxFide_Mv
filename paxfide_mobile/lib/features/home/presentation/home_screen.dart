import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../app/qr_scanner_sheet.dart';
import '../../../shared/theme/pax_theme.dart';
import '../../../shared/widgets/state_views.dart';
import '../../auth/data/session_controller.dart';
import '../../auth/domain/principal.dart';
import '../../auth/domain/session_state.dart';
import '../../campaigns/presentation/campaign_list_view.dart';
import '../../donations/presentation/my_donations_view.dart';
import '../../physical_assets/presentation/operator_screen.dart';
import '../../prediction/presentation/prediction_screen.dart';
import '../../tracking/presentation/tracking_screen.dart';

/// Secciones de `/home`. Cuáles se muestran depende del [Principal] de
/// `GET /me` (ADR-043 §0, A3); mostrarlas no es autorización (P7).
enum HomeSection {
  campaigns('Causas', 'Causas', Icons.explore_outlined,
      'Causas abiertas que puedes apoyar. Toca una para ver los detalles y donar.'),
  donations('Mis donaciones', 'Donaciones', Icons.volunteer_activism_outlined,
      'Las donaciones que hiciste con esta cuenta.'),
  tracking('Seguimiento', 'Seguimiento', Icons.track_changes_rounded,
      'Escribe el código que recibiste al donar y mira a dónde llegó tu ayuda.'),
  operator('Operaciones de campo', 'Operaciones', Icons.local_shipping_outlined,
      'Registra cuándo sale, llega y se entrega cada envío.'),
  prediction('Predicción', 'Predicción', Icons.insights_outlined,
      '¿Llegará cada causa a su meta? Elige una para verlo.');

  final String label;
  final String shortLabel;
  final IconData icon;
  final String description;
  const HomeSection(this.label, this.shortLabel, this.icon, this.description);

  /// Secciones visibles para [principal]. Sin principal (perfil no cargado)
  /// solo las comunes a cualquier cuenta. Varios roles ven la unión.
  static List<HomeSection> visibleFor(Principal? principal) => [
        campaigns,
        donations,
        tracking,
        if (principal?.isFieldOperator ?? false) operator,
        if (principal?.canSeePrediction ?? false) prediction,
      ];
}

/// Pantalla de `/home` (ADR-043 D8, D10). Cada sección muestra su contenido
/// directamente; no hay datos inventados.
class HomeScreen extends StatefulWidget {
  final SessionController session;

  const HomeScreen({super.key, required this.session});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  HomeSection _section = HomeSection.campaigns;
  bool _reloadingProfile = false;

  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onNavChange(HomeSection section) {
    if (_section == section) return;
    setState(() => _section = section);
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  void _toggleTheme() {
    final dark = AppScope.of(context).darkMode;
    dark.value = !dark.value;
  }

  /// El guard lleva a /login al emitirse LOGGED_OUT; aquí no se navega.
  Future<void> _handleLogout() => widget.session.logout();

  Future<void> _reloadProfile() async {
    if (_reloadingProfile) return;
    setState(() => _reloadingProfile = true);
    try {
      await widget.session.reloadPrincipal();
    } on InvalidSessionTransitionException {
      // La sesión ya cambió (p. ej. logout); el guard decide.
    } finally {
      if (mounted) setState(() => _reloadingProfile = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SessionState>(
      valueListenable: widget.session,
      builder: (context, session, _) => _buildForPrincipal(context, session.principal),
    );
  }

  Widget _buildForPrincipal(BuildContext context, Principal? principal) {
    final sections = HomeSection.visibleFor(principal);
    final section = sections.contains(_section) ? _section : sections.first;
    final isDesktop = MediaQuery.of(context).size.width >= 1024;
    final c = PaxPalette.of(context);

    return Scaffold(
      backgroundColor: c.bg,
      body: Row(
        children: [
          if (isDesktop) _buildDesktopSidebar(c, sections, section, principal),
          Expanded(
            child: Column(
              children: [
                _buildTopAppBar(c, isDesktop, principal),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(horizontal: isDesktop ? 40.0 : 16.0, vertical: 20.0),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1000),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (principal == null) _buildProfileUnavailable(),
                            KeyedSubtree(
                              key: ValueKey('section_${section.name}'),
                              child: Column(
                                key: Key('home-section-${section.name}'),
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  SectionHeader(title: section.label, subtitle: section.description),
                                  _buildSectionContent(section),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: isDesktop ? null : _buildMobileBottomBar(c, sections, section),
    );
  }

  Widget _buildSectionContent(HomeSection section) => switch (section) {
        HomeSection.campaigns => const CampaignListView(),
        HomeSection.donations => const MyDonationsView(),
        HomeSection.tracking => const TrackingView(),
        HomeSection.operator => const OperatorView(),
        HomeSection.prediction => const PredictionView(),
      };

  Widget _buildProfileUnavailable() {
    return Notice(
      key: const Key('home-profile-unavailable'),
      kind: NoticeKind.warning,
      title: 'No pudimos cargar tu perfil',
      text: 'Por ahora solo ves las secciones para donantes.',
      action: Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton(
          key: const Key('home-profile-retry'),
          onPressed: _reloadingProfile ? null : _reloadProfile,
          child: const Text('Intentar de nuevo'),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Estructura: barra superior, lateral e inferior
  // ---------------------------------------------------------------------------

  Widget _buildTopAppBar(PaxPalette c, bool isDesktop, Principal? principal) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 36 : 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (!isDesktop)
            _buildBrand(c, fontSize: 23)
          else
            StatusChip(_roleSummary(principal)),
          Row(
            children: [
              IconButton(
                key: const Key('home-scan'),
                tooltip: 'Escanear un código QR',
                icon: Icon(Icons.qr_code_scanner, color: c.textMuted, size: 20),
                onPressed: () => scanQr(context),
              ),
              IconButton(
                tooltip: c.dark ? 'Modo claro' : 'Modo oscuro',
                icon: Icon(
                  c.dark ? Icons.wb_sunny_outlined : Icons.nightlight_round_outlined,
                  color: c.dark ? const Color(0xFFFBBF24) : c.text,
                  size: 20,
                ),
                onPressed: _toggleTheme,
              ),
              IconButton(
                key: const Key('home-logout'),
                tooltip: 'Cerrar sesión',
                icon: Icon(Icons.logout_rounded, color: c.textMuted, size: 20),
                onPressed: _handleLogout,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBrand(PaxPalette c, {required double fontSize}) {
    return RichText(
      text: TextSpan(
        text: 'PaxFide',
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          fontFamily: 'serif',
          letterSpacing: -1.2,
          color: c.text,
        ),
        children: const [
          TextSpan(text: '.', style: TextStyle(color: paxAccent, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildDesktopSidebar(
    PaxPalette c,
    List<HomeSection> sections,
    HomeSection selected,
    Principal? principal,
  ) {
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(right: BorderSide(color: c.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.symmetric(horizontal: 8.0), child: _buildBrand(c, fontSize: 25)),
          const SizedBox(height: 36),
          for (final section in sections) _buildSidebarNavItem(c, section, selected),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.surfaceAlt,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.border),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: paxAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.person_outline_rounded, size: 16, color: paxAccent),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _roleSummary(principal),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: c.text),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarNavItem(PaxPalette c, HomeSection section, HomeSection selected) {
    final isSelected = section == selected;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        key: Key('home-nav-${section.name}'),
        onTap: () => _onNavChange(section),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: isSelected ? paxAccent.withValues(alpha: 0.14) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(section.icon, size: 19, color: isSelected ? paxAccent : c.textMuted),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  section.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? paxAccent : c.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileBottomBar(PaxPalette c, List<HomeSection> sections, HomeSection selected) {
    return Container(
      height: 62,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          for (final section in sections) Expanded(child: _buildMobileNavBtn(c, section, selected)),
        ],
      ),
    );
  }

  Widget _buildMobileNavBtn(PaxPalette c, HomeSection section, HomeSection selected) {
    final isSel = section == selected;
    return GestureDetector(
      key: Key('home-nav-${section.name}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => _onNavChange(section),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(section.icon, size: 21, color: isSel ? paxAccent : c.textMuted),
          const SizedBox(height: 3),
          Text(
            section.shortLabel,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
              color: isSel ? paxAccent : c.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  /// Texto del rol según `/me`. Solo presentación.
  static String _roleSummary(Principal? principal) {
    if (principal == null) return 'Perfil no disponible';
    final labels = <String>[
      if (principal.isDonor) 'Donante',
      if (principal.roles.contains(OrgRole.employee)) 'Operador de campo',
      if (principal.roles.contains(OrgRole.administrator)) 'Administrador',
      if (principal.roles.contains(OrgRole.representative)) 'Representante',
    ];
    return labels.isEmpty ? 'Cuenta' : labels.join(' · ');
  }
}
