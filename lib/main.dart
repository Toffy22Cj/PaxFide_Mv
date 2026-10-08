import 'package:flutter/material.dart';

import 'app/app_config.dart';
import 'app/bootstrap.dart';
import 'app/paxfide_app.dart';
import 'core/storage/secure_key_value_store.dart';
import 'shared/widgets/state_views.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromEnvironment();
  if (config.apiBaseUrl == null) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: MessageView(
            icon: Icons.settings,
            title: 'Falta configurar la API',
            detail: 'Compila con --dart-define=PAXFIDE_API_BASE_URL=<base de la API>.',
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
