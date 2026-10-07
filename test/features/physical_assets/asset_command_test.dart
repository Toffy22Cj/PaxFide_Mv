import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/core/errors/app_exceptions.dart';
import 'package:paxfide_mobile/core/network/api_response.dart';
import 'package:paxfide_mobile/features/physical_assets/domain/asset_action.dart';
import 'package:paxfide_mobile/features/physical_assets/domain/asset_command.dart';
import 'package:paxfide_mobile/features/physical_assets/domain/command_id.dart';
import 'package:paxfide_mobile/features/physical_assets/domain/command_outcome.dart';

void main() {
  group('Command-Id', () {
    final uuidV4 = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');

    test('UUID v4 válido y distinto en cada llamada', () {
      final g = CommandIdGenerator();
      final ids = {for (var i = 0; i < 500; i++) g.next()};
      expect(ids.length, 500);
      expect(ids, everyElement(matches(uuidV4)));
    });

    test('determinista con una semilla (para tests)', () {
      expect(CommandIdGenerator(Random(1)).next(), CommandIdGenerator(Random(1)).next());
    });
  });

  group('AssetCommand: ruta y cuerpo exactos del contrato (referencia-api-v1 §6)', () {
    test('dispatch', () {
      final c = AssetCommand.build(AssetAction.dispatch, 'A-1', {'carrierRef': ' transportista-1 '})!;
      expect(c.path, '/physical-assets/A-1/dispatch');
      expect(c.body, {'carrierRef': 'transportista-1'});
    });

    test('receive', () {
      final c = AssetCommand.build(AssetAction.receive, 'A-1', {'facilityLocation': 'centro-1', 'receiverRef': 'r'})!;
      expect(c.path, '/physical-assets/A-1/receive');
      expect(c.body, {'facilityLocation': 'centro-1', 'receiverRef': 'r'});
    });

    test('deliver: sin deliveredAt (lo pone el servidor)', () {
      final c = AssetCommand.build(AssetAction.deliver, 'A-1', {
        'finalCustodianRef': 'f',
        'beneficiaryRef': 'b',
        'locationRef': 'l',
        'evidenceRef': 'e',
      })!;
      expect(c.path, '/physical-assets/A-1/deliver');
      expect(c.body.keys, ['finalCustodianRef', 'beneficiaryRef', 'locationRef', 'evidenceRef']);
    });

    test('campos vacíos o de más de 256 → inválido, con su nombre', () {
      final errors = <String>[];
      expect(
        AssetCommand.build(AssetAction.receive, 'A-1', {
          'facilityLocation': '  ',
          'receiverRef': 'x' * 257,
        }, errors: errors),
        isNull,
      );
      expect(errors, ['facilityLocation', 'receiverRef']);
    });

    test('solo lectura no tiene comando', () {
      expect(AssetCommand.build(AssetAction.readOnly, 'A-1', const {}), isNull);
    });

    test('el assetRef se codifica en la ruta', () {
      expect(
        AssetCommand.build(AssetAction.dispatch, 'a b', {'carrierRef': 'c'})!.path,
        '/physical-assets/a%20b/dispatch',
      );
    });
  });

  group('clasificación (regla 2.6)', () {
    test('2xx → confirmado', () {
      expect(classifyResponse(const ApiResponse(statusCode: 200)), CommandOutcome.acknowledged);
    });

    test('4xx → rechazo inequívoco (FAILED)', () {
      for (final s in [400, 401, 403, 404, 409, 422]) {
        expect(classifyResponse(ApiResponse(statusCode: s)), CommandOutcome.failed, reason: '$s');
      }
    });

    test('5xx → ambiguo, nunca FAILED', () {
      for (final s in [500, 502, 503]) {
        expect(classifyResponse(ApiResponse(statusCode: s)), CommandOutcome.ambiguous, reason: '$s');
      }
    });

    test('timeout y corte → ambiguo; no conectar → no enviado', () {
      expect(classifyTransport(const NetworkTimeoutException()), CommandOutcome.ambiguous);
      expect(classifyTransport(const ConnectionInterruptedException()), CommandOutcome.ambiguous);
      expect(classifyTransport(const ConnectionNotEstablishedException()), CommandOutcome.notSent);
    });

    test('negativa: un timeout nunca clasifica como FAILED', () {
      expect(classifyTransport(const NetworkTimeoutException()), isNot(CommandOutcome.failed));
    });
  });
}
