import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../app/qr_scanner_sheet.dart';
import '../../auth/data/session_controller.dart';
import '../../auth/domain/principal.dart';
import '../../auth/domain/session_state.dart';
import '../../campaigns/presentation/campaign_list_view.dart';
import '../../donations/presentation/my_donations_view.dart';

/// Secciones de `/home`. Cuáles se muestran depende del [Principal] de
/// `GET /me` (ADR-043 §0, A3); mostrarlas no es autorización (P7).
enum HomeSection {
  campaigns('Convocatorias', 'Convocatorias', Icons.explore_outlined),
  donations('Mis donaciones', 'Donaciones', Icons.volunteer_activism_outlined),
  tracking('Seguimiento', 'Seguimiento', Icons.track_changes_rounded),
  operator('Operaciones de campo', 'Operaciones', Icons.local_shipping_outlined),
  prediction('Predicción', 'Predicción', Icons.insights_outlined);

  final String label;
  final String shortLabel;
  final IconData icon;
  const HomeSection(this.label, this.shortLabel, this.icon);

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

/// Pantalla de `/home` (ADR-043 D8, D10).
///
/// Convocatorias y donaciones se cargan del backend dentro de la propia
/// sección; seguimiento, operaciones y predicción abren su ruta del árbol.
/// No muestra datos inventados.
class HomeScreen extends StatefulWidget {
  final SessionController session;

  const HomeScreen({super.key, required this.session});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isDarkMode = true;
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
    setState(() => _isDarkMode = !_isDarkMode);
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

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;

    final colors = _HomeColors(dark: _isDarkMode);

    return Theme(
      data: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _accent,
          brightness: _isDarkMode ? Brightness.dark : Brightness.light,
          surface: colors.surface,
        ),
        cardTheme: CardThemeData(
          color: colors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: colors.border),
          ),
        ),
        useMaterial3: true,
      ),
      child: Scaffold(
      backgroundColor: colors.bg,
      body: Row(
        children: [
          if (isDesktop) _buildDesktopSidebar(colors, sections, section, principal),
          Expanded(
            child: Column(
              children: [
                _buildTopAppBar(colors, isDesktop, principal),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 40.0 : 16.0,
                      vertical: 20.0,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1200),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (principal == null) ...[
                              _buildProfileUnavailable(colors),
                              const SizedBox(height: 20),
                            ],
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              switchInCurve: Curves.easeOutQuad,
                              switchOutCurve: Curves.easeInQuad,
                              layoutBuilder: (currentChild, previousChildren) {
                                return Stack(
                                  alignment: Alignment.topLeft,
                                  children: [
                                    ...previousChildren,
                                    ?currentChild,
                                  ],
                                );
                              },
                              transitionBuilder: (child, animation) {
                                return FadeTransition(opacity: animation, child: child);
                              },
                              child: KeyedSubtree(
                                key: ValueKey('section_${section.name}'),
                                child: _buildSectionContent(colors, section),
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
      bottomNavigationBar:
          isDesktop ? null : _buildMobileBottomBar(colors, sections, section),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Secciones
  // ---------------------------------------------------------------------------

  Widget _buildSectionContent(_HomeColors c, HomeSection section) {
    switch (section) {
      case HomeSection.campaigns:
        return _buildSection(
          c,
          key: 'home-section-campaigns',
          title: 'Convocatorias',
          subtitle: 'Convocatorias abiertas de organizaciones verificadas: '
              'meta, lo recaudado y los tipos de donación que aceptan.',
          body: const CampaignListView(),
        );
      case HomeSection.donations:
        return _buildSection(
          c,
          key: 'home-section-donations',
          title: 'Mis donaciones',
          subtitle: 'Tus donaciones con su convocatoria, importe, estado y, '
              'cuando los fondos se aplican, su código de seguimiento.',
          body: const MyDonationsView(),
        );
      case HomeSection.tracking:
        return _buildSection(
          c,
          key: 'home-section-tracking',
          title: 'Seguimiento',
          subtitle: 'Con el código de seguimiento de una donación puedes ver '
              'los fondos acreditados y asignados, los activos entregados y la '
              'verificación de integridad de sus registros.',
          body: _buildEntryCard(
            c,
            key: 'home-entry-tracking',
            icon: Icons.qr_code_2_rounded,
            title: 'Consultar seguimiento',
            description: 'El código se escribe a mano en la pantalla de seguimiento.',
            route: AppRoutes.tracking,
          ),
        );
      case HomeSection.operator:
        return _buildSection(
          c,
          key: 'home-section-operator',
          title: 'Operaciones de campo',
          subtitle: 'Despacho, recepción y entrega de activos físicos. '
              'El servidor autoriza cada operación.',
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildEntryCard(
                c,
                key: 'home-entry-operator',
                icon: Icons.inventory_2_outlined,
                title: 'Operaciones',
                description: 'Abrir un activo y registrar su siguiente paso.',
                route: AppRoutes.operator,
              ),
              const SizedBox(height: 12),
              _buildEntryCard(
                c,
                key: 'home-entry-operator-pending',
                icon: Icons.pending_actions_outlined,
                title: 'Operaciones pendientes',
                description: 'Operaciones guardadas en este teléfono que aún no '
                    'se enviaron o no se pudieron confirmar.',
                route: AppRoutes.operatorPending,
              ),
            ],
          ),
        );
      case HomeSection.prediction:
        return _buildSection(
          c,
          key: 'home-section-prediction',
          title: 'Predicción',
          subtitle: 'Estimación de la probabilidad de que una convocatoria '
              'alcance su meta y del porcentaje final esperado. Es una '
              'estimación, no una promesa de recaudo.',
          body: _buildEntryCard(
            c,
            key: 'home-entry-prediction',
            icon: Icons.insights_outlined,
            title: 'Consultar una predicción',
            description: 'Elige una convocatoria de tu organización.',
            route: AppRoutes.prediction,
          ),
        );
    }
  }

  Widget _buildSection(
    _HomeColors c, {
    required String key,
    required String title,
    required String subtitle,
    required Widget body,
  }) {
    return Column(
      key: Key(key),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: c.text)),
        const SizedBox(height: 4),
        Text(subtitle, style: TextStyle(fontSize: 13, color: c.textMuted, height: 1.4)),
        const SizedBox(height: 20),
        body,
      ],
    );
  }

  /// Acceso a una ruta del árbol aprobado.
  Widget _buildEntryCard(
    _HomeColors c, {
    required String key,
    required IconData icon,
    required String title,
    required String description,
    required String route,
  }) {
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: Key(key),
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).pushNamed(route),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: _accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: c.text)),
                    const SizedBox(height: 3),
                    Text(description, style: TextStyle(fontSize: 12, color: c.textMuted, height: 1.35)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: c.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileUnavailable(_HomeColors c) {
    return Container(
      key: const Key('home-profile-unavailable'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_off_outlined, size: 20, color: Color(0xFFF59E0B)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'No pudimos cargar tu perfil. Solo se muestran las secciones comunes '
              'a cualquier cuenta.',
              style: TextStyle(fontSize: 12.5, color: c.text, height: 1.35),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            key: const Key('home-profile-retry'),
            onPressed: _reloadingProfile ? null : _reloadProfile,
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Estructura: barra superior, lateral e inferior
  // ---------------------------------------------------------------------------

  Widget _buildTopAppBar(_HomeColors c, bool isDesktop, Principal? principal) {
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _accent.withValues(alpha: 0.3)),
              ),
              child: Text(
                _roleSummary(principal),
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: _accent),
              ),
            ),
          Row(
            children: [
              IconButton(
                key: const Key('home-scan'),
                tooltip: 'Escanear QR',
                icon: Icon(Icons.qr_code_scanner, color: c.textMuted, size: 20),
                onPressed: () => scanQr(context),
              ),
              IconButton(
                tooltip: _isDarkMode ? 'Modo claro' : 'Modo oscuro',
                icon: Icon(
                  _isDarkMode ? Icons.wb_sunny_outlined : Icons.nightlight_round_outlined,
                  color: _isDarkMode ? const Color(0xFFFBBF24) : c.text,
                  size: 20,
                ),
                onPressed: _toggleTheme,
              ),
              const SizedBox(width: 4),
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

  Widget _buildBrand(_HomeColors c, {required double fontSize}) {
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
          TextSpan(
            text: '.',
            style: TextStyle(color: _accent, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopSidebar(
    _HomeColors c,
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: _buildBrand(c, fontSize: 25),
          ),
          const SizedBox(height: 36),
          for (final section in sections) _buildSidebarNavItem(c, section, selected),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _isDarkMode
                    ? [const Color(0xFF131D27), const Color(0xFF0F1620)]
                    : [const Color(0xFFF8FAFC), Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.person_outline_rounded, size: 16, color: _accent),
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
                const SizedBox(height: 8),
                Text(
                  'Lo que ves depende de tu rol. El servidor autoriza cada operación.',
                  style: TextStyle(fontSize: 11, color: c.textMuted, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarNavItem(_HomeColors c, HomeSection section, HomeSection selected) {
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
            color: isSelected ? _accent.withValues(alpha: 0.14) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(section.icon, size: 19, color: isSelected ? _accent : c.textMuted),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  section.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? _accent : c.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileBottomBar(
    _HomeColors c,
    List<HomeSection> sections,
    HomeSection selected,
  ) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          for (final section in sections)
            Expanded(child: _buildMobileNavBtn(c, section, selected)),
        ],
      ),
    );
  }

  Widget _buildMobileNavBtn(_HomeColors c, HomeSection section, HomeSection selected) {
    final isSel = section == selected;
    return GestureDetector(
      key: Key('home-nav-${section.name}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => _onNavChange(section),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(section.icon, size: 20, color: isSel ? _accent : c.textMuted),
          const SizedBox(height: 2),
          Text(
            section.shortLabel,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
              color: isSel ? _accent : c.textMuted,
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

const Color _accent = Color(0xFF10B981);

/// Paleta de la home en modo claro u oscuro.
class _HomeColors {
  final bool dark;
  const _HomeColors({required this.dark});

  Color get bg => dark ? const Color(0xFF070B0E) : const Color(0xFFF1F5F9);
  Color get surface => dark ? const Color(0xFF0F151D) : Colors.white;
  Color get border => dark ? const Color(0xFF1F2D3D) : const Color(0xFFE2E8F0);
  Color get text => dark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
  Color get textMuted => dark ? const Color(0xFF7E92A7) : const Color(0xFF64748B);
}
