/// Progreso de una convocatoria (M-09): porcentaje de la meta, días que quedan y si la meta ya se alcanzó.
class CampaignProgress {
  const CampaignProgress({required this.fraction, required this.daysLeft, required this.reached});

  /// Lo acreditado sobre la meta, entre 0 y 1 (para la barra). Null sin meta en dinero.
  final double? fraction;

  /// Días completos hasta el cierre; 0 = termina hoy; negativo = ya terminó. Null sin fecha válida.
  final int? daysLeft;
  final bool reached;

  static CampaignProgress of({int? target, int? cleared, required String endDate, DateTime? now}) {
    final end = DateTime.tryParse(endDate);
    final today = (now ?? DateTime.now()).toUtc();
    return CampaignProgress(
      fraction: target == null || target <= 0 ? null : ((cleared ?? 0) / target).clamp(0.0, 1.0),
      daysLeft: end == null ? null : end.toUtc().difference(today).inHours ~/ 24 - (end.isBefore(today) ? 1 : 0),
      reached: target != null && target > 0 && (cleared ?? 0) >= target,
    );
  }

  /// "42 % de la meta" (sin decimales; "menos de 1 %" si hay algo pero no llega al 1 %).
  String? get percentText {
    final f = fraction;
    if (f == null) return null;
    final pct = (f * 100).floor();
    return f > 0 && pct == 0 ? 'Menos del 1 % de la meta' : '$pct % de la meta';
  }

  String? get daysText => switch (daysLeft) {
    null => null,
    < 0 => 'Ya terminó',
    0 => 'Termina hoy',
    1 => 'Queda 1 día',
    final n => 'Quedan $n días',
  };
}
