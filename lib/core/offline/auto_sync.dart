import 'dart:async';

import 'package:flutter/widgets.dart';

/// Envío automático de lo guardado sin conexión (Enmienda 4 de ADR-043, S3): al abrir la app, al volver a ella y cada
/// [interval] mientras está abierta, ejecuta [jobs] en orden (la cola de comandos, las donaciones guardadas, refrescar
/// el perfil). Nunca dos rondas a la vez; un trabajo que falla no detiene a los demás.
class AutoSync with WidgetsBindingObserver {
  AutoSync({required this.jobs, this.interval = const Duration(seconds: 30)});

  final List<Future<void> Function()> jobs;
  final Duration interval;
  Timer? _timer;
  bool _running = false;

  void start() {
    WidgetsBinding.instance.addObserver(this);
    _timer ??= Timer.periodic(interval, (_) => run());
    run();
  }

  void stop() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _timer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) run();
  }

  /// Una ronda. Si ya hay una en curso, no hace nada.
  Future<void> run() async {
    if (_running) return;
    _running = true;
    try {
      for (final job in jobs) {
        try {
          await job();
        } on Object {
          // sin red o un fallo puntual: la siguiente ronda lo intenta otra vez
        }
      }
    } finally {
      _running = false;
    }
  }
}
