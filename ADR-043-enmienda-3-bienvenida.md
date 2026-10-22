# Enmienda 3 de ADR-043 — Bienvenida sin sesión (`/welcome`)

**Status:** Aprobado (Adonis, 2026-10-22, en el chat: «solo hazlo») · **Fecha:** 2026-10-22 · **Autor:** Adonis · **Revisa:** Carlos
**Origen:** M-01/M-02 (Enmienda 2 §1, «Bienvenida sin sesión») y decisión 5 de la reunión del 16 de octubre (catálogo de convocatorias en el inicio). Pantalla ya hecha y probada sin ruta (fase A, rama `chore/landing-bienvenida-movil`).

## Context

Sin sesión, la app abre directamente `/login` (D8, fila `LOGGED_OUT` de la tabla del guard). M-01 y M-02 piden una bienvenida con escanear un QR, «tengo un código», qué es PaxFide, el catálogo de convocatorias y un botón fijo «Iniciar sesión». La Enmienda 2 describe la pantalla pero no añade su ruta al árbol aprobado, y D8 fija el árbol y el destino de `LOGGED_OUT`.

## Decision

1. Nueva ruta **pública** `/welcome`, sin parámetros. Es restaurable sin sesión (D7) y no espera la sesión (invariante 2 de D8).
2. Con `LOGGED_OUT`, el destino por defecto pasa de `/login` a `/welcome`:
   - cuando la pila queda vacía (incluido el arranque en frío);
   - como base debajo de una ruta pública que quedó sola (restaurada o abierta por enlace en frío).
3. El guard **no cambia de forma**: sigue recibiendo solo `SessionState` y la categoría de la ruta.
   - `LOGGED_OUT` + ruta autenticada → sigue redirigiendo a `/login` (lo necesitan `PendingIntent`, D9 R2, y la Decisión B de D7).
   - `LOGGED_OUT` + ruta no aprobada → `/welcome`.
4. Logout (manual o T-1): la pila queda en `[/welcome, /login]`, para volver a entrar en el acto (también con biometría, M-28) y que «volver» desde Entrar lleve a la bienvenida.
5. `/login` y `/register` siguen siendo transitorias. Desde `/welcome`, «Iniciar sesión» hace `push(/login)`; Entrar muestra la flecha de volver cuando hay algo debajo.
6. El catálogo de la bienvenida usa `GET /public/campaigns` sin credenciales (contrato existente, sin cambios).

## Alternatives

- **(a) Meter la bienvenida dentro de `LoginScreen`.** Descartada: mezcla dos pantallas y deja el formulario lejos del pulgar.
- **(b) Bienvenida sin ruta** (superficie transitoria). Descartada: no se podría restaurar ni recibir «volver».
- **(c) `LOGGED_OUT` + ruta autenticada → `/welcome`.** Descartada: rompe R2 (el `PendingIntent` se consume tras el login) y la Decisión B.

## Consequences

**Positivas**
- Se cumplen M-01 y M-02; el catálogo se ve sin cuenta (decisión 5).
- El guard conserva sus invariantes: no lee roles, Outbox ni HTTP.

**Negativas**
- Un toque más para quien solo quiere entrar; lo compensan «Iniciar sesión» fijo y la biometría.
- Hay que reescribir las pruebas que esperan `/login` como primera pantalla.

**Cambios de código (fase B)**
- `AppRoutes`: `welcome`, `paramsOf` y `categorize` (pública).
- `AppRouterDelegate`: los tres puntos donde hoy `/login` es el destino por defecto de `LOGGED_OUT` (pila vacía, base bajo una pública sola y salida de `back()`); se conserva el del `PendingIntent`.
- `app_pages.dart`: la página. `LoginScreen`: flecha de volver si hay algo debajo.

**Pruebas a actualizar**
- `test/app/session_guard_test.dart`: fila `LOGGED_OUT` + no aprobada → `/welcome`.
- `test/app/app_routes_test.dart`, `deep_link_parser_test.dart`, `navigation_restore_state_test.dart`: `/welcome` como pública válida.
- `test/flows/session_navigation_flow_test.dart`: arranque en frío, logout, restauración y cancelar el login.
- Flujos que empiezan en Entrar: `qr_scan_flow_test.dart`, `theme_flow_test.dart`, `accessibility_test.dart`, `donate_flow_test.dart`, `account_flow_test.dart`, `outbox_flow_test.dart`, `test/features/auth/biometric_login_test.dart`.
- `test/support/app_harness.dart`: `login()` abre `/login` antes de escribir.
- `test/integration/backend_real_test.dart`: revisar (necesita el backend real).

## Decidido al aprobar

- El catálogo se muestra sin sesión.
- Va la tarjeta «¿Eres una organización?»: lleva a crear la cuenta en el móvil; la organización se registra y se
  verifica desde la web (decisión 4: en el móvil solo se registran donantes).

## Pendiente de confirmar por el equipo

- Textos de los pasos 04 y 05 del recorrido (afirmaciones sobre la cadena), redactados con ADR-039.
