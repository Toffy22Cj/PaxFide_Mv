# Pruebas de la app con el backend y la base de datos

Estos comandos **no cambian el código del backend**: solo lo encienden y lo usan, igual que lo haría la app.

Hay **dos bases de datos** separadas en tu computador:

| Base | Para qué | ¿Se borra? |
|---|---|---|
| `pruebas` | Probar lo que quieras, ensuciarla sin miedo | Solo si tú ejecutas `limpiar-pruebas.sh` |
| `presentacion` | Lo que vas a mostrar en la sustentación | Nunca desde estos comandos |

Lo que haces en una **no aparece** en la otra. Apagar el computador **no borra nada**.

Todos los comandos se escriben desde la carpeta del front:

```bash
cd ~/paxfide_corregido/scripts/pruebas
```

## Cada vez que vayas a probar

**Terminal 1: el backend.** Déjala abierta.

```bash
./arrancar.sh pruebas
```

(o `./arrancar.sh presentacion`). La primera vez en cada base carga los datos de la demo; las siguientes, conserva todo lo que hayas hecho. Está listo cuando aparece `Started TraceabilityApplication`.

**Terminal 2: la app.**

```bash
./app.sh
```

**Terminal 3: cuando la necesites.**

- Aprobar el pago de la última donación: `./pagar.sh`
- Rechazarlo: `./pagar.sh fallido`
- Ver qué hay guardado en la base (no cambia nada): `./ver-datos.sh pruebas` o `./ver-datos.sh presentacion`
- Cuentas y códigos de la demo: `cat ~/Donaciones/app/demo-evidencia/credenciales-locales.md`. Este archivo se reescribe cada vez que se cargan los datos de la demo en una base vacía.

Todas las cuentas usan la contraseña `demo-local-password`: `donante@`, `empleado1@`, `administrador@` y `representante@`, todas `@demo.paxfide.local`.

## Para terminar

1. En la terminal 2, pulsa `q` para cerrar la app.
2. En la terminal 1, pulsa `Ctrl+C` para cerrar el backend.
3. En cualquier terminal:

```bash
./apagar.sh
```

## Para cambiar de base

Cierra el backend (`Ctrl+C`) y vuelve a arrancarlo con la otra: `./arrancar.sh presentacion`.

## Para vaciar la base de pruebas

Con el backend cerrado:

```bash
./limpiar-pruebas.sh
```

Pide que escribas `si` para confirmar. La base `presentacion` no se toca.

## Antes de la sustentación

La causa "Abrigo para el invierno" se fecha para que el día de la sustentación vaya por el 30 % de su duración y la predicción tenga cifra. Por defecto es el 21 de octubre a las 10:00 a. m. (hora de Colombia). Si es otro día, la **primera vez** que arranques la base `presentacion` escribe la fecha así (hora de Colombia + 5 = hora UTC):

```bash
PAXFIDE_DIA_SUSTENTACION=2026-10-21T15:00:00Z ./arrancar.sh presentacion
```

Hazlo entre 5 y 27 días antes, y desde ahí usa la base `presentacion` como si la app ya estuviera publicada: dona, aprueba y rechaza pagos, mueve envíos. Todo queda guardado con su fecha real, así que el gráfico y la predicción tendrán historia el día de la sustentación.

## Probar en el celular (Android): entrar con huella

En el computador (Linux) la huella no aparece. Para probarla hace falta Android: tu celular o el emulador de Android Studio.

### Solo la primera vez

1. Instala Android Studio y ábrelo una vez para que descargue el SDK de Android.
2. En una terminal:

```bash
flutter doctor --android-licenses   # acepta todo con "y"
flutter doctor                      # la línea "Android toolchain" debe salir con ✓
```

3. En el celular: registra una huella en los ajustes de seguridad del teléfono.

### Con tu celular

1. El celular y el computador deben estar en **la misma red wifi**.
2. Arranca el backend como siempre (terminal 1): `./arrancar.sh pruebas`.
3. Comprueba que el celular llega al backend: averigua la IP del computador con `hostname -I` (la primera), y en el navegador del celular abre `http://ESA-IP:8080/api/v1/public/campaigns`. Debe salir un texto que empieza por `{"items"`. Si no carga y tienes el cortafuegos activado: `sudo ufw allow 8080/tcp`.
4. Crea el APK (terminal 2):

```bash
./apk.sh
```

5. Para instalarlo hay dos formas:
   - **Con cable (más cómodo):** en el celular, activa las opciones de desarrollador (Ajustes → Acerca del teléfono → toca 7 veces "Número de compilación") y dentro de ellas la **depuración USB**. Conecta el cable, acepta el aviso en el celular y vuelve a ejecutar `./apk.sh`: lo instala solo.
   - **Sin cable:** pasa al celular el archivo que indica `./apk.sh` (`build/app/outputs/flutter-apk/app-debug.apk`), ábrelo y permite "instalar apps de origen desconocido".

Si cambia la IP del computador (otra red wifi), vuelve a ejecutar `./apk.sh`.

### Con el emulador de Android Studio

1. En Android Studio: Device Manager → crea un dispositivo (por ejemplo un Pixel) y arráncalo.
2. En el emulador: Ajustes → Seguridad → pon un PIN y añade una huella. Cuando pida tocar el sensor, usa los tres puntos de la barra del emulador → **Fingerprint** → **Touch Sensor**.
3. Con el backend arrancado: `./apk.sh 10.0.2.2` (lo instala en el emulador abierto).
4. Cada vez que la app pida la huella, toca **Touch Sensor** en esa misma ventana.

### Qué comprobar

1. Entra con contraseña (`donante@demo.paxfide.local`, `demo-local-password`). Debe preguntar **"¿Entrar con tu huella la próxima vez?"** → **Activar** → pon la huella → entras y sale "Listo. La próxima vez podrás entrar con tu huella."
2. Cierra sesión. En el login aparece solo **"Entrar por biometría"** y el teléfono pide la huella → entras sin escribir nada.
3. Cierra sesión otra vez y toca la **X** del recuadro: queda el login con contraseña. El botón **"Entrar con huella"** lo vuelve a abrir.
4. Repite tocando **fuera** del recuadro: también se cierra.
5. Toca **"No usar la huella en este teléfono"** y confirma: el recuadro deja de aparecer, y al entrar con contraseña vuelve a preguntar si quieres activarla.
6. En la pantalla de inicio no debe haber nada de la huella.

Para ver los teléfonos registrados en la base (sin el token, que nunca se guarda): `docker exec paxfide-demo-mongo mongosh --quiet paxfide_pruebas --eval 'db.device_credentials.find({}, {tokenHash: 0}).toArray()'`

## Si algo falla

- **"No encuentro el backend"**: el backend debe estar en `~/Donaciones`. Si está en otra carpeta: `export PAXFIDE_BACKEND_DIR=/ruta/al/backend`.
- **"La base de datos no arrancó"**: revisa que Docker esté encendido.
- **"El backend no responde"** al abrir la app: arranca primero el backend en la terminal 1 y espera a `Started TraceabilityApplication`.
- Cualquier otro error: copia lo que salió en la terminal y pásaselo a quien te ayude.
