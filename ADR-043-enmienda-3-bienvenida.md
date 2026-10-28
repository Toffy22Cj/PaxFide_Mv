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

## Actualización (2026-10-22): fidelidad al landing y barra en píldora en toda la app

- La bienvenida usa **un solo mundo isométrico fijo** (`welcome_world.dart`, port del `<canvas id="world">` del landing) detrás del contenido. Al deslizar, la cámara recorre la carretera parada por parada y al final se aleja a la vista completa. El día pasa a atardecer, noche y vuelve a amanecer. Cada escena se anima al llegar y el mundo sigue vivo: nubes, pasto, monedas, luciérnagas y el camión patrullando.
- Las tarjetas aparecen y se desvanecen según la parada, las palabras de «Todo el recorrido» se encienden al avanzar y el mundo se desenfoca al llegar al catálogo. La barra superior se despliega con el menú del landing.
- Colores: solo de la paleta (tokens con mezcla o transparencia). Etiquetas del mapa sin datos de ejemplo (sin Lorica, Montería, Cereté, «120 kits» ni «Lote 142»).
- Con `MediaQuery.disableAnimations` no hay movimiento continuo y la cámara salta a cada parada. En las pruebas, `WelcomeWorld.ambientMotion = false`.
- `PaxAppBar` (`lib/shared/widgets/pax_app_bar.dart`) sustituye a `AppBar` en todas las pantallas: es una píldora flotante de vidrio con el logo (o volver/cerrar), el título y las acciones.
- Pendiente de confirmar por el equipo: la frase original «Nadie lo puede cambiar sin que se note» y «no se puede maquillar» se suavizaron hasta que se confirme la afirmación sobre blockchain.

## Actualización (2026-10-22): login y registro como el landing; logo en vector

- **Login** (`/login`): la caja de acceso del landing adaptada al móvil. Lleva el mundo de fondo, la píldora «Volver al recorrido», la insignia «TU CUENTA PAXFIDE», las pestañas Iniciar sesión / Crear cuenta, Google, Billetera Web3, «o continúa con correo electrónico», los campos con ícono, «¿Olvidaste tu contraseña?», «Recordarme en este teléfono» y «Regístrate gratis».
  - Google, Billetera Web3 y la recuperación de contraseña **no existen en el backend**: muestran un aviso de que aún no están disponibles y no llaman a nada (en el landing también eran demostración).
  - «Recordarme en este teléfono» es real: desmarcado, el JWT solo vive en memoria (`SecureTokenStore`) y al cerrar la app hay que volver a entrar.
- **Registro** (`/register`): solo cambia el diseño. Sigue siendo solo para donantes, con correo y contraseña de al menos 12 caracteres. Sin Google, Web3, rol, nombre ni casilla de términos. La barra de seguridad muestra la única regla real: el largo mínimo.
- **Logo**: `PaxLogo` es ahora el logo del landing dibujado en vector (sol, hoja, corazón, caja y mano), sin la imagen con fondo blanco. Usa colores de la paleta.
- **Pruebas**: se ejecutan con pantalla de teléfono (411 × 891). Así aparecieron y se corrigieron desbordes reales con el texto grande.
- **Pendiente de confirmar**: el subtítulo del landing «verifica lotes en blockchain» se dejó tal cual, pero la verificación aún no está disponible en la app.

## Actualización (2026-10-28): aceptación de términos y política de datos en registro y login

- **Registro (`/register`)**: el registro ahora lleva dos casillas de verificación obligatorias para aceptar los términos y condiciones y autorizar el tratamiento de datos personales con las versiones vigentes (`currentTermsVersion` y `currentDataPolicyVersion`, ambas `v1-2026-10`). No van marcadas por defecto. Si falta alguna casilla, no se envía la petición y se muestra el aviso de requerimiento con `AuthNotice`.
- **Login (`/login`)**: ante un 403 `AcceptanceRequired`, el login muestra el diálogo modal `LegalAcceptanceDialog` para aceptar las versiones legales pendientes y reintenta la autenticación enviando exactamente las versiones pendientes aceptadas.

## Actualización (2026-10-28): corrección de login, recuperación de contraseña, textos y catálogo enriquecido

- **Recuperación de contraseña**: implementada vía `AuthApi.requestPasswordReset(email)` (`POST /auth/password-reset`, pública, responde 202 sin cuerpo siempre). Desde `/login`, «¿Olvidaste tu contraseña?» abre la hoja modal inferior `Key('forgot.sheet')` prellenada con el correo del login. Ante 202, muestra el mensaje neutro de envío sin confirmar si la cuenta existe. Validación local de correo vacío (aviso sin petición).
- **Simplificación del login**: se eliminaron los botones de Google y Billetera Web3 al no formar parte de la API de autenticación, así como el separador de correo y avisos informativos innecesarios (`_notice` y `AuthNoticeKind.info`).
- **Suavizado de textos promocionales**: se ajustaron los textos visibles que prometían más de lo ofrecido por la app. El subtítulo de login pasa a «Gestiona tus donaciones, sigue su recorrido y apoya convocatorias», el título del catálogo a «Causas abiertas que puedes seguir paso a paso» y la etiqueta a «Convocatorias abiertas». Se preservan intactos los textos de las paradas 04 y 05 a la espera de confirmación del equipo.
- **Tipografía accesible**: se elevaron a 12 puntos como mínimo todos los tamaños de fuente inferiores a 12 en `lib/` (`AuthBadge`, `AuthDivider`, texto de largo de contraseña en registro y etiquetas en mono de la bienvenida).
- **Catálogo enriquecido (portada, logo y sello de verificación)**:
  - `CampaignSummary` y `PublicCampaign` leen `organizationVerified` (booleano defensivo), `organizationLogoUrl` y `coverImageUrl`.
  - Método auxiliar `resolveApiMediaUrl` en `CampaignApi` resuelve rutas relativas estrictamente bajo `/api/v1/public/` contra el esquema, host y puerto de `apiBaseUrl`, sin parámetros de seguimiento y rechazando dominios externos.
  - `CampaignSummaryCard`, la tarjeta de bienvenida `_CampaignCard` y `CampaignPublicScreen` incorporan:
    - Portada arriba en formato 16:9 (`Image.network` con fondo de reserva del tema, `excludeFromSemantics: true`).
    - Logo circular de la organización con iniciales de reserva sobre fondo de tokens.
    - Sello «✓ Organización verificada» visible únicamente cuando `organizationVerified == true`.

## Nota (2026-10-28): qué queda superado de las actualizaciones del 2026-10-22

Las secciones anteriores no se reescriben. Con las dos actualizaciones del 2026-10-28, estas afirmaciones ya no son ciertas:

- «Google, Billetera Web3 y la recuperación de contraseña no existen en el backend»: Google y Web3 se **retiraron** del login; la recuperación **sí existe** (`POST /auth/password-reset`) y está conectada.
- «Registro … sin casilla de términos»: el registro **lleva** las dos casillas obligatorias.
- «Pendiente de confirmar: el subtítulo del landing "verifica lotes en blockchain"»: **resuelto**. El subtítulo pasó a «Gestiona tus donaciones, sigue su recorrido y apoya convocatorias».
- Sigue pendiente: los textos de las paradas 04 y 05 del recorrido.

Detalles de diseño que no estaban escritos:

- **403 `AcceptanceRequired` y T-1 (D3):** el login va con `CredentialMode.none`, así que este 403 no pasa por `AuthResponseHandler` ni cambia la sesión. Se traduce en `AuthApi` a `AcceptanceRequiredException`, una excepción con nombre de la capa 2 de D4 que hereda de `ApiHttpException` y **no** de `ForbiddenException`. `ApiResponse` sigue siendo transporte puro.
- **Versiones legales:** fijas en `lib/features/auth/domain/legal_versions.dart` (`v1-2026-10`), porque la API no las expone. Solo se usan en el registro; en el login se envían siempre las pendientes que trae el 403, y solo tras aceptarlas.
- **Textos legales:** las casillas no enlazan a ningún texto todavía. Pendiente de que se publiquen.
- **Imágenes del catálogo:** las tarjetas toman la base de la API de `AppConfig` (con `AppScope.maybeOf`, que admite que no haya `AppScope`, como en las pruebas) y `resolveApiMediaUrl` construye las URL de portada y logo. Solo se cargan rutas bajo `/api/v1/public/`, sin credenciales.
- **Recuperación de contraseña:** la app solo pide el enlace. La contraseña nueva se pone en la web (`/recuperar`, rama `feat/web-account-security` de `Toffy22Cj/PaxFide`, aún sin fusionar en `develop`). Probado de punta a punta contra el backend local el 2026-10-28, confirmando el token con `POST /auth/password-reset/confirm` (204).
- **Verificación:** `scripts/ci-local.sh` en verde sobre `15722b7` (`flutter analyze` sin avisos, 328 pruebas); evidencia en `Documentos/evidencia-mobile/ci-local-15722b7-2026-10-28T20-55-48Z.txt`.
