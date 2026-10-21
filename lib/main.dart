import 'package:flutter/material.dart';

import 'app/app_config.dart';
import 'app/bootstrap.dart';
import 'app/paxfide_app.dart';
import 'core/storage/secure_key_value_store.dart';
import 'shared/theme/pax_theme.dart';
import 'shared/widgets/pax_ui.dart';
import 'shared/widgets/state_views.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromEnvironment();
  if (config.apiBaseUrl == null) {
    runApp(
      MaterialApp(
        theme: PaxTheme.light,
        darkTheme: PaxTheme.dark,
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          appBar: AppBar(title: const Text('Configuración interna')),
          body: const MessageView(
            icon: Icons.inbox_outlined,
            title: 'Falta configurar la API',
            detail:
                'Esta compilación interna necesita la configuración del servidor. Avisa al equipo responsable antes '
                'de continuar.',
            action: NoticeBanner(
              'Solo para builds internos: compila con --dart-define-from-file=config/dev.json.',
              tone: Tone.info,
            ),
          ),
        ),
      ),
    );
    return;
  }
  final services = buildServices(config: config, secureStore: const FlutterSecureKeyValueStore());
  runApp(PaxFideApp(services: services));
  startServices(services);
}
