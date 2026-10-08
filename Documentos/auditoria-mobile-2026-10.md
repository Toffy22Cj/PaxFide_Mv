# Auditoría de `paxfide-mobile` — 2026-10-07

**Qué es:** paso 0 del encargo de Carlos del 2026-10-07. Compara el código con ADR-043 (D1–D12, ya APROBADO con la §0) y con `front-fase1.md`. **No cambia código.**
**Código auditado:** `056b4ad` ("bootstrap paxfide-mobile architecture and formalize ADR-043", Adonis Pérez, 2026-10-04). Es el único commit con código: `main` (`fe4bece`) solo tiene documentos y su historia no comparte ancestro con el código; `develop` (`eefd1e4`) une las dos con un merge. `chore/front-fase1-env` y `claude/serene-wozniak-2lv6xl` apuntan a `056b4ad`.
**Fuentes de diseño:** `ADR-043-frontend-movil-paxfide-mobile.md` (raíz de este repo, APROBADO 2026-10-07T22:35Z) y `front-fase1.md` (raíz de este repo, la versión "cerrada a nivel de diseño", 17 secciones; ver DDM-02). §N = sección de `front-fase1.md`.
**Línea base medida** (Flutter 3.47.5 / Dart 3.13.4, sin tocar nada): `flutter analyze` → 4 avisos de nivel *info* (`prefer_initializing_formals` ×4); `flutter test` → 1 test (el contador de la plantilla), pasa.

## 1. Resultado en una frase

El código es un **esqueleto de dominio sin aplicación**: hay tipos y reglas puras para sesión, guard, rutas, deep links, Outbox y `ActionResolver`, pero ninguna implementación de red ni de almacenamiento, ninguna pantalla real (`main.dart` es la plantilla del contador de Flutter) y ningún test propio. **No hay datos inventados ni funciones que el sistema no tenga** — ni escrow, ni "Finanzas & Retiros", ni bolsas, certificados, galería de fotos, banda del 95 %, selector de rol, panel de organización, gráficos ni cifras simuladas: se buscó en todas las ramas (`main`, `develop`, `chore/front-fase1-env`, `056b4ad`) y no aparecen. Lo que el encargo pide quitar no existe en este repositorio (ver §4).

## 2. Tabla de auditoría

Acción: **conservar** (cumple), **corregir** (existe pero contradice el diseño), **quitar** (no debe estar), **construir** (falta).

| Decisión | Qué dice el diseño | Qué hace el código | Acción |
|---|---|---|---|
| D1 Superficies | Donante + operador de campo. Lo administrativo va en la web. Excepción: predicción para `ADMINISTRATOR`/`REPRESENTATIVE` (§0 A3) | Sin pantallas. Nada administrativo | **Construir** las pantallas de donante y operador y la de predicción. Nada que quitar |
| D2 Arquitectura | Por features; `presentation → domain → data → core`, nunca invertida. Carpetas `core/{network,storage,security,offline,errors,result}`, `features/{auth,campaigns,donations,tracking,physical_assets}`, `shared/` (§2) | Existen `app/`, `core/{errors,network,offline,storage}`, `features/auth/domain`, `features/physical_assets/domain`. No hay capas `data` ni `presentation`, ni `campaigns`, `donations`, `tracking`, `shared` | **Construir** las capas y features que faltan |
| D2 Sentido de dependencias | `core` no conoce dominio | `core/offline/ambiguous_reconciler.dart` (en `core`) conoce la ruta `/physical-assets/{assetRef}` y el campo `lifecycleStatus`, que son de la feature `physical_assets`: `core` depende de conocimiento de una feature | **Corregir**: la reconciliación pasa a `features/physical_assets`; `core/offline` queda con la máquina de estados genérica |
| D2 `ActionResolver` | En `features/physical_assets/domain/`; no es autorización (P7) | Ahí está; comentario P7 correcto | **Conservar** |
| D2 / dominio `LifecycleStatus` | `REGISTERED→Dispatch, DISPATCHED→Receive, RECEIVED→Deliver, DELIVERED→solo lectura` | Enum de 4 valores. El backend tiene 5: también `DEPLETED` (`AssetLifecycleStatus.java`). Un activo `DEPLETED` (tras una división) no tendría representación y un valor desconocido no tiene salida | **Corregir**: `DEPLETED` y cualquier valor desconocido → solo lectura |
| D3 Estados de sesión | `UNKNOWN → RESTORING → AUTHENTICATED \| LOGGED_OUT`, sin `REFRESHING`/`TOKEN_EXPIRED` (§3) | `SessionStatus` con exactamente esos 4 valores | **Conservar** |
| D3 Rol en la sesión | El rol **no** se guarda en la sesión: sale de `GET /me` y vive en memoria con la sesión. Nunca se decodifica el JWT | `SessionState` no tiene rol (correcto). No hay nada que lea `/me` ni que decodifique el JWT | **Conservar** `SessionState`; **construir** el principal en memoria desde `/me` |
| D3 Transiciones | Restauración al arrancar; login; logout; T-1 | No hay controlador de sesión: nadie emite los estados | **Construir** |
| D3 T-1 | `401` con `jwt` → limpia `TokenStore` → `LOGGED_OUT`; no aplica a `tracking`; no toca el Outbox | `AuthResponseHandler` lo hace así. Sin tests | **Conservar** + tests (también la negativa: el de seguimiento no toca la sesión) |
| D4 `ApiClient` | Transporte puro; `CredentialMode = none \| jwt \| tracking`; no genera `commandId` | Interfaz abstracta correcta; **sin implementación** | **Construir** la implementación (SDK: `dart:io`, DDM-04) |
| D4 Errores en 3 capas | Transporte / HTTP-API / interpretación de feature. Timeout nunca es `FAILED` | `NetworkConnectionException` se documenta como "fallo determinista" para cualquier fallo de conexión. Solo es determinista si la petición **no llegó a salir** (no se pudo conectar); un corte tras enviar es ambiguo. Las excepciones HTTP fijan 400/500 aunque llegue otro 4xx/5xx | **Corregir**: separar "no se pudo conectar" (determinista) de "conexión cortada tras enviar" (ambiguo); conservar el código HTTP real |
| D5 `TokenStore` | `flutter_secure_storage` | Interfaz sin implementación; la dependencia **no está** en `pubspec.yaml` | **Construir** |
| D5/D12 `OutboxStore` | `flutter_secure_storage`, JSON cifrado con campo de versión (§0 A2) | Interfaz sin implementación | **Construir** |
| D5 `CacheStore` | Reconstruible, tecnología no fijada | No existe | Sin acción: ninguna pantalla lo necesita (no se cachean datos de dominio) |
| D6 Máquina del Outbox | `PENDING → IN_FLIGHT → ACKNOWLEDGED \| FAILED \| AMBIGUOUS`; T-2; `AMBIGUOUS` nunca se reintenta solo; reintento manual con el mismo `commandId`; `FAILED` → Descartar / Nueva operación con `commandId` nuevo | `OutboxStatus` con los 5 estados; `OutboxRecovery.executeRecoveryT2` aplica T-2. No hay `SyncEngine`, ni reglas de transición, ni tests | **Conservar** enum y T-2; **construir** `SyncEngine` y transiciones con tests negativos |
| D6 + H2 | Cada entrada guarda el `accountId` que la creó; otra cuenta nunca la envía ni la ve; sobrevive al logout; descartar pide confirmación (§0 A1) | `OutboxItem` **no tiene `accountId`** | **Corregir** `OutboxItem` y **construir** el filtrado por cuenta |
| D6 Reconciliación | `GET /physical-assets/{assetRef}`; `lifecycleStatus` esperado → `ACKNOWLEDGED`; si no, sigue `AMBIGUOUS` | `AmbiguousReconciler` lo hace (ubicación incorrecta, ver D2). Sin tests | **Corregir** ubicación; conservar la lógica + tests |
| D7 `NavigationRestoreState` | Solo rutas del árbol aprobado; `schemaVersion` compatible; corrupto → fallback; nunca credenciales | Solo valida longitud; no valida `schemaVersion` ni que la ruta esté en el árbol; no se persiste | **Corregir** la validación; **construir** la persistencia (una posición) |
| D8 Árbol de rutas | `/c/:publicCode`, `/login`, `/home`, `/donations`, `/operator`, `/operator/pending`, `/assets/:assetRef`; seguimiento **sin código en la URL** (encargo §4.2) | `AppRoutes` tiene `/tracking/:trackingCode`. `categorize` acepta cualquier cosa que empiece por `/c/`, `/tracking/` o `/assets/` (también `/c/` vacío o `/c/a/b`) | **Corregir**: `/tracking` sin parámetro; validar la forma exacta de cada ruta. **Construir**: `/register` (transitoria de auth, D10 actualizado) y `/prediction` (autenticada, §0 A3) |
| D8 Guards | Solo sesión + categoría; `permitir \| redirigir \| esperar`; tabla 4×4 de §10 | `SessionGuard` reproduce la tabla. No lee roles, Outbox ni HTTP. Sin tests | **Conservar** + tests de la tabla, idempotencia y aserciones negativas |
| D8 Router | Router activo desde el arranque (G-1 a); UI de espera fuera del router; sin `/boot` | No hay router: `main.dart` es la plantilla | **Construir** con `Router` del SDK |
| D9 `DeepLinkParser` | Único parser (R1); R3 sin comandos; R5 host desconocido → no aprobada; solo 3 payloads | Único parser y sin efectos (bien). **No valida el host** (cualquier host vale). Acepta también rutas fijas (`/home`, `/login`, `/operator`…), que no son payloads de QR. Para seguimiento copia el código a la ruta | **Corregir**: host canónico configurado (DDM-03); solo `/c/…`, `/assets/…` y `/tracking…`; el de seguimiento abre `/tracking` y **descarta** el código |
| D9 `PendingIntent` | Solo en memoria; consumo único; un deep link nuevo lo reemplaza | Tipo de datos sin contenedor ni reglas | **Construir** el contenedor + tests |
| D10 Alcance | Actualizado (§0 A4): registro, `/me`, comandos, donar, intención y mis donaciones ya existen | Nada implementado | **Construir** según la prioridad del encargo |
| D11 | Sustituido por H2 decidido | — | Sin acción |
| D12 Dependencias | `flutter_secure_storage`, `mobile_scanner`, `qr_flutter`; nada más sin preguntar | `pubspec.yaml` solo tiene `cupertino_icons` | **Construir**: añadir las tres. `cupertino_icons` (de la plantilla) se conserva: no es nueva |
| Plantilla | — | `lib/main.dart` (contador "Flutter Demo") y `test/widget_test.dart` | **Quitar** (no es un dato inventado, pero no es la app) |
| Plataforma | Cámara para escanear; red en release | `AndroidManifest.xml` principal sin `INTERNET` ni `CAMERA`; `Info.plist` sin `NSCameraUsageDescription`; `applicationId` `com.example.paxfide_mobile` | **Corregir** permisos. El `applicationId` se deja (distribución fuera del ADR, §6) |

## 3. Datos inventados o simulados mostrados como reales

Ninguno. El único texto visible es la plantilla del contador. Para que siga así en lo que se construya, cada pantalla muestra solo campos que devuelve el backend (`referencia-api-v1.md` y los DTO de `Toffy22Cj/Donaciones` en `develop`, comprobados el 2026-10-07):

| Pantalla | Fuente | Notas de privacidad |
|---|---|---|
| Activo | `GET /physical-assets/{assetRef}`: `assetRef, lifecycleStatus, currentCustodianRef, currentLocation, quantity, unitOfMeasure, campaignRef?` | Sin `donorRef` (no viene). Solo para quien el backend autoriza |
| Seguimiento | `GET /donations/tracking`: `financialSnapshot{currency, originalAmount, clearedAmount, pendingAllocationAmount, confirmedAllocationAmount, refundedAmount}`, `campaignRef?`, `logistics[]`, `status` | `campaignRef` es un id interno: no se muestra |
| Mis donaciones | `GET /account/donations`: `intentId, campaignTitle, amount, currency, status, trackingCode?` | `intentId` es interno: no se muestra. `trackingCode` es secreto: no se muestra ni se registra (se registrará como decisión delegada en el bloque del donante) |
| Convocatoria | `GET /public/campaigns/{publicCode}` y su narrativa | — |
| Predicción | `GET /organizations/{organizationId}/campaigns/{campaignRef}/prediction` | Etiqueta "ESTIMACIÓN — modelo entrenado con datos sintéticos", separada de los hechos |

## 4. Lo que el encargo pide quitar y no existe

| Elemento | Resultado de la búsqueda (todas las ramas) |
|---|---|
| Escrow, "Finanzas & Retiros", bolsa disponible/retenida | No existe |
| Certificados, galería de fotos de hitos | No existe |
| Banda de confianza del 95 % | No existe |
| Cifras, listas o gráficos inventados | No existe |
| Selector de rol en el login; rol en `SessionState` | No existe (`SessionState` ya es solo el estado) |
| Panel de organización | No existe |
| "Diseño visual que encaje" (login partido, navegación adaptable, gráficos con `CustomPainter`) | Tampoco existe; no hay nada que conservar. Si se construye, será de cero y solo con datos reales (se registrará como decisión delegada) |

Comando usado: `git grep -i -E 'escrow|finanzas|retiro|bolsa|certificad|galer|95 ?%|confianza|CustomPainter|selector|NavigationRail|organizaci' <ref> -- lib test` sobre las cuatro referencias: 0 ficheros en cada una.

**Posible explicación (no verificada):** el encargo describe una versión de la app que no está en `Toffy22Cj/PaxFide_Mv` (quizá local o en otro repositorio). Si existe, conviene traerla para auditarla; este documento solo cubre lo que está en el remoto.

## 5. Discrepancias de documentación encontradas

| # | Discrepancia | Tratamiento |
|---|---|---|
| A-1 | Hay dos `front-fase1.md`: el de `Toffy22Cj/Donaciones` (207 líneas, "review en curso", §1–§10) y el de la raíz de este repo (572 líneas, "cerrado a nivel de diseño", §1–§17). ADR-043 cita §11–§14, que solo existen en el segundo | Rige el de este repo (DDM-02) |
| A-2 | El encargo pide marcar §8 y §9 de ADR-043 como históricas; el ADR no tiene §8 ni §9 | Nota aplicada a D8 y D9 (DDM-01) |
| A-3 | `front-fase1.md` §13 y D10: el seguimiento responde `401`. El backend vigente responde **404** uniforme (TR-D1, `referencia-api-v1.md` §8) | La pantalla trata 401 y 404 igual: "código no válido o expirado" |
| A-4 | `api-contract-matrix.md` §4b: el QR de seguimiento lleva `/tracking/{trackingCode}`. El encargo: el código nunca va en una URL | El parser acepta ese formato (puede haber QR impresos) pero **descarta** el código y abre `/tracking`; la app nunca genera QR de seguimiento. Anotado en `solicitudes-backend.md` (S-03) |
| A-5 | El host canónico de los enlaces no está fijado (D9 R5) y el repositorio web no está accesible desde esta sesión | Host por configuración de compilación (DDM-03); anotado en `solicitudes-backend.md` |
| A-6 | ADR-043 vive también en `Toffy22Cj/Donaciones` (solo lectura) y allí sigue PROPUESTO | Se aprobó la copia de este repo; anotado en `solicitudes-backend.md` (S-01) para que alguien con permiso sincronice |

## 6. Estado tras el bloque de corrección (`fix/mobile-correccion-d2-d3-d8`)

| Fila de §2 | Hecho |
|---|---|
| D2 sentido de dependencias | `ambiguous_reconciler.dart` sale de `core` y pasa a `features/physical_assets/domain/asset_reconciler.dart`. Nuevo test `test/architecture/dependency_direction_test.dart` que lee los `import` y falla si `core` importa features o si una capa importa a otra en sentido contrario (comprobado con dos mutaciones: ambas lo hacen fallar) |
| `LifecycleStatus` | `DEPLETED` añadido; valor desconocido → solo lectura |
| D4 errores | Transporte: `ConnectionNotEstablishedException` (determinista, la petición no salió), `NetworkTimeoutException` y `ConnectionInterruptedException` (ambiguas). HTTP: se conserva el código real; `ConflictException` (409) añadida |
| D6 + H2 | `OutboxItem` lleva `accountId` y deja de conocer el dominio (`kind`, `resourceRef`, `path`) |
| D7 | `NavigationRestoreState` valida `schemaVersion`, ruta del árbol, que no sea transitoria y que los parámetros sean exactamente los de la ruta; JSON corrupto → descartado |
| D8 | `/tracking` sin parámetro; forma exacta de cada ruta; `/register` y `/prediction` añadidas |
| D9 | Origen canónico obligatorio (DDM-03); solo los tres payloads; el código de seguimiento se descarta |
| Plantilla | `main.dart` del contador y su test quitados |
| Lints | Los 4 avisos de la línea base corregidos |
