# Decisiones delegadas — `paxfide-mobile`, octubre de 2026

**Origen:** encargo de Carlos del 2026-10-07 ("alinear y completar `paxfide-mobile`"), sección 1: registrar cada decisión que el agente toma **por Carlos**.
**Estado de todas:** `PENDIENTE DE RATIFICACIÓN` hasta que Carlos las revise.
**Criterio:** (1) ADR-043 aprobado con su §0 y el encargo; (2) `front-fase1.md`; (3) `referencia-api-v1.md`, `golden-path.md` y `reglas-equipo-y-agentes.md` del backend; (4) entre opciones válidas, la más segura, más reversible y más simple; en seguridad o privacidad, la más restrictiva.
**Columnas:** id · fecha UTC · pantalla o bloque · pregunta · opciones · elegida · motivo · ¿reversible? · estado.

## 1. Decisiones de Carlos aplicadas (no son delegadas)

| Decisión | Dónde quedó aplicada |
|---|---|
| ADR-043 APROBADO con H2, D12, alcance, D10 actualizado y §8/§9 históricas | `ADR-043-frontend-movil-paxfide-mobile.md`, estado y §0 |
| Seguimiento sin código en la URL (decisión de la web) | ADR-043 §0; `DeepLinkParser` y `AppRoutes` (bloque de corrección) |
| Rama `develop` y una rama por tarea | `develop` creada el 2026-10-07 (DDM-06) |

## 2. Registro

| id | Fecha UTC | Pantalla / bloque | Pregunta | Opciones | Elegida | Motivo | ¿Reversible? | Estado |
|---|---|---|---|---|---|---|---|---|
| DDM-01 | 2026-10-07T22:35Z | ADR-043 | El encargo pide marcar "§8 y §9 del ADR" como registro histórico, pero ADR-043 solo tiene §0–§7 | (a) notas en D8 y D9 del ADR; (b) notas en §8 y §9 de `front-fase1.md`; (c) no marcar nada y preguntar | **(a)** D8 (árbol de rutas) y D9 (deep links) | Son las partes del ADR que el encargo contradice (`/tracking/:trackingCode`), y la nota pedida es del ADR, no del diseño. (b) habría tocado un documento que el encargo no menciona | Sí: dos notas de texto | PENDIENTE DE RATIFICACIÓN |
| DDM-02 | 2026-10-07T22:35Z | Fuentes | Hay dos `front-fase1.md` (backend: §1–§10, "review en curso", commit del 2026-10-06; este repo: §1–§17, "cerrado a nivel de diseño", commit del 2026-09-30). ¿Cuál es "la más reciente"? | (a) la de commit más reciente (backend); (b) la de contenido más reciente (este repo) | **(b)** la de este repo | Su contenido es posterior: incluye §11–§17, que ADR-043 cita (§14 de tests, §13 de pantallas), y declara el diseño cerrado. La del backend es un estado intermedio del mismo documento, copiado después | Sí | PENDIENTE DE RATIFICACIÓN |
| DDM-03 | 2026-10-07T22:35Z | Deep links y QR | El host canónico de los enlaces no está fijado (D9 R5) y el repositorio web no es accesible desde esta sesión. ¿Qué host aceptan el parser y qué URL llevan los QR generados? | (a) fijar un dominio en el código; (b) configurarlo al compilar (`--dart-define=PAXFIDE_PUBLIC_BASE_URL`); (c) aceptar cualquier host | **(b)**. Sin valor configurado, el parser no aprueba ningún enlace y la generación de QR se desactiva con un aviso | (a) fijaría un valor que D9 R5 prohíbe fijar; (c) incumple R5. Las rutas (`/assets/{assetRef}`, `/c/{publicCode}`) son las de la matriz §4b, que son las de la web | Sí: un valor de compilación | PENDIENTE DE RATIFICACIÓN |
| DDM-04 | 2026-10-07T22:35Z | `ApiClient` | ¿Con qué cliente HTTP? D12 no lo fija y el encargo prohíbe dependencias nuevas | (a) `package:http` (dependencia nueva); (b) `dart:io` `HttpClient` del SDK | **(b)** | No añade dependencias. La app es solo móvil (Android/iOS), donde `dart:io` está disponible | Sí: una clase | PENDIENTE DE RATIFICACIÓN |
| DDM-05 | 2026-10-07T22:35Z | Comandos | ¿Cómo se genera el `Command-Id` (UUID) sin el paquete `uuid`? | (a) añadir `uuid`; (b) UUID v4 con `Random.secure()` del SDK | **(b)**, en la capa de dominio de `physical_assets` (nunca en `ApiClient`, D4) | Sin dependencias nuevas; el backend solo exige un UUID válido | Sí | PENDIENTE DE RATIFICACIÓN |
| DDM-06 | 2026-10-07T22:35Z | Ramas | `main` solo tiene documentos y su historia no comparte ancestro con el código. ¿De dónde sale `develop`? | (a) `develop` desde el código (`056b4ad`), sin los documentos de `main`; (b) `develop` = merge de `056b4ad` y `main` (`--allow-unrelated-histories`) | **(b)** | `develop` tiene así el código y los documentos de diseño que mandan. Es un merge: no reescribe ninguna historia ni toca `main` | Sí: `develop` es nueva | PENDIENTE DE RATIFICACIÓN |
| DDM-07 | 2026-10-07T22:35Z | ADR-043 | ADR-043 existe en `Toffy22Cj/Donaciones` (solo lectura para este encargo) y en la raíz de este repo. ¿Cuál se marca APROBADO? | (a) solo la de este repo; (b) también la del backend | **(a)**; la copia de este repo se igualó primero al texto del backend (renumeración ADR-042 → ADR-046) y después se aprobó. La sincronización del backend queda en `solicitudes-backend.md` (S-01) | El encargo prohíbe escribir en el backend | Sí | PENDIENTE DE RATIFICACIÓN |
