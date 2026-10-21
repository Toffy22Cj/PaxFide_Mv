import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../app/text_size_button.dart';
import '../../../app/theme_mode_button.dart';
import '../../../shared/widgets/pax_ui.dart';

/// Pantallas de acceso (Figma 01): barra con el título, el tamaño del texto y el tema; una columna centrada de 420 de
/// ancho como máximo. [brand] pone el logo, "PaxFide" y el lema arriba (Entrar); [subtitle] es el texto de entrada
/// (Crear una cuenta). [back] muestra la flecha para volver.
class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    required this.title,
    required this.child,
    this.brand = false,
    this.subtitle,
    this.back = false,
  });

  final String title;
  final Widget child;
  final bool brand;
  final String? subtitle;
  final bool back;

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: back
            ? IconButton(tooltip: 'Volver', icon: const Icon(Icons.arrow_back), onPressed: services.router.back)
            : null,
        title: Text(title),
        actions: const [TextSizeButton(), ThemeModeButton()],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (brand) ...[const BrandHeader(), const SizedBox(height: 28)],
                  if (subtitle != null) ...[
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodyLarge
                          ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 20),
                  ],
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Campo de contraseña con el ojo para mostrarla u ocultarla.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    this.enabled = true,
    this.helperText,
    this.onSubmitted,
    this.autofillHints,
  });
  final TextEditingController controller;
  final bool enabled;
  final String? helperText;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofillHints;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) => TextField(
    controller: widget.controller,
    enabled: widget.enabled,
    obscureText: _hidden,
    autofillHints: widget.autofillHints,
    onSubmitted: widget.onSubmitted,
    decoration: InputDecoration(
      helperText: widget.helperText,
      suffixIcon: IconButton(
        tooltip: _hidden ? 'Mostrar contraseña' : 'Ocultar contraseña',
        icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined),
        onPressed: () => setState(() => _hidden = !_hidden),
      ),
    ),
  );
}
