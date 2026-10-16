import 'package:flutter/material.dart';

import '../../../core/errors/app_exceptions.dart';
import '../../../shared/theme/pax_theme.dart';
import '../biometrics/biometric_login.dart';

/// "Entrar con huella" (ADR-043 §8.8): activarla o desactivarla en este teléfono, con la sesión iniciada.
Future<void> showBiometricSettingsSheet(BuildContext context, BiometricLogin biometricLogin) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => _BiometricSettingsSheet(biometricLogin: biometricLogin),
  );
}

class _BiometricSettingsSheet extends StatefulWidget {
  const _BiometricSettingsSheet({required this.biometricLogin});
  final BiometricLogin biometricLogin;

  @override
  State<_BiometricSettingsSheet> createState() => _BiometricSettingsSheetState();
}

class _BiometricSettingsSheetState extends State<_BiometricSettingsSheet> {
  bool? _available;
  bool? _enabled;
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final available = await widget.biometricLogin.isAvailable();
    final enabled = await widget.biometricLogin.isEnabled();
    if (!mounted) return;
    setState(() {
      _available = available;
      _enabled = enabled;
    });
  }

  Future<void> _toggle(bool on) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    String? message;
    if (on) {
      final r = await widget.biometricLogin.enable();
      message = switch (r) {
        BiometricEnableResult.enabled => 'Listo. La próxima vez podrás entrar con tu huella.',
        BiometricEnableResult.canceled => 'No se activó: no se confirmó la huella.',
        BiometricEnableResult.unavailable => 'Este teléfono no tiene huella ni rostro configurados.',
        BiometricEnableResult.tooManyDevices =>
          'Ya tienes la huella activada en 10 teléfonos. Desactívala en alguno para añadir este.',
        BiometricEnableResult.networkError => 'Sin conexión. Inténtalo de nuevo.',
      };
    } else {
      try {
        await widget.biometricLogin.disable();
        message = 'Desactivada. Para entrar usarás tu contraseña.';
      } on AppException {
        message = 'Sin conexión: no se pudo desactivar. Inténtalo de nuevo.';
      }
    }
    final enabled = await widget.biometricLogin.isEnabled();
    if (!mounted) return;
    setState(() {
      _enabled = enabled;
      _busy = false;
      _message = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = PaxPalette.of(context);
    final available = _available;
    final enabled = _enabled;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          key: const Key('biometric-settings'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Entrar con huella', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: p.text)),
            const SizedBox(height: 6),
            Text(
              'Entra sin escribir tu contraseña, con la huella o el rostro de este teléfono. Tu contraseña nunca se '
              'guarda en el teléfono. Si cambias tu contraseña, tendrás que volver a activarla.',
              style: TextStyle(fontSize: 13, color: p.textMuted, height: 1.4),
            ),
            const SizedBox(height: 14),
            if (available == null || enabled == null)
              const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
            else if (!available && !enabled)
              Text(
                key: const Key('biometric-unavailable'),
                'Este teléfono no tiene huella ni rostro configurados, o no los permite usar en la app.',
                style: TextStyle(fontSize: 13, color: p.textMuted),
              )
            else
              SwitchListTile(
                key: const Key('biometric-switch'),
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.fingerprint),
                title: Text(enabled ? 'Activada en este teléfono' : 'Desactivada', style: TextStyle(color: p.text)),
                value: enabled,
                onChanged: _busy ? null : _toggle,
              ),
            if (_message != null) ...[
              const SizedBox(height: 8),
              Text(_message!, key: const Key('biometric-message'), style: TextStyle(fontSize: 13, color: p.text)),
            ],
          ],
        ),
      ),
    );
  }
}
