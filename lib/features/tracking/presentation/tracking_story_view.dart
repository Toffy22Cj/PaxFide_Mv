import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/dates.dart';
import '../../../shared/money.dart';
import '../../../shared/motion/pax_motion.dart';
import '../../../shared/quantity.dart';
import '../../../shared/theme/pax_tokens.dart';
import '../../../shared/widgets/loaders.dart';
import '../../../shared/widgets/pax_ui.dart';
import '../../physical_assets/domain/lifecycle_status.dart';
import '../data/tracking_api.dart';
import '../domain/tracking_story.dart';

/// La historia de una donación en el teléfono, como la línea de tiempo de la web (`TrackingTimeline`,
/// `paxfide-linea-tiempo.html`): las tres columnas de la web pasan a una sola. Arriba el árbol (Donada → lotes →
/// sublotes, con sus pasos), debajo la carretera en serpiente de un lote y, al tocar cualquier paso, su detalle en una
/// hoja inferior (la columna «Detalle y verificación» de la web).

String custodianLabel(String c) => switch (c) {
  'LOGISTICS_PARTNER' => 'Operador logístico',
  'REGIONAL_WAREHOUSE' => 'Bodega regional',
  'LAST_MILE_CARRIER' => 'Transporte de última milla',
  'LOCAL_ALLY' => 'Aliado local',
  'UNCATEGORIZED' || '' => 'Sin categoría',
  _ => c,
};

String lifecycleLabel(String wire) => switch (LifecycleStatus.fromWire(wire)) {
  LifecycleStatus.registered => 'Registrado',
  LifecycleStatus.dispatched => 'En camino',
  LifecycleStatus.received => 'Recibido',
  LifecycleStatus.delivered => 'Entregado',
  LifecycleStatus.depleted => 'Dividido',
  null => wire,
};

/// "3 oct 2026, 09:10" en la hora del teléfono; el texto original si no es una fecha.
String formatEventTime(String iso) => shortDateTime(iso);

/// "a3f9c8d1…c801": el principio y el final de una huella.
String shortHash(String h) => h.length <= 16 ? h : '${h.substring(0, 8)}…${h.substring(h.length - 6)}';

/// Sello de un paso (G-3), con los textos de la web.
(String, Tone, IconData) anchorLabel(String status) => switch (status) {
  'ANCHORED' => ('Anclado en blockchain', Tone.success, Icons.lock_outline),
  'IN_BATCH' => ('En el próximo anclaje', Tone.neutral, Icons.schedule),
  'UNDER_REVIEW' => ('En revisión', Tone.pending, Icons.warning_amber_rounded),
  _ => ('Esperando anclaje', Tone.neutral, Icons.schedule),
};

IconData eventIcon(String wire) => switch (TrackingEvent.fromWire(wire)) {
  TrackingEvent.registered => Icons.storage_rounded,
  TrackingEvent.dispatched => Icons.local_shipping_outlined,
  TrackingEvent.received => Icons.inventory_2_outlined,
  TrackingEvent.delivered => Icons.favorite_border,
  TrackingEvent.split => Icons.call_split,
  TrackingEvent.splitCompensated => Icons.undo,
  TrackingEvent.custodyTransferred => Icons.swap_horiz,
  TrackingEvent.depleted => Icons.remove,
  null => Icons.circle_outlined,
};

/// Nombre del lote: su tipo y su cantidad. Nunca un nombre de lote inventado.
String lotTitle(LogisticsItem l) =>
    [l.assetType, formatQuantityWithUnit(l.quantity, l.unitOfMeasure)].where((x) => x.isNotEmpty).join(' · ');

/// Recorrido de un lote: cargando, listo o con error.
sealed class HistoryState {
  const HistoryState();
}

class HistoryLoading extends HistoryState {
  const HistoryLoading();
}

class HistoryReady extends HistoryState {
  const HistoryReady(this.entries);
  final List<HistoryEntry> entries;
}

class HistoryFailed extends HistoryState {
  const HistoryFailed();
}

/// Lo que se sabe del pago (la raíz «Donada»).
class PaymentFacts {
  const PaymentFacts({this.firstClearedAt, this.lastClearedAt, required this.amount, this.currency});
  final String? firstClearedAt;
  final String? lastClearedAt;
  final int amount;
  final String? currency;
}

// ------------------------------------------------------------------------------------------- Detalle (hoja)

/// Abre el detalle de un paso (o del pago, si [entry] es nulo) en una hoja inferior de 350 ms.
Future<void> showStepDetail(
  BuildContext context, {
  HistoryEntry? entry,
  int index = 0,
  String? assetTitle,
  PaymentFacts? payment,
}) => showModalBottomSheet<void>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  showDragHandle: true,
  sheetAnimationStyle: AnimationStyle(
    duration: PaxMotion.of(context, const Duration(milliseconds: 350)),
    reverseDuration: PaxMotion.of(context, PaxMotion.normal),
    curve: Curves.easeOutCubic,
  ),
  builder: (sheet) => ConstrainedBox(
    constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(sheet).height * 0.85),
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: entry == null ? _PaymentDetail(payment!) : _StepDetail(entry: entry, index: index, assetTitle: assetTitle),
    ),
  ),
);

class _DetailHead extends StatelessWidget {
  const _DetailHead({required this.icon, required this.title, this.subtitle, required this.text});
  final IconData icon;
  final String title;
  final String? subtitle;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: s.primary, borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: s.onPrimary),
        ),
        const SizedBox(height: 10),
        Text(title, style: theme.textTheme.titleLarge),
        if (subtitle != null) Text(subtitle!, style: theme.textTheme.bodySmall?.copyWith(color: s.onSurfaceVariant)),
        const SizedBox(height: 6),
        Text(text, style: theme.textTheme.bodyMedium?.copyWith(color: s.onSurfaceVariant)),
        const SizedBox(height: 12),
        Divider(color: s.outlineVariant),
      ],
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta(this.label, this.value);
  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
          Expanded(
            child: DefaultTextStyle.merge(
              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              child: value,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentDetail extends StatelessWidget {
  const _PaymentDetail(this.payment);
  final PaymentFacts payment;

  @override
  Widget build(BuildContext context) {
    final p = payment;
    final different = p.lastClearedAt != null && p.lastClearedAt != p.firstClearedAt;
    return Column(
      key: const Key('tracking.detail.payment'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _DetailHead(
          icon: Icons.credit_card,
          title: 'Donada',
          text: 'Tu pago se confirmó y el dinero quedó en el fondo de la convocatoria.',
        ),
        _Meta('Monto', Text(formatMinorUnits(p.amount, p.currency))),
        _Meta('Pago confirmado', Text(p.firstClearedAt == null ? 'Todavía no' : formatEventTime(p.firstClearedAt!))),
        if (different) _Meta('Última liquidación', Text(formatEventTime(p.lastClearedAt!))),
      ],
    );
  }
}

class _StepDetail extends StatelessWidget {
  const _StepDetail({required this.entry, required this.index, this.assetTitle});
  final HistoryEntry entry;
  final int index;
  final String? assetTitle;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final known = TrackingEvent.fromWire(e.eventType);
    final (seal, tone, sealIcon) = anchorLabel(e.anchorStatus);
    final proof = e.anchorProof;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      key: const Key('tracking.detail.step'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DetailHead(
          icon: eventIcon(e.eventType),
          title: eventLabel(e.eventType),
          subtitle: assetTitle,
          text: known?.description ?? 'Registro del recorrido del lote.',
        ),
        _Meta('Evento', Text(e.eventType, style: const TextStyle(fontFamily: 'monospace'))),
        _Meta('Custodio responsable', Text(custodianLabel(e.custodianCategory))),
        _Meta('Zona', Text(e.locationZone.isEmpty ? noPublicZone : e.locationZone)),
        _Meta('Fecha', Text(e.timestamp.isEmpty ? 'Sin fecha' : formatEventTime(e.timestamp))),
        if (e.eventHash case final hash?)
          _Meta(
            'Huella criptográfica',
            _HashValue(hash: hash, label: 'Huella del registro', key: Key('tracking.step.$index.hash')),
          ),
        if (e.eventType == TrackingEvent.delivered.wire && e.evidenceRegistered != null)
          _Meta(
            'Foto de la entrega',
            e.evidenceRegistered!
                ? Column(
                    key: Key('tracking.step.$index.evidence'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Con foto de entrega'),
                      if (e.evidenceRef case final ref?) _HashValue(hash: ref, label: 'Huella de la foto'),
                    ],
                  )
                : const Text('Sin foto'),
          ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: StatusChip(seal, key: Key('tracking.step.$index.seal'), icon: sealIcon, tone: tone),
        ),
        const SizedBox(height: 8),
        if (e.anchorStatus == 'ANCHORED' && proof == null)
          Text(
            'Este paso se ancló en un lote antiguo, antes de que se guardaran las pruebas: su huella no se puede '
            'comprobar desde aquí.',
            style: TextStyle(color: muted, fontSize: 13),
          ),
        if (proof != null)
          Text(
            'Anclado en ${proof.network}${proof.anchoredAt == null ? '' : ' el ${formatEventTime(proof.anchoredAt!)}'}'
            ' · transacción ${shortHash(proof.transactionHash)}',
            key: Key('tracking.step.$index.proof'),
            style: TextStyle(color: muted, fontSize: 13),
          ),
      ],
    );
  }
}

/// La huella recortada; tocarla copia la completa (y se lee completa en voz alta).
class _HashValue extends StatelessWidget {
  const _HashValue({super.key, required this.hash, required this.label});
  final String hash;
  final String label;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Semantics(
      label: '$label: $hash. Toca para copiarla.',
      excludeSemantics: true,
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () {
          Clipboard.setData(ClipboardData(text: hash));
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text('Huella copiada.')));
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: s.secondaryContainer, borderRadius: BorderRadius.circular(6)),
                child: Text(
                  shortHash(hash),
                  style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: s.onSecondaryContainer),
                ),
              ),
              Text(
                'Copiar',
                style: TextStyle(color: s.primary, decoration: TextDecoration.underline, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------------------------------- Árbol

/// Donada → lotes → sublotes, con los pasos de cada lote. Tocar un paso (o la raíz) abre su detalle.
class TrackingTree extends StatelessWidget {
  const TrackingTree({
    super.key,
    required this.items,
    required this.payment,
    required this.histories,
    required this.onRetry,
  });
  final List<LogisticsItem> items;
  final PaymentFacts payment;
  final Map<String, HistoryState> histories;
  final ValueChanged<String> onRetry;

  @override
  Widget build(BuildContext context) {
    final roots = buildAssetTree<LogisticsItem>(items, ref: (i) => i.assetRef, parent: (i) => i.parentAssetRef);
    return Column(
      key: const Key('tracking.tree'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RootNode(payment),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'Todavía no hay bienes asociados a tu donación.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
        for (final node in roots) ...[
          const _RoadLink(),
          _LotCard(node: node, depth: 0, items: items, histories: histories, onRetry: onRetry),
        ],
      ],
    );
  }
}

class _RootNode extends StatelessWidget {
  const _RootNode(this.payment);
  final PaymentFacts payment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Card(
        key: const Key('tracking.root'),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => showStepDetail(context, payment: payment),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _NodeIcon(Icons.credit_card),
                const SizedBox(width: 12),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Donada', style: theme.textTheme.titleSmall),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _Chip(formatMinorUnits(payment.amount, payment.currency)),
                          _Chip(
                            payment.firstClearedAt == null
                                ? 'Pago sin confirmar'
                                : formatEventTime(payment.firstClearedAt!),
                            mono: payment.firstClearedAt != null,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tramo de carretera de la raíz a cada lote (boceto: tramo oscuro con línea discontinua).
class _RoadLink extends StatelessWidget {
  const _RoadLink();

  @override
  Widget build(BuildContext context) => Center(
    child: CustomPaint(size: const Size(10, 16), painter: _RoadLinkPainter(Theme.of(context).colorScheme.onSurface)),
  );
}

class _RoadLinkPainter extends CustomPainter {
  const _RoadLinkPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = color.withValues(alpha: 0.9));
    final dash = Paint()
      ..color = PaxTokens.brandYellow50
      ..strokeWidth = 2;
    for (var y = 0.0; y < size.height; y += 6) {
      canvas.drawLine(Offset(size.width / 2, y), Offset(size.width / 2, y + 3), dash);
    }
  }

  @override
  bool shouldRepaint(_RoadLinkPainter old) => old.color != color;
}

class _NodeIcon extends StatelessWidget {
  const _NodeIcon(this.icon, {this.seal});
  final IconData icon;
  final String? seal;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    final review = seal == 'UNDER_REVIEW';
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: s.primary, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 18, color: s.onPrimary),
        ),
        if (seal != null)
          Positioned(
            top: -5,
            right: -5,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: review ? s.tertiaryContainer : s.secondaryContainer,
                border: Border.all(color: s.surface),
              ),
              child: Icon(
                anchorLabel(seal!).$3,
                size: 10,
                color: review ? s.onTertiaryContainer : s.onSecondaryContainer,
              ),
            ),
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text, {this.mono = false});
  final String text;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: s.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: s.outlineVariant),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, color: s.onSurfaceVariant, fontFamily: mono ? 'monospace' : null),
      ),
    );
  }
}

class _LotCard extends StatelessWidget {
  const _LotCard({
    required this.node,
    required this.depth,
    required this.items,
    required this.histories,
    required this.onRetry,
  });
  final TreeNode<LogisticsItem> node;
  final int depth;
  final List<LogisticsItem> items;
  final Map<String, HistoryState> histories;
  final ValueChanged<String> onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = theme.colorScheme;
    final l = node.item;
    final index = items.indexOf(l);
    final history = histories[l.assetRef] ?? const HistoryLoading();
    final title = lotTitle(l);
    final body = switch (history) {
      HistoryLoading() => const Padding(
        padding: EdgeInsets.all(8),
        child: Center(child: ChainCubesLoader()),
      ),
      HistoryFailed() => Row(
        children: [
          const Expanded(child: Text('No pudimos cargar el recorrido.')),
          TextButton(onPressed: () => onRetry(l.assetRef), child: const Text('Reintentar')),
        ],
      ),
      HistoryReady(entries: final e) when e.isEmpty => Text(
        'Sin movimientos registrados.',
        style: TextStyle(color: s.onSurfaceVariant),
      ),
      HistoryReady(entries: final e) => _Steps(entries: e, lot: index, assetTitle: title),
    };
    final card = Container(
      key: Key('tracking.item.$index'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: depth > 0 ? s.surfaceContainerHighest : s.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: s.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (depth > 0)
            Text(
              'SUBLOTE',
              style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: s.tertiary, letterSpacing: 0.6),
            ),
          Text(title, style: theme.textTheme.titleSmall),
          const SizedBox(height: 2),
          Text(
            [
              lifecycleLabel(l.lifecycleStatus),
              l.locationZone.isEmpty ? noPublicZone : l.locationZone,
              custodianLabel(l.custodianCategory),
            ].join(' · '),
            style: theme.textTheme.bodySmall?.copyWith(color: s.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Divider(height: 1, color: s.outlineVariant),
          const SizedBox(height: 8),
          AnimatedSize(
            duration: PaxMotion.of(context, PaxMotion.normal),
            curve: PaxMotion.standard,
            alignment: Alignment.topCenter,
            child: body,
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(left: depth > 0 ? 16 : 0),
          child: card,
        ),
        for (final child in node.children) ...[
          const SizedBox(height: 12),
          Padding(
            padding: EdgeInsets.only(left: depth > 0 ? 16 : 0),
            child: _LotCard(node: child, depth: depth + 1, items: items, histories: histories, onRetry: onRetry),
          ),
        ],
      ],
    );
  }
}

class _Steps extends StatelessWidget {
  const _Steps({required this.entries, required this.lot, required this.assetTitle});
  final List<HistoryEntry> entries;
  final int lot;
  final String assetTitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = theme.colorScheme;
    final truck = showsTruck([for (final e in entries) e.eventType]);
    return Column(
      key: Key('tracking.lot.$lot.steps'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, e) in entries.indexed)
          Stack(
            clipBehavior: Clip.none,
            children: [
              // La vía entre un paso y el siguiente.
              if (i < entries.length - 1)
                Positioned(
                  left: 23,
                  top: 46,
                  bottom: -2,
                  child: Container(
                    width: 6,
                    decoration: BoxDecoration(
                      color: s.onSurface.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              InkWell(
                key: Key('tracking.step.$lot.$i'),
                borderRadius: BorderRadius.circular(8),
                onTap: () => showStepDetail(context, entry: e, index: i, assetTitle: assetTitle),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _NodeIcon(eventIcon(e.eventType), seal: e.anchorStatus),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 2,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(eventLabel(e.eventType), style: theme.textTheme.titleSmall),
                                _Chip(e.timestamp.isEmpty ? 'Sin fecha' : formatEventTime(e.timestamp), mono: true),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                _Chip(e.locationZone.isEmpty ? noPublicZone : e.locationZone),
                                _Chip(custodianLabel(e.custodianCategory)),
                                if (e.anchorStatus == 'UNDER_REVIEW') _Chip(anchorLabel(e.anchorStatus).$1),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: s.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
            ],
          ),
        if (truck)
          const Align(
            alignment: Alignment.centerRight,
            child: TruckLoader(key: Key('tracking.truck'), width: 160),
          ),
      ],
    );
  }
}

// ------------------------------------------------------------------------------------------- Serpiente

/// Geometría de la serpiente: estaciones alternas a izquierda y derecha; todos los tramos miden lo mismo.
abstract final class Snake {
  static const width = 300.0, left = 40.0, right = 260.0, top = 40.0, gap = 100.0;

  static List<Offset> points(int n) => [
    for (var i = 0; i < (n < 1 ? 1 : n); i++) Offset(i.isEven ? left : right, top + i * gap),
  ];

  static Path path(List<Offset> p) {
    final path = Path()..moveTo(p.first.dx, p.first.dy);
    for (var i = 1; i < p.length; i++) {
      final a = p[i - 1], b = p[i];
      path.cubicTo(a.dx, a.dy + 55, b.dx, b.dy - 55, b.dx, b.dy);
    }
    return path;
  }
}

class _Station {
  const _Station(this.label, this.at, this.icon, {this.entry, this.index = 0});
  final String label;
  final String? at;
  final IconData icon;
  final HistoryEntry? entry;
  final int index;
}

/// «Recorrido de tu donación»: un lote a la vez (pestañas si hay varios) como una carretera en serpiente. El camión
/// conduce hasta la última estación solo si el último evento es un despacho (va en camino); si no, queda parado en
/// su estación.
class SnakeRoute extends StatefulWidget {
  const SnakeRoute({super.key, required this.items, required this.histories, required this.payment, this.campaignLine});
  final List<LogisticsItem> items;
  final Map<String, HistoryState> histories;
  final PaymentFacts payment;
  final String? campaignLine;

  @override
  State<SnakeRoute> createState() => _SnakeRouteState();
}

class _SnakeRouteState extends State<SnakeRoute> with SingleTickerProviderStateMixin {
  int _active = 0;
  late final AnimationController _drive = AnimationController(vsync: this, duration: PaxMotion.normal * 3);
  late final Animation<double> _t = CurvedAnimation(parent: _drive, curve: PaxMotion.inOut);
  String? _drivenFor;

  @override
  void dispose() {
    _drive.dispose();
    super.dispose();
  }

  /// Arranca el viaje del camión una vez por lote y recorrido.
  void _maybeDrive(String key, bool driving) {
    if (_drivenFor == key) return;
    _drivenFor = key;
    if (driving && !PaxMotion.reduce(context)) {
      _drive.forward(from: 0);
    } else {
      _drive.value = 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = theme.colorScheme;
    final items = widget.items;
    final active = _active.clamp(0, items.length - 1);
    final item = items[active];
    final history = widget.histories[item.assetRef] ?? const HistoryLoading();
    final steps = history is HistoryReady ? history.entries : const <HistoryEntry>[];
    final stations = [
      if (widget.payment.firstClearedAt != null)
        _Station('Pago confirmado', widget.payment.firstClearedAt, Icons.credit_card),
      for (final (i, e) in steps.indexed)
        _Station(eventLabel(e.eventType), e.timestamp, eventIcon(e.eventType), entry: e, index: i),
    ];
    final n = stations.length;
    final driving = n > 1 && showsTruck([for (final e in steps) e.eventType]);
    if (history is HistoryReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _maybeDrive('${item.assetRef}:$n', driving);
      });
    }
    final points = Snake.points(n);
    final path = Snake.path(points);
    final height = points.last.dy + Snake.top;
    final title = lotTitle(item);
    return Card(
      key: const Key('tracking.snake'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'LOTE · $title'.toUpperCase(),
              style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: s.tertiary, letterSpacing: 0.5),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: StatusChip(
                '${lifecycleLabel(item.lifecycleStatus)}'
                '${n > 0 ? ' · $n ${n == 1 ? 'estación' : 'estaciones'}' : ''}',
              ),
            ),
            const SizedBox(height: 6),
            Text('Recorrido de tu donación', style: theme.textTheme.titleMedium),
            if (widget.campaignLine != null)
              Text(widget.campaignLine!, style: theme.textTheme.bodySmall?.copyWith(color: s.onSurfaceVariant)),
            if (items.length > 1) ...[
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var i = 0; i < items.length; i++) ...[
                      ChoiceChip(
                        key: Key('tracking.snake.tab.$i'),
                        label: Text(_tabLabel(items, i)),
                        selected: i == active,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _active = i),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Divider(height: 1, color: s.outlineVariant),
            AnimatedSwitcher(
              duration: PaxMotion.of(context, PaxMotion.normal),
              child: switch (history) {
                HistoryLoading() => const Padding(
                  key: ValueKey('loading'),
                  padding: EdgeInsets.all(16),
                  child: Center(child: ChainCubesLoader()),
                ),
                _ when n == 0 => Padding(
                  key: const ValueKey('empty'),
                  padding: const EdgeInsets.all(16),
                  child: Text('Este bien todavía no tiene estaciones.', style: TextStyle(color: s.onSurfaceVariant)),
                ),
                _ => Center(
                  key: ValueKey('road.${item.assetRef}'),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: SizedBox(
                      width: Snake.width,
                      height: height,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: RepaintBoundary(child: CustomPaint(painter: _RoadPainter(path, s.onSurface))),
                          ),
                          for (final (i, st) in stations.indexed)
                            _StationButton(
                              station: st,
                              point: points[i],
                              rightSide: i.isOdd,
                              assetTitle: title,
                              payment: widget.payment,
                            ),
                          // El camión en la carretera.
                          Positioned.fill(
                            child: IgnorePointer(
                              child: RepaintBoundary(
                                child: CustomPaint(
                                  key: const Key('tracking.snake.truck'),
                                  painter: _SnakeTruckPainter(
                                    _t,
                                    path,
                                    from: driving ? (n - 2) / (n - 1) : (n <= 1 ? 0 : 1),
                                    to: n <= 1 ? 0 : 1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Nombre de la pestaña; si dos lotes se llaman igual, lleva su número.
String _tabLabel(List<LogisticsItem> items, int i) {
  final name = items[i].assetType.isEmpty ? 'Bien ${i + 1}' : items[i].assetType;
  final same = items.where((x) => (x.assetType.isEmpty ? '' : x.assetType) == items[i].assetType).length;
  return same > 1 ? '$name ${i + 1}' : name;
}

class _StationButton extends StatelessWidget {
  const _StationButton({
    required this.station,
    required this.point,
    required this.rightSide,
    required this.assetTitle,
    required this.payment,
  });
  final _Station station;
  final Offset point;
  final bool rightSide;
  final String assetTitle;
  final PaymentFacts payment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = theme.colorScheme;
    final label = Container(
      constraints: const BoxConstraints(maxWidth: 150),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: s.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: s.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: rightSide ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(station.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          if (station.at case final at? when at.isNotEmpty)
            Text(
              shortDate(at),
              style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: s.onSurfaceVariant),
            ),
        ],
      ),
    );
    final icon = Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(color: s.primary, borderRadius: BorderRadius.circular(10)),
      child: Icon(station.icon, size: 18, color: s.onPrimary),
    );
    final e = station.entry;
    final button = InkWell(
      key: Key('tracking.station.${e == null ? 'payment' : station.index}'),
      borderRadius: BorderRadius.circular(10),
      onTap: () => e == null
          ? showStepDetail(context, payment: payment)
          : showStepDetail(context, entry: e, index: station.index, assetTitle: assetTitle),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: rightSide ? [label, const SizedBox(width: 8), icon] : [icon, const SizedBox(width: 8), label],
      ),
    );
    return rightSide
        ? Positioned(right: Snake.width - point.dx - 18, top: point.dy - 18, child: button)
        : Positioned(left: point.dx - 18, top: point.dy - 18, child: button);
  }
}

class _RoadPainter extends CustomPainter {
  _RoadPainter(this.path, this.color);
  final Path path;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: 0.9),
    );
    // Línea discontinua de 8 y 8 sobre la carretera.
    final dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = PaxTokens.brandYellow50;
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 16) {
        canvas.drawPath(m.extractPath(d, d + 8), dash);
      }
    }
  }

  @override
  bool shouldRepaint(_RoadPainter old) => old.path != path || old.color != color;
}

/// El camión sobre la carretera, de [from] a [to] (fracciones del recorrido) según [t].
class _SnakeTruckPainter extends CustomPainter {
  _SnakeTruckPainter(this.t, this.path, {required this.from, required this.to}) : super(repaint: t);
  final Animation<double> t;
  final Path path;
  final double from;
  final double to;

  @override
  void paint(Canvas canvas, Size size) {
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;
    final total = metrics.fold<double>(0, (a, m) => a + m.length);
    var d = total * (from + (to - from) * t.value);
    ui.Tangent? tan;
    for (final m in metrics) {
      if (d <= m.length) {
        tan = m.getTangentForOffset(d);
        break;
      }
      d -= m.length;
    }
    tan ??= metrics.last.getTangentForOffset(metrics.last.length);
    if (tan == null) return;
    const scale = 40 / 66;
    canvas
      ..save()
      // Sobre la carretera; al llegar a su estación sube 18 px para quedar encima del icono.
      ..translate(tan.position.dx - 33 * scale, tan.position.dy - 42 * scale - 18 * t.value)
      ..scale(scale);
    TruckPainter.drawTruck(canvas, PaxTokens.brandGreen50);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SnakeTruckPainter old) => old.t != t || old.path != path || old.from != from || old.to != to;
}
