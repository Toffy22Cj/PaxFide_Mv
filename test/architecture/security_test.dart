import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Encargo §5: ningún secreto en URLs ni logs. La forma más simple de garantizarlo: la app no escribe logs.
void main() {
  final files = Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

  test('lib/ no usa print, debugPrint, log ni stdout', () {
    final re = RegExp(r'(^|[^.\w])(print|debugPrint)\(|dart:developer|stdout\.|stderr\.');
    final bad = [
      for (final f in files)
        for (final (i, line) in f.readAsLinesSync().indexed)
          if (re.hasMatch(line) && !line.trimLeft().startsWith('//')) '${f.path}:${i + 1}: $line',
    ];
    expect(bad, isEmpty);
  });

  test('ninguna ruta del árbol lleva el código de seguimiento', () {
    final routes = File('lib/app/app_routes.dart').readAsStringSync();
    expect(routes, isNot(contains(':trackingCode')));
  });
}
