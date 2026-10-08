import 'package:flutter/material.dart';

import 'app_services.dart';

class PaxFideApp extends StatelessWidget {
  const PaxFideApp({super.key, required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      services: services,
      child: MaterialApp.router(
        title: 'PaxFide',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B6E5A))),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B6E5A), brightness: Brightness.dark),
        ),
        routerDelegate: services.router,
        backButtonDispatcher: RootBackButtonDispatcher(),
      ),
    );
  }
}
