import 'package:flutter/material.dart';

import '../../../shared/widgets/amount_bars.dart';
import '../domain/impact.dart';

/// M-21: panel "Mi impacto" con barras por convocatoria. Sin datos (o con error), no ocupa espacio.
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
                    '${i.unitsDelivered} ${i.unitsDelivered == 1 ? 'bien entregado' : 'bienes entregados'} · '
                    '${i.distinctRecipients} ${i.distinctRecipients == 1 ? 'persona ayudada' : 'personas ayudadas'}',
                  ),
                  const SizedBox(height: 8),
                  AmountBars(
                    bars: [
                      for (final c in i.byCampaign)
                        AmountBar(c.campaignTitle, c.unitsDelivered, '${c.unitsDelivered} entregados'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
