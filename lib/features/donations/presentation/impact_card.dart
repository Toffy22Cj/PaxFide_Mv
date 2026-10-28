import 'package:flutter/material.dart';

import '../../../shared/money.dart';
import '../../../shared/quantity.dart';
import '../../../shared/widgets/amount_bars.dart';
import '../domain/impact.dart';

/// M-21: panel "Mi impacto" (`GET /account/impact`): donaciones confirmadas, convocatorias apoyadas, total donado
/// por moneda y barras con las unidades entregadas en esas convocatorias. Sin datos (o con error), no ocupa espacio.
class ImpactCard extends StatefulWidget {
  const ImpactCard({super.key, required this.source});
  final ImpactSource source;

  @override
  State<ImpactCard> createState() => _ImpactCardState();
}

class _ImpactCardState extends State<ImpactCard> {
  late final Future<MyImpact?> _impact = widget.source.myImpact().catchError((_) => null);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MyImpact?>(
      future: _impact,
      builder: (context, snap) {
        final i = snap.data;
        if (i == null) return const SizedBox.shrink();
        final text = Theme.of(context).textTheme;
        final muted = Theme.of(context).colorScheme.onSurfaceVariant;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Card(
            key: const Key('impact'),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mi impacto', style: text.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    '${i.donationsCount} ${i.donationsCount == 1 ? 'donación confirmada' : 'donaciones confirmadas'} · '
                    '${i.campaignsSupported} '
                    '${i.campaignsSupported == 1 ? 'convocatoria apoyada' : 'convocatorias apoyadas'}',
                    key: const Key('impact.summary'),
                  ),
                  for (final t in i.totals)
                    Text('Donado: ${formatMinorUnits(t.amount, t.currency)}', style: text.titleSmall),
                  if (i.deliveredUnits.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('Entregado en las convocatorias que apoyaste', style: text.labelLarge),
                    const SizedBox(height: 4),
                    AmountBars(
                      bars: [
                        for (final u in i.deliveredUnits)
                          AmountBar(
                            u.unitOfMeasure,
                            num.tryParse(u.quantity) ?? 0,
                            formatQuantity(u.quantity),
                          ),
                      ],
                    ),
                  ],
                  if (i.truncated) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Se cuentan tus 100 donaciones más recientes.',
                      key: const Key('impact.truncated'),
                      style: text.bodySmall?.copyWith(color: muted),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
