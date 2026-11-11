import 'package:flutter/material.dart';

import 'app_routes.dart';
import 'app_services.dart';
import 'app_shell.dart';
import 'qr_scanner_sheet.dart';

/// `/scan`: la pestaña Escanear del empleado (M-03). Es una pantalla de la barra: se llega tocándola o deslizando,
/// y queda marcada mientras se está en ella. La cámara solo está encendida mientras esta pantalla está a la vista:
/// al abrir la ficha de un lote se apaga, y al volver se puede leer otro código.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  /// Cambia cada vez que la pantalla vuelve a estar a la vista: el escáner acepta otro código.
  int _round = 0;
  bool _wasVisible = true;

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final visible = ModalRoute.of(context)?.isCurrent ?? true;
    if (visible && !_wasVisible) _round++;
    _wasVisible = visible;
    return AppShell(
      location: AppRoutes.scan,
      title: 'Escanear',
      body: visible
          ? ScannerPanel(
              key: ValueKey('scan.$_round'),
              builder: services.qrScannerBuilder,
              employee: services.session.principal?.showsOperatorActions ?? false,
              onCode: (raw) => handleScannedCode(context, raw),
            )
          : const SizedBox.shrink(),
    );
  }
}
