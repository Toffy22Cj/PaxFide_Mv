import 'package:flutter/material.dart';

import 'app/paxfide_app.dart';
import 'core/storage/in_memory_token_store.dart';
import 'features/auth/data/login_gateway.dart';
import 'features/auth/data/session_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final session = SessionController(tokenStore: InMemoryTokenStore());

  runApp(PaxFideApp(
    session: session,
    loginGateway: defaultLoginGateway(),
  ));

  // G-1 (a): el router ya está activo; la restauración corre en paralelo y el
  // guard reevalúa cuando termine.
  session.restore();
}
