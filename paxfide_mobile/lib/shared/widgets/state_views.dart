import 'package:flutter/material.dart';

/// UI de espera mientras la sesión está en UNKNOWN / RESTORING.
///
/// NO es una ruta (ADR-043 D8, G-1 a): no existe `/boot`, no se restaura y no
/// es destino de deep links. La muestra el `RouteGate` dentro de la ruta que
/// está esperando.
class SessionWaitingView extends StatelessWidget {
  const SessionWaitingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF8FAFC),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E4A38)),
              ),
            ),
            SizedBox(height: 14),
            Text('Cargando…', style: TextStyle(fontSize: 14, color: Color(0xFF64748B))),
          ],
        ),
      ),
    );
  }
}

/// Ruta aprobada en el árbol v1 cuya pantalla todavía no existe en esta build.
///
/// No promete fechas ni capacidades; solo informa y ofrece volver.
class UnavailableScreenView extends StatelessWidget {
  final String path;

  const UnavailableScreenView({super.key, required this.path});

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        automaticallyImplyLeading: canPop,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Text(
              'Esta pantalla no está disponible en esta versión de la app.',
              key: Key('unavailable-screen'),
              style: TextStyle(fontSize: 15, color: Color(0xFF334155), height: 1.4),
            ),
          ),
        ),
      ),
    );
  }
}
