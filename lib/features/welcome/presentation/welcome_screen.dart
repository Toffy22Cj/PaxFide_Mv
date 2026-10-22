import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../app/app_services.dart';
import '../../../app/qr_scanner_sheet.dart';
import '../../../app/text_size_button.dart';
import '../../../app/theme_mode_button.dart';
import '../../../shared/theme/pax_theme.dart';
import '../../../shared/widgets/pax_ui.dart';
import '../../campaigns/domain/campaign_search.dart';
import '../../campaigns/presentation/campaign_search_view.dart';
import '../../campaigns/presentation/campaign_summary_card.dart';

/// Un paso del recorrido (landing, "Desliza y acompaña su recorrido").
class _Step {
  const _Step(this.label, this.title, this.text, this.icon);
  final String label;
  final String title;
  final String text;
  final IconData icon;
}

/// Pasos 04 y 05: redactados con lo que dice la documentación (ADR-039: huellas encadenadas, agrupadas y ancladas en
/// una red EVM; los campos de referencia nunca piden nombres). PENDIENTES DE CONFIRMAR por el equipo (ver informe).
const _steps = [
  _Step(
    '01 / 05 · Donas',
    'Tu donación, de principio a fin',
    'Pagas por la pasarela. Cuando el pago se confirma, recibes un código para seguir tu donación paso a paso.',
    Icons.volunteer_activism_outlined,
  ),
  _Step(
    '02 / 05 · Se convierte en ayuda',
    'De saldo a cajas reales',
    'La organización compra los insumos y registra cada lote. El dinero y el lote quedan conectados, y cada lote '
        'tiene su propio QR.',
    Icons.inventory_2_outlined,
  ),
  _Step(
    '03 / 05 · Viaja y se reparte',
    'Sigue la caja, aunque se divida',
    'Cada despacho y cada recepción se registran al escanear el QR. Si un lote se divide, cada parte conserva su '
        'origen.',
    Icons.local_shipping_outlined,
  ),
  _Step(
    '04 / 05 · Queda sellado',
    'Una huella que se puede comprobar',
    'Cada registro guarda una huella digital enlazada a la anterior. Las huellas se agrupan y se anclan en una red '
        'blockchain pública para poder verificarlas.',
    Icons.verified_user_outlined,
  ),
  _Step(
    '05 / 05 · Llega',
    'Entregado, y lo puedes ver',
    'La entrega se registra con referencias, sin el nombre de quien recibe. Con tu código ves el recorrido completo.',
    Icons.task_alt,
  ),
];

/// `/welcome`: bienvenida sin sesión (M-01/M-02, adaptación del landing web; Enmienda 3 de ADR-043). Es la primera
/// pantalla sin sesión y la base de la pila con LOGGED_OUT.
///
/// Qué es PaxFide, escanear un QR, "tengo un código", el recorrido en cinco pasos, el catálogo con convocatorias
/// reales (`GET /public/campaigns`, sin sesión) y el botón fijo "Iniciar sesión". Sin datos de ejemplo presentados
/// como reales y sin campo de código: el código de seguimiento solo se escribe en `/tracking`.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  late final AppServices _services = AppScope.of(context);
  final _catalogKey = GlobalKey();
  late Future<List<CampaignSummary>> _campaigns = _fetch();

  Future<List<CampaignSummary>> _fetch() => _services.campaignSearch.search(const CampaignQuery());

  void _goToCatalog() {
    final ctx = _catalogKey.currentContext;
    if (ctx == null) return;
    final animate = !MediaQuery.disableAnimationsOf(context);
    Scrollable.ensureVisible(
      ctx,
      duration: animate ? const Duration(milliseconds: 350) : Duration.zero,
      curve: Curves.easeOut,
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

  @override
  Widget build(BuildContext context) {
    final theme = PaxTheme.welcome(Theme.of(context));
    return Theme(
      data: theme,
      child: Scaffold(
        appBar: AppBar(title: const Text('PaxFide'), actions: const [TextSizeButton(), ThemeModeButton()]),
        // Columna desplazable (no ListView perezosa): es corta y "Donar" necesita que el catálogo exista para bajar
        // hasta él.
        body: SingleChildScrollView(
          key: const Key('welcome.list'),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _Hero(),
              const SizedBox(height: 20),
              _Action(
                key: const Key('welcome.scan'),
                icon: Icons.qr_code_scanner,
                label: 'Escanear un código QR',
                onTap: () => scanQr(context),
              ),
              const SizedBox(height: 10),
              _Action(
                key: const Key('welcome.tracking'),
                icon: Icons.pin_outlined,
                label: 'Tengo un código de seguimiento',
                onTap: () => _services.router.push(AppRoutes.tracking),
              ),
              const SizedBox(height: 10),
              _Action(
                key: const Key('welcome.donate'),
                icon: Icons.volunteer_activism_outlined,
                label: 'Donar a una convocatoria',
                onTap: _goToCatalog,
              ),
              const SizedBox(height: 28),
              Text('Cómo funciona', style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Acompaña el recorrido de una donación.',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              for (final (i, step) in _steps.indexed) _StepCard(step, key: Key('welcome.step.${i + 1}')),
              const SizedBox(height: 4),
              Text(
                'Cada paso queda registrado y lo puedes consultar con tu código cuando quieras.',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              _TrackingCard(onOpen: () => _services.router.push(AppRoutes.tracking)),
              const SizedBox(height: 16),
              _OrganizationCard(onOpen: () => _services.router.push(AppRoutes.register)),
              const SizedBox(height: 28),
              KeyedSubtree(key: _catalogKey, child: _catalogHeader(theme)),
              const SizedBox(height: 8),
              _catalog(),
            ],
          ),
        ),
        // M-02: "Iniciar sesión" fijo, al alcance del pulgar.
        bottomNavigationBar: SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
            ),
            child: Semantics(
              button: true,
              label: 'Iniciar sesión',
              excludeSemantics: true,
              child: FilledButton(
                key: const Key('welcome.login'),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
                onPressed: () => _services.router.push(AppRoutes.login),
                child: const Text('Iniciar sesión'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _catalogHeader(ThemeData theme) => Row(
    children: [
      Expanded(child: Text('Convocatorias abiertas', style: theme.textTheme.titleLarge)),
      TextButton(key: const Key('welcome.campaigns.all'), onPressed: _openAll, child: const Text('Ver todas')),
    ],
  );

  Widget _catalog() => FutureBuilder<List<CampaignSummary>>(
    future: _campaigns,
    builder: (context, snap) {
      if (snap.connectionState != ConnectionState.done) {
        return const Column(
          key: Key('welcome.campaigns.loading'),
          children: [CampaignSkeletonCard(), CampaignSkeletonCard(), CampaignSkeletonCard()],
        );
      }
      if (snap.hasError) {
        return SectionCard(
          key: const Key('welcome.campaigns.error'),
          child: Row(
            children: [
              const Expanded(child: Text('No pudimos cargar las convocatorias.')),
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
        return const SectionCard(
          key: Key('welcome.campaigns.empty'),
          child: Text('No hay convocatorias abiertas en este momento.'),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final c in items.take(3))
            CampaignFigureCard(
              c,
              key: Key('welcome.campaign.${c.publicCode}'),
              detailsKey: Key('welcome.campaign.${c.publicCode}.details'),
              onOpen: () => _services.router.push(AppRoutes.campaignPath(c.publicCode)),
            ),
        ],
      );
    },
  );
}

/// Qué es PaxFide: marca, título del landing y una frase.
class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        const BrandHeader(),
        const SizedBox(height: 20),
        Text(
          'Tu donación, de principio a fin',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'Dona a una convocatoria y sigue tu aporte desde el pago hasta la entrega.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Acción a lo ancho, en píldora, con ícono.
class _Action extends StatelessWidget {
  const _Action({super.key, required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: OutlinedButton.icon(onPressed: onTap, icon: Icon(icon, size: 20), label: Text(label)),
  );
}

/// Un paso del recorrido: etiqueta "01 / 05" en mono, título, texto e ícono.
class _StepCard extends StatelessWidget {
  const _StepCard(this.step, {super.key});
  final _Step step;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconCircle(step.icon, size: 44),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.label.toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      letterSpacing: 0.5,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(step.title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(step.text, style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "¿Ya donaste?": lleva a la pantalla real de seguimiento. Sin campo ni códigos de ejemplo: el código es privado.
class _TrackingCard extends StatelessWidget {
  const _TrackingCard({required this.onOpen});
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => HighlightCard(
    key: const Key('welcome.trackingCard'),
    padding: const EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('¿Ya donaste? Sigue tu donación.', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        const Text('Escribe o pega el código que recibiste al donar y verás en qué punto va.'),
        const SizedBox(height: 12),
        Semantics(
          button: true,
          label: 'Seguir mi donación',
          excludeSemantics: true,
          child: FilledButton(
            key: const Key('welcome.tracking.card'),
            onPressed: onOpen,
            child: const Text('Seguir mi donación'),
          ),
        ),
      ],
    ),
  );
}

/// "¿Eres una organización?" (landing). En el móvil se crea la cuenta; la organización se registra y se verifica
/// desde la web (decisión 4: en el móvil solo se registran donantes).
class _OrganizationCard extends StatelessWidget {
  const _OrganizationCard({required this.onOpen});
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    Widget point(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
    return SectionCard(
      key: const Key('welcome.organizationCard'),
      title: '¿Eres una organización?',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Crea tu cuenta y registra la organización desde la web de PaxFide. Un administrador la verifica antes de '
            'que publique convocatorias.',
            style: TextStyle(color: muted),
          ),
          point(Icons.event_note_outlined, 'Convocatorias con meta y fechas'),
          point(Icons.qr_code_2, 'Lotes con QR y recorrido visible'),
          point(Icons.fact_check_outlined, 'Historial que se puede verificar'),
          const SizedBox(height: 14),
          Semantics(
            button: true,
            label: 'Crear mi cuenta',
            excludeSemantics: true,
            child: OutlinedButton(
              key: const Key('welcome.organization'),
              onPressed: onOpen,
              child: const Text('Crear mi cuenta'),
            ),
          ),
        ],
      ),
    );
  }
}
