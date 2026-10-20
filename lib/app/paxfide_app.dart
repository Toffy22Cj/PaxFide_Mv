import 'package:flutter/material.dart';

import '../shared/theme/pax_theme.dart';
import 'app_services.dart';

class PaxFideApp extends StatelessWidget {
  const PaxFideApp({super.key, required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      services: services,
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: services.theme,
        builder: (context, mode, _) => MaterialApp.router(
          title: 'PaxFide',
          debugShowCheckedModeBanner: false,
          theme: PaxTheme.light,
          darkTheme: PaxTheme.dark,
          themeMode: mode,
          routerDelegate: services.router,
          backButtonDispatcher: RootBackButtonDispatcher(),
        ),
      ),
    );
  }
}
