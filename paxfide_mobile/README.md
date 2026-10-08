# paxfide_mobile

App móvil de PaxFide para el donante y el operador de campo. Diseño de referencia: `front-fase1.md` y ADR-043 (PROPUESTO).

## Ejecutar

```bash
flutter pub get
flutter run                                         # build normal: login sin contrato, no entra
flutter run --dart-define=PAXFIDE_FAKE_AUTH=true    # solo desarrollo: login simulado, cualquier credencial
```

El login simulado muestra el aviso "MODO DESARROLLO" y nunca se activa en un build normal.

## Verificar

```bash
flutter analyze
flutter test
```

## Estado

- Sesión sin roles (`UNKNOWN → RESTORING → AUTHENTICATED | LOGGED_OUT`), T-1, T-2 y reconciliación de `AMBIGUOUS`.
- Navegación por nombre a través de `AppRouter` → `SessionGuard`; las pantallas no navegan entre login y home por su cuenta.
- Pantallas implementadas: `/login`, `/home`. El resto de rutas aprobadas muestran "no disponible en esta versión".
- `TokenStore` en memoria (provisional; ADR-043 D5 fija `flutter_secure_storage`).
- Sin `ApiClient` concreto, sin persistencia del Outbox ni de la restauración, sin deep links del sistema (dependencias no decididas, D12).
