import 'package:flutter/material.dart';

/// Punto de entrada provisional: la plantilla del contador se quitó (auditoría 2026-10).
/// El arranque real (restauración de sesión, router, T-2) llega en el bloque "base".
void main() {
  runApp(const PaxFideApp());
}

class PaxFideApp extends StatelessWidget {
  const PaxFideApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'PaxFide',
      home: Scaffold(body: Center(child: Text('PaxFide'))),
    );
  }
}
