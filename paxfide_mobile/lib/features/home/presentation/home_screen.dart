import 'package:flutter/material.dart';
import '../../auth/domain/session_state.dart';
import '../../auth/presentation/login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late UserRole _currentRole;
  bool _isDarkMode = true;
  int _navIndex = 0;
  String _selectedCategory = 'Todas';
  int _selectedCampaignIndex = 0;

  int? _hoveredBarIndex;
  double? _hoveredCurveX;
  String? _hoveredCardId;

  final Set<String> _bookmarkedCauses = {'c1'};

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final ScrollController _scrollController = ScrollController();

  final List<String> _orgCampaigns = [
    'Kits Escolares Rurales 2026',
    'Comedor San Juan',
    'Brigada Guajira',
  ];

  @override
  void initState() {
    super.initState();
    _currentRole = SessionManager.instance.currentRole;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onNavChange(int index) {
    if (_navIndex == index) return;
    setState(() => _navIndex = index);
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  void _toggleTheme() {
    setState(() => _isDarkMode = !_isDarkMode);
  }

  void _handleLogout() {
    SessionManager.instance.logOut();
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (context, anim, secAnim) => const LoginScreen(),
        transitionsBuilder: (context, anim, secAnim, child) {
          final curve = CurvedAnimation(parent: anim, curve: Curves.easeInOut);
          return FadeTransition(opacity: curve, child: child);
        },
        transitionDuration: const Duration(milliseconds: 250),
      ),
      (route) => false,
    );
  }

  void _toggleBookmark(String id) {
    setState(() {
      if (_bookmarkedCauses.contains(id)) {
        _bookmarkedCauses.remove(id);
      } else {
        _bookmarkedCauses.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;

    final bg = _isDarkMode ? const Color(0xFF070B0E) : const Color(0xFFF1F5F9);
    final surface = _isDarkMode ? const Color(0xFF0F151D) : Colors.white;
    final surfaceAlt = _isDarkMode ? const Color(0xFF16202C) : const Color(0xFFF8FAFC);
    final border = _isDarkMode ? const Color(0xFF1F2D3D) : const Color(0xFFE2E8F0);
    final text = _isDarkMode ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final textMuted = _isDarkMode ? const Color(0xFF7E92A7) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bg,
      body: Row(
        children: [
          if (isDesktop)
            _buildDesktopSidebar(surface, border, text, textMuted),
          Expanded(
            child: Column(
              children: [
                _buildTopAppBar(surface, border, text, textMuted, isDesktop),
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
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          switchInCurve: Curves.easeOutQuad,
                          switchOutCurve: Curves.easeInQuad,
                          layoutBuilder: (currentChild, previousChildren) {
                            return Stack(
                              alignment: Alignment.topLeft,
                              children: [
                                ...previousChildren,
                                if (currentChild != null) currentChild,
                              ],
                            );
                          },
                          transitionBuilder: (child, animation) {
                            return FadeTransition(opacity: animation, child: child);
                          },
                          child: KeyedSubtree(
                            key: ValueKey('tab_${_currentRole.name}_$_navIndex'),
                            child: _buildCurrentTabContent(surface, surfaceAlt, border, text, textMuted, isDesktop),
                          ),
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
      bottomNavigationBar: isDesktop ? null : _buildMobileBottomBar(surface, border, textMuted),
    );
  }

  Widget _buildCurrentTabContent(Color surface, Color surfaceAlt, Color border, Color text, Color textMuted, bool isDesktop) {
    if (_currentRole == UserRole.donor) {
      switch (_navIndex) {
        case 0:
          return _buildDonorDashboard(surface, surfaceAlt, border, text, textMuted, isDesktop);
        case 1:
          return _buildDonorDonationsView(surface, border, text, textMuted);
        case 2:
          return _buildDonorImpactView(surface, border, text, textMuted);
        case 3:
          return _buildSettingsView(surface, border, text, textMuted);
        default:
          return _buildDonorDashboard(surface, surfaceAlt, border, text, textMuted, isDesktop);
      }
    } else {
      switch (_navIndex) {
        case 0:
          return _buildOrganizationDashboard(surface, surfaceAlt, border, text, textMuted, isDesktop);
        case 1:
          return _buildOrgAuditView(surface, border, text, textMuted);
        case 2:
          return _buildOrgFinancesView(surface, border, text, textMuted);
        case 3:
          return _buildSettingsView(surface, border, text, textMuted);
        default:
          return _buildOrganizationDashboard(surface, surfaceAlt, border, text, textMuted, isDesktop);
      }
    }
  }

  Widget _buildTopAppBar(Color surface, Color border, Color text, Color textMuted, bool isDesktop) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: surface,
        border: Border(bottom: BorderSide(color: border)),
      ),
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 36 : 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (!isDesktop)
            RichText(
              text: TextSpan(
                text: 'PaxFide',
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'serif',
                  letterSpacing: -1.2,
                  color: text,
                ),
                children: const [
                  TextSpan(
                    text: '.',
                    style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            )
          else
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      ScaleTransition(
                        scale: _pulseAnimation,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _currentRole == UserRole.donor ? 'Protocolo Fiduciario Activo' : 'Nodo Institucional Conectado',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF10B981)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          Row(
            children: [
              IconButton(
                tooltip: _isDarkMode ? 'Modo claro' : 'Modo oscuro',
                icon: Icon(
                  _isDarkMode ? Icons.wb_sunny_outlined : Icons.nightlight_round_outlined,
                  color: _isDarkMode ? const Color(0xFFFBBF24) : text,
                  size: 20,
                ),
                onPressed: _toggleTheme,
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Cerrar sesión',
                icon: Icon(Icons.logout_rounded, color: textMuted, size: 20),
                onPressed: _handleLogout,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopSidebar(Color surface, Color border, Color text, Color textMuted) {
    final isDonor = _currentRole == UserRole.donor;

    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: surface,
        border: Border(right: BorderSide(color: border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: RichText(
              text: TextSpan(
                text: 'PaxFide',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'serif',
                  letterSpacing: -1.2,
                  color: text,
                ),
                children: const [
                  TextSpan(
                    text: '.',
                    style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 36),
          if (isDonor) ...[
            _buildSidebarNavItem(0, Icons.explore_outlined, 'Explorar Causas', text, textMuted),
            _buildSidebarNavItem(1, Icons.volunteer_activism_outlined, 'Mis Aportes', text, textMuted),
            _buildSidebarNavItem(2, Icons.photo_camera_back_outlined, 'Evidencia & Impacto', text, textMuted),
            _buildSidebarNavItem(3, Icons.settings_outlined, 'Ajustes', text, textMuted),
          ] else ...[
            _buildSidebarNavItem(0, Icons.grid_view_rounded, 'Tablero Ejecutivo', text, textMuted),
            _buildSidebarNavItem(1, Icons.verified_user_outlined, 'Auditoría Fiduciaria', text, textMuted),
            _buildSidebarNavItem(2, Icons.account_balance_outlined, 'Finanzas & Retiros', text, textMuted),
            _buildSidebarNavItem(3, Icons.tune_rounded, 'Parámetros', text, textMuted),
          ],
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
              border: Border.all(color: border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isDonor ? Icons.person_outline_rounded : Icons.apartment_rounded,
                        size: 16,
                        color: const Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isDonor ? 'Perfil Donante' : 'Entidad Registrada',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: text),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  isDonor
                      ? 'Aportes respaldados por depósito fiduciario verificable.'
                      : 'Reportes y métricas sincronizados con protocolo.',
                  style: TextStyle(fontSize: 11, color: textMuted, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarNavItem(int index, IconData icon, String label, Color text, Color textMuted) {
    final isSelected = _navIndex == index;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: () => _onNavChange(index),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF10B981).withValues(alpha: 0.14) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, size: 19, color: isSelected ? const Color(0xFF10B981) : textMuted),
              const SizedBox(width: 14),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? const Color(0xFF10B981) : textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDonorDashboard(
    Color surface,
    Color surfaceAlt,
    Color border,
    Color text,
    Color textMuted,
    bool isDesktop,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _isDarkMode
                  ? [const Color(0xFF0F1A1B), const Color(0xFF0B1417)]
                  : [Colors.white, const Color(0xFFF8FAFC)],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFF10B981).withValues(alpha: _isDarkMode ? 0.35 : 0.25),
            ),
          ),
          child: isDesktop
              ? Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.shield_outlined, color: Color(0xFF10B981), size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Tus Aportes Están Protegidos', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w900, color: text)),
                          const SizedBox(height: 2),
                          Text('El dinero se libera únicamente tras la confirmación verificada de la entrega.', style: TextStyle(fontSize: 12, color: textMuted)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: () => _onNavChange(1),
                      icon: const Icon(Icons.receipt_long_rounded, size: 15),
                      label: const Text('Ver Mis Certificados', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.shield_outlined, color: Color(0xFF10B981), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Tus Aportes Están Protegidos', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: text)),
                              const SizedBox(height: 2),
                              Text('Fondos protegidos hasta confirmación de entrega.', style: TextStyle(fontSize: 12, color: textMuted)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _onNavChange(1),
                        icon: const Icon(Icons.receipt_long_rounded, size: 15),
                        label: const Text('Ver Mis Certificados (3)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 20),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: ['Todas', 'Educación', 'Nutrición', 'Salud', 'Emergencia'].map((cat) {
              final isSelected = _selectedCategory == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedCategory = cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF10B981) : surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF10B981) : border,
                      ),
                    ),
                    child: Text(
                      cat,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected ? Colors.white : textMuted,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 20),
        isDesktop
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildInteractiveCauseCard(
                      id: 'c1',
                      tag: 'Educación & Nutrición',
                      title: 'Kits Escolares & Canastas Nutricionales',
                      org: 'Fundación Fiduciaria Guajira',
                      loc: 'Manaure, La Guajira',
                      currentVal: 19500000,
                      goalVal: 25000000,
                      progress: 0.78,
                      donors: 142,
                      daysLeft: '8 días',
                      surface: surface,
                      surfaceAlt: surfaceAlt,
                      border: border,
                      text: text,
                      textMuted: textMuted,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _buildInteractiveCauseCard(
                      id: 'c2',
                      tag: 'Comedores Comunitarios',
                      title: 'Dotación Comedor Infantil San Juan',
                      org: 'Huellas del Mañana',
                      loc: 'Soacha, Cundinamarca',
                      currentVal: 9000000,
                      goalVal: 12000000,
                      progress: 0.75,
                      donors: 88,
                      daysLeft: '14 días',
                      surface: surface,
                      surfaceAlt: surfaceAlt,
                      border: border,
                      text: text,
                      textMuted: textMuted,
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  _buildInteractiveCauseCard(
                    id: 'c1',
                    tag: 'Educación & Nutrición',
                    title: 'Kits Escolares & Canastas Nutricionales',
                    org: 'Fundación Fiduciaria Guajira',
                    loc: 'Manaure, La Guajira',
                    currentVal: 19500000,
                    goalVal: 25000000,
                    progress: 0.78,
                    donors: 142,
                    daysLeft: '8 días',
                    surface: surface,
                    surfaceAlt: surfaceAlt,
                    border: border,
                    text: text,
                    textMuted: textMuted,
                  ),
                  const SizedBox(height: 16),
                  _buildInteractiveCauseCard(
                    id: 'c2',
                    tag: 'Comedores Comunitarios',
                    title: 'Dotación Comedor Infantil San Juan',
                    org: 'Huellas del Mañana',
                    loc: 'Soacha, Cundinamarca',
                    currentVal: 9000000,
                    goalVal: 12000000,
                    progress: 0.75,
                    donors: 88,
                    daysLeft: '14 días',
                    surface: surface,
                    surfaceAlt: surfaceAlt,
                    border: border,
                    text: text,
                    textMuted: textMuted,
                  ),
                ],
              ),
      ],
    );
  }

  Widget _buildInteractiveCauseCard({
    required String id,
    required String tag,
    required String title,
    required String org,
    required String loc,
    required double currentVal,
    required double goalVal,
    required double progress,
    required int donors,
    required String daysLeft,
    required Color surface,
    required Color surfaceAlt,
    required Color border,
    required Color text,
    required Color textMuted,
  }) {
    final isBookmarked = _bookmarkedCauses.contains(id);
    final isHovered = _hoveredCardId == id;

    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredCardId = id),
      onExit: (_) => setState(() => _hoveredCardId = null),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, isHovered ? -4 : 0, 0),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isHovered ? const Color(0xFF10B981).withValues(alpha: 0.6) : border,
          ),
          boxShadow: isHovered
              ? [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : [],
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tag,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF10B981)),
                  ),
                ),
                Row(
                  children: [
                    Text(daysLeft, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: textMuted)),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => _toggleBookmark(id),
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 150),
                        scale: isBookmarked ? 1.15 : 1.0,
                        child: Icon(
                          isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                          size: 20,
                          color: isBookmarked ? const Color(0xFF10B981) : textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(fontSize: 17.5, fontWeight: FontWeight.w800, color: text, height: 1.25),
            ),
            const SizedBox(height: 5),
            Text(
              '$org · $loc',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: textMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeOutCubic,
                tween: Tween<double>(begin: 0, end: progress),
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  backgroundColor: surfaceAlt,
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                  minHeight: 7,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 1200),
                      curve: Curves.easeOutExpo,
                      tween: Tween<double>(begin: 0, end: currentVal),
                      builder: (context, val, _) => Text(
                        '\$${(val / 1000000).toStringAsFixed(1)}M COP',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: text),
                      ),
                    ),
                    Text('meta: \$${(goalVal / 1000000).toStringAsFixed(1)}M · $donors aportes', style: TextStyle(fontSize: 11, color: textMuted)),
                  ],
                ),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: const Text('Aportar', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDonorDonationsView(Color surface, Color border, Color text, Color textMuted) {
    final donations = [
      {'title': 'Kits Escolares Manaure', 'amount': '\$150.000 COP', 'date': '28 Sep 2026', 'status': 'En Escrow', 'color': const Color(0xFF10B981)},
      {'title': 'Comedor Infantil Soacha', 'amount': '\$300.000 COP', 'date': '15 Sep 2026', 'status': 'Ejecución 70%', 'color': const Color(0xFF0284C7)},
      {'title': 'Brigada Médica Rural', 'amount': '\$80.000 COP', 'date': '02 Ago 2026', 'status': 'Verificado', 'color': const Color(0xFF10B981)},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Mis Aportes Fiduciarios', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: text)),
        const SizedBox(height: 6),
        Text('Historial de contribuciones bajo custodia y estado de liberación.', style: TextStyle(fontSize: 13, color: textMuted)),
        const SizedBox(height: 20),
        ...donations.map((d) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(d['title'] as String, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: text)),
                  const SizedBox(height: 4),
                  Text('${d['date']} · Certificado #PF-${d.hashCode % 10000}', style: TextStyle(fontSize: 11.5, color: textMuted)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(d['amount'] as String, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: text)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (d['color'] as Color).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(d['status'] as String, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: d['color'] as Color)),
                  ),
                ],
              ),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildDonorImpactView(Color surface, Color border, Color text, Color textMuted) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Evidencia & Cumplimiento', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: text)),
        const SizedBox(height: 6),
        Text('Galería inmutable de fotos y actas subidas por las organizaciones.', style: TextStyle(fontSize: 13, color: textMuted)),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981), size: 20),
                  const SizedBox(width: 8),
                  Text('Entrega Hito #1: 142 Kits Escolares', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: text)),
                ],
              ),
              const SizedBox(height: 8),
              Text('Manaure, La Guajira · Fotografía georreferenciada y acta firmada por personería municipal.', style: TextStyle(fontSize: 12, color: textMuted)),
              const SizedBox(height: 16),
              Container(
                height: 120,
                decoration: BoxDecoration(
                  color: _isDarkMode ? const Color(0xFF16202C) : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.photo_library_outlined, color: textMuted, size: 24),
                      const SizedBox(width: 8),
                      Text('4 Fotografías de Entrega Verificadas', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: textMuted)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOrganizationDashboard(
    Color surface,
    Color surfaceAlt,
    Color border,
    Color text,
    Color textMuted,
    bool isDesktop,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _orgCampaigns.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final isSel = _selectedCampaignIndex == i;
              return GestureDetector(
                onTap: () => setState(() => _selectedCampaignIndex = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSel ? const Color(0xFF10B981) : surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isSel ? const Color(0xFF10B981) : border),
                  ),
                  child: Row(
                    children: [
                      if (isSel) ...[
                        const Icon(Icons.check_circle_rounded, size: 13, color: Colors.white),
                        const SizedBox(width: 5),
                      ],
                      Text(
                        _orgCampaigns[i],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isSel ? Colors.white : textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 18),
        isDesktop
            ? Row(
                children: [
                  _buildAnimatedStatTile('Recaudación', 18.4, '\$18.4M COP', '+14% vs meta', const Color(0xFF10B981), surface, border, text, textMuted),
                  const SizedBox(width: 12),
                  _buildAnimatedStatTile('Aportantes', 142.0, '142', '+12 hoy', const Color(0xFF0284C7), surface, border, text, textMuted),
                  const SizedBox(width: 12),
                  _buildAnimatedStatTile('Cierre', 14.0, '14d', 'En cronograma', const Color(0xFFF59E0B), surface, border, text, textMuted),
                ],
              )
            : Column(
                children: [
                  Row(
                    children: [
                      _buildAnimatedStatTile('Recaudación', 18.4, '\$18.4M', '+14% meta', const Color(0xFF10B981), surface, border, text, textMuted),
                      const SizedBox(width: 10),
                      _buildAnimatedStatTile('Aportantes', 142.0, '142', '+12 hoy', const Color(0xFF0284C7), surface, border, text, textMuted),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildAnimatedStatTile('Cierre', 14.0, '14 días', 'En cronograma', const Color(0xFFF59E0B), surface, border, text, textMuted),
                    ],
                  ),
                ],
              ),
        const SizedBox(height: 20),
        isDesktop
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildChartBox(
                      title: 'Ritmo Semanal',
                      badge: 'Semanas 1 a 4',
                      surface: surface,
                      border: border,
                      text: text,
                      child: _InteractiveWeeklyBars(
                        hoveredIndex: _hoveredBarIndex,
                        onHover: (idx) => setState(() => _hoveredBarIndex = idx),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: _buildChartBox(
                      title: 'Proyección Fiduciaria ML',
                      badge: 'Intervalo 95%',
                      surface: surface,
                      border: border,
                      text: text,
                      child: _InteractivePredictionCurve(
                        hoveredX: _hoveredCurveX,
                        onHover: (x) => setState(() => _hoveredCurveX = x),
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  _buildChartBox(
                    title: 'Ritmo Semanal',
                    badge: 'Semanas 1 a 4',
                    surface: surface,
                    border: border,
                    text: text,
                    child: _InteractiveWeeklyBars(
                      hoveredIndex: _hoveredBarIndex,
                      onHover: (idx) => setState(() => _hoveredBarIndex = idx),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildChartBox(
                    title: 'Proyección Fiduciaria ML',
                    badge: 'Intervalo 95%',
                    surface: surface,
                    border: border,
                    text: text,
                    child: _InteractivePredictionCurve(
                      hoveredX: _hoveredCurveX,
                      onHover: (x) => setState(() => _hoveredCurveX = x),
                    ),
                  ),
                ],
              ),
      ],
    );
  }

  Widget _buildOrgAuditView(Color surface, Color border, Color text, Color textMuted) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Libro de Auditoría en Custodia', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: text)),
        const SizedBox(height: 6),
        Text('Contratos inteligentes de escrow y trazabilidad pública inmutable.', style: TextStyle(fontSize: 13, color: textMuted)),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAuditEntry('Contrato #CT-8819', 'Manaure Kits', 'Bloqueado en Escrow', '\$19.500.000 COP', const Color(0xFF10B981), text, textMuted),
              const Divider(height: 24),
              _buildAuditEntry('Contrato #CT-8812', 'Comedor Infantil', 'Liberación parcial hito 1', '\$4.500.000 COP', const Color(0xFF0284C7), text, textMuted),
              const Divider(height: 24),
              _buildAuditEntry('Contrato #CT-8790', 'Brigada Médica', 'Liquidación completa', '\$8.200.000 COP', const Color(0xFF64748B), text, textMuted),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAuditEntry(String id, String campaign, String status, String amount, Color badgeColor, Color text, Color textMuted) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(id, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: text)),
            const SizedBox(height: 2),
            Text(campaign, style: TextStyle(fontSize: 12, color: textMuted)),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(amount, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: text)),
            const SizedBox(height: 2),
            Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: badgeColor)),
          ],
        ),
      ],
    );
  }

  Widget _buildOrgFinancesView(Color surface, Color border, Color text, Color textMuted) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Finanzas & Solicitudes de Desembolso', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: text)),
        const SizedBox(height: 6),
        Text('Administración de fondos liberados y retiros bancarios certificados.', style: TextStyle(fontSize: 13, color: textMuted)),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: border)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Disponible para Retiro', style: TextStyle(fontSize: 12, color: textMuted)),
                    const SizedBox(height: 6),
                    Text('\$4.500.000 COP', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: const Color(0xFF10B981))),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: border)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Retención en Custodia', style: TextStyle(fontSize: 12, color: textMuted)),
                    const SizedBox(height: 6),
                    Text('\$15.000.000 COP', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: text)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSettingsView(Color surface, Color border, Color text, Color textMuted) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ajustes & Parámetros', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: text)),
        const SizedBox(height: 6),
        Text('Configuración de cuenta, seguridad y nodo fiduciario.', style: TextStyle(fontSize: 13, color: textMuted)),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: border)),
          child: Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.fingerprint_rounded, color: Color(0xFF10B981)),
                title: Text('Firma Digital Fiduciaria', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: text)),
                subtitle: Text('Certificado verificado mediante protocolo', style: TextStyle(fontSize: 12, color: textMuted)),
                trailing: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.shield_outlined, color: Color(0xFF0284C7)),
                title: Text('Nodo Fiduciario', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: text)),
                subtitle: Text('PaxNet v1.4.0 · Conexión cifrada', style: TextStyle(fontSize: 12, color: textMuted)),
                trailing: const Text('Activo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF10B981))),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAnimatedStatTile(
    String label,
    double targetVal,
    String displayFinal,
    String sub,
    Color accent,
    Color surface,
    Color border,
    Color text,
    Color textMuted,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textMuted)),
            const SizedBox(height: 4),
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 1000),
              curve: Curves.easeOutExpo,
              tween: Tween<double>(begin: 0, end: targetVal),
              builder: (context, val, _) => Text(
                targetVal > 100 ? '${val.toInt()}' : displayFinal,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: text),
              ),
            ),
            const SizedBox(height: 2),
            Text(sub, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: accent)),
          ],
        ),
      ),
    );
  }

  Widget _buildChartBox({
    required String title,
    required String badge,
    required Color surface,
    required Color border,
    required Color text,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: text)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(badge, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF10B981))),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildMobileBottomBar(Color surface, Color border, Color textMuted) {
    final isDonor = _currentRole == UserRole.donor;

    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: surface,
        border: Border(top: BorderSide(color: border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: isDonor
            ? [
                _buildMobileNavBtn(0, Icons.explore_outlined, 'Explorar', textMuted),
                _buildMobileNavBtn(1, Icons.volunteer_activism_outlined, 'Aportes', textMuted),
                _buildMobileNavBtn(2, Icons.photo_camera_back_outlined, 'Impacto', textMuted),
              ]
            : [
                _buildMobileNavBtn(0, Icons.grid_view_rounded, 'Tablero', textMuted),
                _buildMobileNavBtn(1, Icons.verified_user_outlined, 'Auditoría', textMuted),
                _buildMobileNavBtn(2, Icons.account_balance_outlined, 'Finanzas', textMuted),
              ],
      ),
    );
  }

  Widget _buildMobileNavBtn(int index, IconData icon, String label, Color textMuted) {
    final isSel = _navIndex == index;
    return GestureDetector(
      onTap: () => _onNavChange(index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: isSel ? const Color(0xFF10B981) : textMuted),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
              color: isSel ? const Color(0xFF10B981) : textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _InteractiveWeeklyBars extends StatelessWidget {
  final int? hoveredIndex;
  final ValueChanged<int?> onHover;

  const _InteractiveWeeklyBars({
    required this.hoveredIndex,
    required this.onHover,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onExit: (_) => onHover(null),
      child: GestureDetector(
        onTapDown: (details) {
          final box = context.findRenderObject() as RenderBox?;
          if (box == null) return;
          final x = details.localPosition.dx;
          final step = box.size.width / 4;
          onHover((x / step).floor().clamp(0, 3));
        },
        child: CustomPaint(
          size: const Size(double.infinity, 140),
          painter: _BarsInteractionPainter(hoveredIndex: hoveredIndex),
        ),
      ),
    );
  }
}

class _BarsInteractionPainter extends CustomPainter {
  final int? hoveredIndex;

  _BarsInteractionPainter({required this.hoveredIndex});

  @override
  void paint(Canvas canvas, Size size) {
    final values = [3.2, 4.8, 4.1, 6.35];
    final labels = ['\$3.2M', '\$4.8M', '\$4.1M', '\$6.35M'];
    const maxVal = 7.5;
    final bottomY = size.height - 22;
    final barW = size.width / (values.length * 2.5);

    final avgY = bottomY - (3.27 / maxVal) * (bottomY - 12);
    final dashedPaint = Paint()
      ..color = const Color(0xFFF59E0B).withValues(alpha: 0.6)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    double curX = 0;
    while (curX < size.width) {
      canvas.drawLine(Offset(curX, avgY), Offset(curX + 4, avgY), dashedPaint);
      curX += 8;
    }

    for (int i = 0; i < values.length; i++) {
      final xCenter = (i * 2 + 1) * (size.width / (values.length * 2));
      final barH = (values[i] / maxVal) * (bottomY - 12);
      final topY = bottomY - barH;
      final isHovered = hoveredIndex == i;

      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTRB(xCenter - barW / 2, topY, xCenter + barW / 2, bottomY),
        const Radius.circular(6),
      );

      final barPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isHovered
              ? [const Color(0xFF34D399), const Color(0xFF059669)]
              : [const Color(0xFF10B981), const Color(0xFF047857)],
        ).createShader(rrect.outerRect);

      canvas.drawRRect(rrect, barPaint);

      if (isHovered) {
        final tpValue = TextPainter(
          text: TextSpan(
            text: labels[i],
            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        final bgRect = RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(xCenter, topY - 12), width: tpValue.width + 10, height: 16),
          const Radius.circular(4),
        );
        canvas.drawRRect(bgRect, Paint()..color = const Color(0xFF047857));
        tpValue.paint(canvas, Offset(xCenter - tpValue.width / 2, topY - 20));
      }

      final tp = TextPainter(
        text: TextSpan(
          text: 'S${i + 1}',
          style: TextStyle(
            color: isHovered ? const Color(0xFF10B981) : const Color(0xFF7E92A7),
            fontSize: 10,
            fontWeight: isHovered ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(xCenter - tp.width / 2, bottomY + 5));
    }
  }

  @override
  bool shouldRepaint(covariant _BarsInteractionPainter oldDelegate) =>
      oldDelegate.hoveredIndex != hoveredIndex;
}

class _InteractivePredictionCurve extends StatelessWidget {
  final double? hoveredX;
  final ValueChanged<double?> onHover;

  const _InteractivePredictionCurve({
    required this.hoveredX,
    required this.onHover,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onExit: (_) => onHover(null),
      onHover: (e) => onHover(e.localPosition.dx),
      child: GestureDetector(
        onPanUpdate: (d) => onHover(d.localPosition.dx),
        onTapDown: (d) => onHover(d.localPosition.dx),
        child: CustomPaint(
          size: const Size(double.infinity, 140),
          painter: _CurveInteractionPainter(hoveredX: hoveredX),
        ),
      ),
    );
  }
}

class _CurveInteractionPainter extends CustomPainter {
  final double? hoveredX;

  _CurveInteractionPainter({required this.hoveredX});

  @override
  void paint(Canvas canvas, Size size) {
    final bottomY = size.height - 22;
    final h = bottomY - 12;

    final bandPath = Path()
      ..moveTo(size.width * 0.5, bottomY - h * 0.65)
      ..lineTo(size.width * 0.75, bottomY - h * 0.85)
      ..lineTo(size.width, bottomY - h * 0.95)
      ..lineTo(size.width, bottomY - h * 0.75)
      ..lineTo(size.width * 0.75, bottomY - h * 0.68)
      ..lineTo(size.width * 0.5, bottomY - h * 0.65)
      ..close();

    canvas.drawPath(
      bandPath,
      Paint()..color = const Color(0xFF10B981).withValues(alpha: 0.15)..style = PaintingStyle.fill,
    );

    final historyPath = Path()
      ..moveTo(0, bottomY)
      ..lineTo(size.width * 0.25, bottomY - h * 0.3)
      ..lineTo(size.width * 0.5, bottomY - h * 0.65);

    canvas.drawPath(
      historyPath,
      Paint()..color = const Color(0xFF10B981)..strokeWidth = 2.6..style = PaintingStyle.stroke,
    );

    final predPath = Path()
      ..moveTo(size.width * 0.5, bottomY - h * 0.65)
      ..lineTo(size.width * 0.75, bottomY - h * 0.78)
      ..lineTo(size.width, bottomY - h * 0.86);

    canvas.drawPath(
      predPath,
      Paint()..color = const Color(0xFF34D399)..strokeWidth = 2.0..style = PaintingStyle.stroke,
    );

    final dot = Offset(size.width * 0.5, bottomY - h * 0.65);
    canvas.drawCircle(dot, 4.5, Paint()..color = const Color(0xFF10B981));
    canvas.drawCircle(
      dot,
      4.5,
      Paint()..color = Colors.white..strokeWidth = 1.8..style = PaintingStyle.stroke,
    );

    const labels = ['S1', 'S2', 'Hoy', 'S4 (ML)', 'S5 (ML)'];
    for (int i = 0; i < labels.length; i++) {
      final x = (size.width / (labels.length - 1)) * i;
      final tp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(
            color: i == 2 ? const Color(0xFF10B981) : const Color(0xFF7E92A7),
            fontSize: 9.5,
            fontWeight: i == 2 ? FontWeight.w900 : FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset((x - tp.width / 2).clamp(0.0, size.width - tp.width), bottomY + 5));
    }
  }

  @override
  bool shouldRepaint(covariant _CurveInteractionPainter oldDelegate) =>
      oldDelegate.hoveredX != hoveredX;
}