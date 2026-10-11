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

## Si algo falla

- **"No encuentro el backend"**: el backend debe estar en `~/Donaciones`. Si está en otra carpeta: `export PAXFIDE_BACKEND_DIR=/ruta/al/backend`.
- **"La base de datos no arrancó"**: revisa que Docker esté encendido.
- **"El backend no responde"** al abrir la app: arranca primero el backend en la terminal 1 y espera a `Started TraceabilityApplication`.
- Cualquier otro error: copia lo que salió en la terminal y pásaselo a quien te ayude.
