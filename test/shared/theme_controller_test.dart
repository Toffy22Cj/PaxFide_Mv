import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paxfide_mobile/shared/theme/theme_controller.dart';

import '../support/fakes.dart';

void main() {
  test('empieza como el teléfono y recuerda la elección', () async {
    final store = InMemorySecureKeyValueStore();
    final theme = ThemeController(store);
    expect(theme.value, ThemeMode.system);

    await theme.select(ThemeMode.dark);
    expect(store.values[ThemeController.storageKey], 'dark');

    final reopened = ThemeController(store);
    await reopened.load();
    expect(reopened.value, ThemeMode.dark);
  });

  test('un valor desconocido guardado vuelve a "como el teléfono"', () async {
    final store = InMemorySecureKeyValueStore()..values[ThemeController.storageKey] = 'rosa';
    final theme = ThemeController(store);
    await theme.load();
    expect(theme.value, ThemeMode.system);
  });
}
