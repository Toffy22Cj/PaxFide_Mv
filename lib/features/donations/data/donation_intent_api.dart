import '../../../core/errors/app_exceptions.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_response.dart';
import '../../../core/network/credential_mode.dart';

/// Respuesta de CV-11. `statusToken` es un secreto: vive solo en memoria y viaja solo en la cabecera
/// `Intent-Token`. `paymentRedirectUrl` es la ruta del checkout simulado de la web de demo.
class CreatedIntent {
  const CreatedIntent({required this.intentId, this.statusToken, this.paymentRedirectUrl});
  final String intentId;

  /// Puede faltar (reenvío de una intención anterior a la Enmienda 3): entonces la app no puede consultar el estado.
  final String? statusToken;

  /// Solo con `GATEWAY`.
  final String? paymentRedirectUrl;
}

class IntentStatus {
  const IntentStatus({required this.status, this.trackingCode});
  final String status;

  /// Solo con fondos aplicados (Enmienda 3 de ADR-037, D6).
  final String? trackingCode;
}

/// Token inválido o caducado: el mismo 404 que una intención inexistente.
class IntentNotFoundException extends AppException {
  const IntentNotFoundException() : super('Intención no encontrada o token caducado');
}

/// `POST /public/campaigns/{publicCode}/donation-intents` (CV-11) y `GET /public/donation-intents/{intentId}`.
class DonationIntentApi {
  const DonationIntentApi(this._api);
  final ApiClient _api;

  /// JWT opcional: con sesión la donación queda ligada a la cuenta. Devuelve la respuesta tal cual para que el
  /// llamante clasifique (2xx / 4xx / 5xx); los fallos de transporte se lanzan.
  Future<ApiResponse> create({
    required String publicCode,
    required String amount,
    required String currency,
    required String commandId,
    required bool withAccount,
  }) => _api.post(
    '/public/campaigns/${Uri.encodeComponent(publicCode)}/donation-intents',
    body: {'amount': amount, 'currency': currency, 'paymentMethod': 'GATEWAY'},
    headers: {'Command-Id': commandId},
    credentialMode: withAccount ? CredentialMode.jwt : CredentialMode.none,
  );

  static CreatedIntent parseCreated(Map<String, dynamic> j) {
    final id = j['intentId'];
    if (id is! String || id.isEmpty) throw const MalformedResponseException();
    final token = j['statusToken'], url = j['paymentRedirectUrl'];
    return CreatedIntent(
      intentId: id,
      statusToken: token is String && token.isNotEmpty ? token : null,
      paymentRedirectUrl: url is String && url.isNotEmpty ? url : null,
    );
  }

  Future<IntentStatus> status(String intentId, String statusToken) async {
    final r = await _api.get(
      '/public/donation-intents/${Uri.encodeComponent(intentId)}',
      headers: {'Intent-Token': statusToken},
      credentialMode: CredentialMode.none,
    );
    if (r.statusCode == 404) throw const IntentNotFoundException();
    final j = r.requireData();
    if (j['status'] is! String) throw const MalformedResponseException();
    return IntentStatus(status: j['status'] as String, trackingCode: j['trackingCode'] as String?);
  }
}
