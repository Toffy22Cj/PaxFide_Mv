# paxfide-mobile

App Flutter de PaxFide para el **donante** y el **operador de campo** que escanea QR (ADR-043, APROBADO 2026-10-07).

- Diseño: `front-fase1.md` y `ADR-043-frontend-movil-paxfide-mobile.md` (raíz).
- Auditoría, decisiones delegadas, solicitudes al backend y actas: `Documentos/`.
- Contrato HTTP: `Documentos/referencia-api-v1.md` del backend (`Toffy22Cj/Donaciones`, rama `develop`).

## Configuración

La app no trae hosts por defecto. Se configura al compilar con un fichero JSON (`--dart-define-from-file`):

| Clave | Para qué |
|---|---|
| `PAXFIDE_API_BASE_URL` | Base de la API, terminada en `/api/v1` |
| `PAXFIDE_PUBLIC_BASE_URL` | Origen de los enlaces y QR, el mismo que usa la web. Sin él, el escáner no aprueba ningún enlace y no se generan QR |

```bash
cp config/dev.example.json config/dev.json       # escritorio y backend local
cp config/movil.example.json config/movil.json   # teléfono con túnel
```

Los `config/*.json` reales están en `.gitignore`; solo se versionan los `*.example.json`. No contienen secretos, solo URLs.

## Backend local

Se levanta con `Documentos/runbook-demo-local.md` del backend (MongoDB, Ganache, Mailpit y el backend en `:8080`, perfil `dev`, con la semilla de demo). Cuentas de la semilla: `plataforma@`, `representante@`, `administrador@`, `empleado@` y `donante@demo.paxfide.local`, todas con `TRACEABILITY_DEMO_SEED_PASSWORD` de `demo.env`.

## Ejecutar en Linux (escritorio)

Requisitos (Ubuntu/Debian): `clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev` y, para el almacenamiento seguro (`flutter_secure_storage` usa libsecret), **`libsecret-1-dev`** más un servicio de llaves en marcha (GNOME Keyring o KWallet; en un escritorio normal ya está).

```bash
sudo apt-get install clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libsecret-1-dev
flutter config --enable-linux-desktop
flutter run -d linux --dart-define-from-file=config/dev.json
```

Si el llavero no está desbloqueado, la sesión no se puede guardar y el login falla al escribir el token: abrir la sesión gráfica normal (que desbloquea el llavero) o arrancar `gnome-keyring-daemon`.

**Qué no se puede probar en escritorio:** la **cámara** (`mobile_scanner` solo funciona en Android, iOS y macOS). En su lugar, la hoja del escáner tiene "O pega el enlace del QR", que pasa por el mismo `DeepLinkParser`. Tampoco hay enlaces del sistema (deep links desactivados hasta S-02) ni el comportamiento del almacenamiento cifrado de Android.

## Ejecutar en un Android por USB

1. En el teléfono: Ajustes → Acerca del teléfono → tocar 7 veces "Número de compilación"; luego Opciones de desarrollador → **Depuración por USB**. Conectar por USB y aceptar la huella del ordenador.
2. `flutter devices` debe listar el teléfono.
3. Elegir cómo llega el teléfono al backend:

### Opción recomendada: túnel `https` (Cloudflare quick tunnel)

El teléfono no necesita estar en la misma red y no hace falta HTTP sin cifrar.

```bash
# en la máquina del backend (sin cuenta de Cloudflare; la URL cambia en cada arranque)
cloudflared tunnel --url http://localhost:8080
# → https://<algo>.trycloudflare.com
```

Poner esa URL en `config/movil.json` como `PAXFIDE_API_BASE_URL` (`https://<algo>.trycloudflare.com/api/v1`). Si también se quieren QR que abra la web, otro túnel para la web (`--url http://localhost:3000`) en `PAXFIDE_PUBLIC_BASE_URL`.

```bash
flutter run --flavor normal --dart-define-from-file=config/movil.json      # depuración
flutter build apk --flavor normal --dart-define-from-file=config/movil.json # APK para instalar
```

### Alternativa: HTTP sin cifrar en la red local (solo build de demo)

Solo el **sabor `demo`** (id `com.example.paxfide_mobile.demo`, nombre "PaxFide demo") permite HTTP sin cifrar, y **solo para el host** de `PAXFIDE_API_BASE_URL` cuando empieza por `http://`. El sabor `normal` nunca lo permite, ni siquiera en debug (DDM-41).

```bash
# config/demo-lan.json: {"PAXFIDE_API_BASE_URL": "http://192.168.1.20:8080/api/v1", "PAXFIDE_PUBLIC_BASE_URL": "..."}
flutter run --flavor demo --dart-define-from-file=config/demo-lan.json
```

En el emulador de Android, el ordenador es `10.0.2.2` (`http://10.0.2.2:8080/api/v1`, también con `--flavor demo`).

> El proyecto tiene dos sabores: `flutter run`/`flutter build apk` en Android necesitan `--flavor normal` o `--flavor demo`.

**Aviso:** el build de Android no se ha podido compilar en el entorno donde se preparó (el SDK de Android no se pudo descargar). La primera compilación real puede necesitar ajustes en `android/app/build.gradle.kts`.

## CI local y recorrido real

```bash
scripts/ci-local.sh                 # flutter analyze + flutter test; evidencia en Documentos/evidencia-mobile/
scripts/recorrido-backend-real.sh   # contra el backend local (cargar antes demo.env del backend)
```
