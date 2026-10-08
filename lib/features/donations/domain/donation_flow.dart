import '../../../core/errors/app_exceptions.dart';
import '../../../core/offline/command_outcome.dart';
import '../../../core/util/command_id.dart';
import '../data/donation_intent_api.dart';

/// Importe ya convertido a unidades mínimas ISO 4217, como texto de dígitos (referencia-api-v1 §0).
bool isValidAmount(String s) => RegExp(r'^[1-9][0-9]{0,14}$').hasMatch(s);

/// Estado de una donación en curso. Todo vive en memoria: el `statusToken` y el `trackingCode` nunca se persisten,
/// se registran ni van en una URL.
class DonationAttempt {
  DonationAttempt({required this.publicCode, required this.amount, required this.currency, required this.commandId});
  final String publicCode;
  final String amount;
  final String currency;

  /// El mismo en un reintento tras un fallo ambiguo; el backend responde la misma intención con un token nuevo.
  final String commandId;
  CreatedIntent? intent;
  IntentStatus? lastStatus;
}

/// Flujo de donar con la pasarela simulada (CV-11 + consulta con `Intent-Token`). La consulta del estado es manual:
/// sin polling (regla 3.5).
class DonationFlow {
  DonationFlow(this.api, [CommandIdGenerator? ids]) : _ids = ids ?? CommandIdGenerator();
  final DonationIntentApi api;
  final CommandIdGenerator _ids;

  DonationAttempt start(String publicCode, String amount, String currency) =>
      DonationAttempt(publicCode: publicCode, amount: amount, currency: currency, commandId: _ids.next());

  /// Crea la intención. Devuelve el resultado clasificado y, si hubo 4xx, el código para explicar el motivo.
  Future<(CommandOutcome, int?)> create(DonationAttempt a, {required bool withAccount}) async {
    try {
      final r = await api.create(
        publicCode: a.publicCode,
        amount: a.amount,
        currency: a.currency,
        commandId: a.commandId,
        withAccount: withAccount,
      );
      final outcome = classifyResponse(r);
      if (outcome == CommandOutcome.acknowledged) a.intent = DonationIntentApi.parseCreated(r.requireData());
      return (outcome, r.statusCode);
    } on TransportException catch (e) {
      return (classifyTransport(e), null);
    }
  }

  Future<IntentStatus> refresh(DonationAttempt a) async {
    final i = a.intent;
    if (i == null) throw StateError('sin intención');
    final token = i.statusToken;
    if (token == null) throw StateError('sin statusToken: la app no puede consultar esta intención');
    final s = await api.status(i.intentId, token);
    a.lastStatus = s;
    return s;
  }
}
