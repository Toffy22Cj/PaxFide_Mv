# Enmienda 6 de ADR-043 — Gráficos de fondos mensuales y actividad de la organización

**Estado:** **APROBADA — Adonis, 2026-11-19** (comunicado por Manuel el 2026-11-19, junto con la revisión de PaxFide_Mv#17). *Texto original del estado, que se conserva:* PROPUESTA — espera aprobación (Manuel; ADR-043 es del front móvil y A3 la fijó Carlos: **[Falta: quién aprueba esta enmienda (Carlos o Manuel), fecha y medio.]**). Redactada el 2026-11-16 por Manuel, con asistencia de Claude, por su decisión del mismo día: «Fondos y actividad van con una enmienda de ADR-043 que redacta ya y que apruebas aparte, porque querías los gráficos en las dos apps».

**No autoriza código.** El código va en su propio plan, después de la aprobación y después de fusionar `Toffy22Cj/PaxFide_Mv#16` (decisión del 2026-11-16: no apilar ramas).

**Por qué es una enmienda.** A3 (§0, Carlos, 2026-10-07) fija el alcance del móvil: «Donante y operador de campo (D1). Única excepción: la pantalla de **predicción**, visible también para `ADMINISTRATOR`/`REPRESENTATIVE`». La Enmienda 2 (§1 y §8) añade que «el panel de la organización sigue siendo de la web». Dos lecturas nuevas de datos de la organización y sus pantallas amplían ese alcance.

## Contexto

- Encargo del 2026-11-15, Tarea B: gráficos simples y avanzados **en web y móvil**, uno simple y uno avanzado visibles por panel; cambia el tipo solo quien ya ve esos datos («cada rol en lo que ya ve», decisión de Manuel del 2026-11-15).
- Paneles aprobados el 2026-11-16: predicción, fondos mensuales, estado de lotes y actividad.
- Hoy el móvil ya lee la predicción (A3) y el listado de lotes de la organización (`PhysicalAssetApi.listForOrganization`, para el operador). **No** lee `GET /organizations/{id}/funds/monthly` ni `GET /organizations/{id}/activity`.
- Ya aprobado sin esta enmienda (plan del paso 3): en el móvil, gráficos de **predicción** (con `/prediction/history`) y de **estado de lotes**.

## Decisión propuesta

| # | Cambio | Sustituye o actualiza |
|---|---|---|
| E6-1 | **Segunda excepción de alcance (A3):** una pantalla **«Datos de la organización»** con dos paneles de gráficos: **fondos mensuales** (`GET /organizations/{id}/funds/monthly?months=1..12`) y **actividad** (`GET /organizations/{id}/activity`, primeras páginas, como mucho 100 eventos, indicado en el gráfico). Solo lectura | A3; Enmienda 2 §1 y §8 («el panel de la organización sigue siendo de la web»), solo para estas dos lecturas |
| E6-2 | **Quién la ve.** Se muestra según `/me`, con las mismas reglas que el backend: fondos, `ADMINISTRATOR` o `EMPLOYEE` (DD-31); actividad, `ADMINISTRATOR`, `REPRESENTATIVE` o `EMPLOYEE` (D-R6-8). Un `REPRESENTATIVE` solo ve el panel de actividad. El donante, nada. El backend sigue autorizando cada lectura; un 403 se muestra como tal | — |
| E6-3 | **Selector del tipo de gráfico** («cada rol en lo que ya ve»): en fondos y actividad, `ADMINISTRATOR` y `EMPLOYEE`; el `REPRESENTATIVE` ve el predeterminado de actividad, sin selector | — |
| E6-4 | **Sin dependencias nuevas** (A2/D12): gráficos con `CustomPaint`, sobre el mismo componente base que predicción y lotes. La elección del gráfico se guarda en `flutter_secure_storage` (ya aprobado), por cuenta (`accountId`, nunca el correo) y por panel | — |
| E6-5 | **Navegación.** Una tarjeta en Inicio y una entrada en la barra solo para los roles de E6-2; la barra del empleado (Enmienda 2, nota del 2026-11-12: «Inicio · Mi día · Escanear · Cuenta») no gana pestañas: la pantalla se abre desde Inicio | Enmienda 2 §1, solo para añadir la tarjeta |
| E6-6 | **Sin conexión** (Enmienda 4, S2): las dos lecturas se guardan como las demás (última respuesta, cifrada y por cuenta) y el gráfico dice la fecha de esa respuesta | — |

## Qué no cambia

- Ninguna escritura: la pantalla es de solo lectura. Registrar y dividir activos, la configuración de convocatorias y el resto del panel siguen siendo de la web.
- Ningún permiso del backend cambia (ADR-044 y DD-31 sin tocar).
- No se muestran `fundId`, donantes ni ningún dato que el backend no devuelva; los meses vacíos se dibujan en cero porque el backend los devuelve en `"0"`.

## Alternativas

| Opción | Por qué no |
|---|---|
| Dejar fondos y actividad solo en la web | Manuel quiere los gráficos en las dos apps (2026-11-16) |
| Una pestaña nueva en la barra para todos | Rompe la barra del empleado fijada en la Enmienda 2 y la muestra a quien no tiene datos |
| Mostrar también la integridad de la organización (`/integrity`) | No está entre los cuatro paneles aprobados; se puede proponer aparte |

## Consecuencias

- El móvil deja de ser solo «donante y operador de campo» también para estos dos paneles de lectura: A3 pasa a tener dos excepciones.
- Dos lecturas más en la caché sin conexión (Enmienda 4, S2).
- Documentos que cambian al implementarla: la §1 de la Enmienda 2 (nota fechada), `PENDIENTES_ADONIS.md`, `api-contract-matrix.md` del móvil y su `README`.

## Definición de hecho (para cuando se apruebe)

1. Pantalla visible para `ADMINISTRATOR`, `EMPLOYEE` y `REPRESENTATIVE` (este, solo actividad); **no** visible para el donante (aserción negativa).
2. Selector solo para `ADMINISTRATOR` y `EMPLOYEE`; el `REPRESENTATIVE` no lo tiene (aserción negativa).
3. Cada tipo de gráfico con datos de ejemplo (respuestas reales del escenario `demo-historico`) y con datos vacíos.
4. La elección se conserva al reabrir la app y un almacenamiento roto no rompe la pantalla.
5. 403 y sin conexión: estados propios, nunca un gráfico vacío presentado como «sin datos».
6. `flutter analyze` y `flutter test` completos, con su salida literal.
