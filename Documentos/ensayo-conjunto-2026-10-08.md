# Ensayo conjunto backend + `paxfide-mobile` — 2026-10-08

**Qué es:** el ensayo pedido por Carlos ("Haz el ensayo conjunto con `runbook-demo-local.md`"): levantar el backend desde cero siguiendo el runbook al pie de la letra, recorrer su golden path y, sobre **el mismo backend**, recorrer la app con su propio código.
**Máquina:** contenedor Linux de la sesión; Docker 29.8 (Compose 5.6), Java 21.0.12, Maven 3.9.11, Python 3.13.16, Flutter 3.47.5 / Dart 3.13.4. Sin SDK de Android ni iOS: la app se ejercita por su código (tests), no en un dispositivo.

## 1. Sobre qué commit del backend

Carlos indicó `develop` = `231a7f6`. Al empezar, `origin/develop` estaba en **`1b012da`** (40 commits más). Se ensayó sobre `1b012da` porque es lo que hoy es `develop` (DDM-36):

- `runbook-demo-local.md` y `scripts/demo/` son **idénticos** en los dos commits (último cambio: `5b6586d`).
- El código y `referencia-api-v1.md` cambiaron. Dos cambios afectan a la app (§3).

## 2. Pasos del runbook, tal cual (UTC)

| Paso | Hora | Resultado |
|---|---|---|
| Inicio (clon limpio de `develop` `1b012da`) | 00:03:41 | — |
| 1. `docker compose … up -d` | 00:03:47 | MongoDB `healthy` (réplica `rs0`) y Ganache arriba |
| 2. `cp demo.env.example demo.env` | 00:04:16 | Sin cambios a los valores de ejemplo |
| 3. `deploy-anchor-registry.sh` | 00:04:16 | Contrato desplegado desde la cuenta #1 |
| 4. `mvn -q install -DskipTests` | 00:04:21 → 00:05:03 | `exit=0` |
| 4. `mvn -q -pl app spring-boot:run` | 00:05:18 | `GET /public/campaigns` → `{"items":[]}`; semilla creada |
| 5. `recorrido.py` | 00:05:23 → 00:05:38 | `exit=0`; 34 llamadas; **1 batch `ANCHORED` en Ganache** (12 eventos, ninguno sin batch) |
| 5-bis. App sin cambios (`c9ac65b`) | 00:05:45 | 14/14 en verde, **pero** con los importes mal mostrados (§3): el test comparaba valores en bruto |
| 5-bis. App con el arreglo (`88f9948`) | 00:10:00 | **15/15**; evidencia en `evidencia-mobile/recorrido-backend-real-88f9948-…` |
| 5-bis. La app lee los datos del golden path | — | Convocatoria de `recorrido.py` (meta 500 000,00 COP, unidades entregadas y receptores > 0) y la donación con cuenta del donante de la semilla (40 000,00 COP) en "mis donaciones" |
| 7. Parar y `down -v` | ver §5 | — |

## 3. Lo que el ensayo encontró en la app

| # | Hallazgo | Causa | Arreglo (`fix/mobile-ensayo-conjunto`) |
|---|---|---|---|
| E-1 | La app mostraba los importes en bruto: "Meta: 50000000 COP" donde son **500 000,00 COP** | `referencia-api-v1` §0 en `1b012da`: importes en **unidades mínimas ISO 4217** (COP, exponente 2), también en el seguimiento. La app seguía DDM-27 ("unidades enteras, sin formatear") | `shared/money.dart`; seguimiento, convocatoria, hechos y mis donaciones. Sustituye DDM-27 |
| E-2 | Donar: lo que escribía el donante se enviaba como si ya fueran unidades mínimas (escribir 60000 donaba 600,00 COP) | Mismo cambio | El donante escribe pesos (hasta 2 decimales) y ve "Se donarán 60 000,00 COP." antes de enviar; la app convierte. Moneda sin exponente conocido → no se ofrece donar |
| E-3 | Registro: una contraseña de menos de 12 caracteres daba "Revisa el email: no es válido." | `POST /auth/register` exige ≥ 12 caracteres (`PasswordTooShort`) | Comprobación previa, ayuda en el campo y mensaje del 400 que nombra las dos reglas |

E-1 y E-2 son los graves: un factor 100 en cifras de dinero delante de un donante o en la demo. El recorrido de 14 pasos no los detectó porque comparaba números, no lo que ve el usuario; ahora comprueba también el texto formateado con los importes reales.

## 4. Lo que no se pudo ensayar

- **Pantallas en un dispositivo**: no hay emulador ni SDK móvil en el entorno. Lo que se ve está cubierto por los tests de widgets (196), no por una ejecución real.
- **Completar el pago desde el móvil**: el checkout simulado es una ruta de la web de demo (DDM-31). El ensayo dispara el webhook firmado desde el test, como haría la web.
- **Seguimiento con el código del golden path**: `recorrido.py` oculta los `trackingCode` (`***`), así que la app usa el de su propia donación del paso 5.

## 5. Cierre
Ver la última fila de §2 una vez ejecutado el paso 7.
