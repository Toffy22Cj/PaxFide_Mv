import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Reglas de rendimiento (2026-10-29): lo que causaba el lag no vuelve sin que se note.
void main() {
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();
  String code(File f) => f.readAsLinesSync().where((l) => !l.trimLeft().startsWith('//')).join('\n');

  test('ningún desenfoque del fondo ni de capas (BackdropFilter, ImageFiltered, ImageFilter.blur)', () {
    final bad = [
      for (final f in files)
        if (RegExp(r'BackdropFilter\(|ImageFiltered\(|ImageFilter\.blur').hasMatch(code(f))) f.path,
    ];
    expect(bad, isEmpty, reason: 'Un desenfoque se recalcula en cada fotograma: usa un velo de color');
  });

  test('ninguna imagen de memoria creada dentro de build (se decodifica otra vez en cada reconstrucción)', () {
    final bad = [
      for (final f in files)
        if (RegExp(r'Image\.memory\(\s*Uint8List\.fromList').hasMatch(code(f))) f.path,
    ];
    expect(bad, isEmpty);
  });
}
