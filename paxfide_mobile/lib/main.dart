import 'package:flutter/material.dart';

import 'app/app_config.dart';
import 'app/app_services.dart';
import 'app/paxfide_app.dart';
import 'core/storage/secure_key_value_store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final services = buildServices(
    config: AppConfig.fromEnvironment(),
    secureStore: const FlutterSecureKeyValueStore(),
  );

  runApp(PaxFideApp(services: services));

  // G-1 (a): el router ya está activo; T-2 y la restauración de la sesión
  // corren en paralelo y el guard reevalúa cuando terminan.
  startServices(services);
}
