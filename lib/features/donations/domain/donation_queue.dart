import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/errors/app_exceptions.dart';
import '../../../core/offline/command_outcome.dart';
import '../../../core/storage/secure_key_value_store.dart';
import '../data/donation_intent_api.dart';

/// Estado de una donación guardada en el teléfono (Enmienda 4 de ADR-043, S5).
enum SavedDonationStatus {
  /// Guardada sin conexión; se envía sola.
  pending,

  /// El servidor la registró: falta pagarla (o ya se pagó y se consulta su estado).
  sent,

  /// El servidor la rechazó (4xx): no se reintenta.
  failed,
}

/// Una donación hecha desde la app y guardada cifrada. `statusToken` es la llave de su estado (S5); el código de
/// seguimiento nunca se guarda (ADR-043 §0).
class SavedDonation {
  const SavedDonation({
    required this.commandId,
    required this.publicCode,
    required this.campaignTitle,
    required this.amount,
    required this.currency,
    required this.accountId,
    required this.createdAt,
    this.status = SavedDonationStatus.pending,
    this.intentId,
    this.statusToken,
    this.paymentUrl,
    this.rejectionStatus,
  });

  final String commandId;
  final String publicCode;
  final String campaignTitle;
  final String amount;
  final String currency;

  /// La cuenta con la que se donó; `null` = sin cuenta. Una donación con cuenta solo la envía y la ve esa cuenta (H2).
  final String? accountId;
  final DateTime createdAt;
  final SavedDonationStatus status;
  final String? intentId;
  final String? statusToken;
  final String? paymentUrl;
  final int? rejectionStatus;

  SavedDonation copyWith({
    SavedDonationStatus? status,
    String? intentId,
    String? statusToken,
    String? paymentUrl,
    int? rejectionStatus,
  }) => SavedDonation(
    commandId: commandId,
    publicCode: publicCode,
    campaignTitle: campaignTitle,
    amount: amount,
    currency: currency,
    accountId: accountId,
    createdAt: createdAt,
    status: status ?? this.status,
    intentId: intentId ?? this.intentId,
    statusToken: statusToken ?? this.statusToken,
    paymentUrl: paymentUrl ?? this.paymentUrl,
    rejectionStatus: rejectionStatus ?? this.rejectionStatus,
  );

  Map<String, Object?> toJson() => {
    'commandId': commandId,
    'publicCode': publicCode,
    'campaignTitle': campaignTitle,
    'amount': amount,
    'currency': currency,
    'accountId': accountId,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'status': status.name,
    'intentId': intentId,
    'statusToken': statusToken,
    'paymentUrl': paymentUrl,
    'rejectionStatus': rejectionStatus,
  };

  static SavedDonation? fromJson(Object? j) {
    if (j is! Map) return null;
    String? s(String k) => j[k] is String ? j[k] as String : null;
    final status = SavedDonationStatus.values.where((v) => v.name == j['status']).firstOrNull;
    final created = s('createdAt') == null ? null : DateTime.tryParse(s('createdAt')!);
    if (s('commandId') == null || s('publicCode') == null || s('amount') == null || s('currency') == null) return null;
    if (status == null || created == null) return null;
    return SavedDonation(
      commandId: s('commandId')!,
      publicCode: s('publicCode')!,
      campaignTitle: s('campaignTitle') ?? '',
      amount: s('amount')!,
      currency: s('currency')!,
      accountId: s('accountId'),
      createdAt: created,
      status: status,
      intentId: s('intentId'),
      statusToken: s('statusToken'),
      paymentUrl: s('paymentUrl'),
      rejectionStatus: j['rejectionStatus'] is int ? j['rejectionStatus'] as int : null,
    );
  }
}

/// Las donaciones guardadas en el teléfono, cifradas (almacén seguro, D5/D12), y su envío (S5). El envío reutiliza
/// el `Command-Id` de cada una: el backend responde la misma intención a un reenvío (con un `statusToken` nuevo).
class DonationQueue extends ChangeNotifier {
  DonationQueue(this._store, this._api, {required this.sessionAccountId});

  static const key = 'paxfide.donations.saved';

  final SecureKeyValueStore _store;
  final DonationIntentApi _api;

  /// La cuenta de la sesión ahora; `null` sin sesión.
  final String? Function() sessionAccountId;

  Future<T> _locked<T>(Future<T> Function() body) {
    final result = _tail.then((_) => body());
    _tail = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<void> _tail = Future.value();

  Future<List<SavedDonation>> _read() async {
    try {
      final raw = await _store.read(key);
      final j = raw == null ? null : jsonDecode(raw);
      if (j is! List) return [];
      return [for (final x in j) ?SavedDonation.fromJson(x)];
    } on Object {
      return [];
    }
  }

  Future<void> _write(List<SavedDonation> all) => _store.write(key, jsonEncode([for (final d in all) d.toJson()]));

  /// Las que puede ver quien usa el teléfono ahora: las sin cuenta y las de su cuenta. Más recientes primero.
  Future<List<SavedDonation>> visible() async {
    final account = sessionAccountId();
    final all = await _locked(_read);
    return all.where((d) => d.accountId == null || d.accountId == account).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> save(SavedDonation d) async {
    await _locked(() async {
      final all = await _read();
      all.removeWhere((x) => x.commandId == d.commandId);
      await _write([...all, d]);
    });
    notifyListeners();
  }

  Future<void> remove(String commandId) async {
    await _locked(() async {
      final all = await _read();
      all.removeWhere((x) => x.commandId == commandId);
      await _write(all);
    });
    notifyListeners();
  }

  /// Envía una pendiente. Con cuenta, solo si esa cuenta tiene la sesión abierta (H2).
  Future<CommandOutcome> send(SavedDonation d) async {
    if (d.status != SavedDonationStatus.pending) return CommandOutcome.acknowledged;
    final withAccount = d.accountId != null;
    if (withAccount && sessionAccountId() != d.accountId) return CommandOutcome.notSent;
    try {
      final r = await _api.create(
        publicCode: d.publicCode,
        amount: d.amount,
        currency: d.currency,
        commandId: d.commandId,
        withAccount: withAccount,
      );
      final outcome = classifyResponse(r);
      switch (outcome) {
        case CommandOutcome.acknowledged:
          final intent = DonationIntentApi.parseCreated(r.requireData());
          await save(
            d.copyWith(
              status: SavedDonationStatus.sent,
              intentId: intent.intentId,
              statusToken: intent.statusToken,
              paymentUrl: intent.paymentRedirectUrl,
            ),
          );
        case CommandOutcome.failed:
          await save(d.copyWith(status: SavedDonationStatus.failed, rejectionStatus: r.statusCode));
        case CommandOutcome.ambiguous || CommandOutcome.notSent:
          break; // sigue pendiente: se reenvía con el mismo Command-Id
      }
      return outcome;
    } on TransportException catch (e) {
      return classifyTransport(e);
    } on AppException {
      return CommandOutcome.ambiguous;
    }
  }

  /// Envío automático (S3): todas las pendientes que puede enviar quien usa el teléfono. Se detiene sin red.
  Future<void> sendAll() async {
    for (final d in (await visible()).reversed.where((d) => d.status == SavedDonationStatus.pending)) {
      if (await send(d) == CommandOutcome.notSent) break;
    }
  }

  /// Estado del pago con el `statusToken` guardado. Devuelve el estado (con el código de seguimiento, que no se
  /// guarda) o lanza [IntentNotFoundException] si el token caducó (24 h).
  Future<IntentStatus> status(SavedDonation d) {
    final id = d.intentId, token = d.statusToken;
    if (id == null || token == null) throw const IntentNotFoundException();
    return _api.status(id, token);
  }
}
