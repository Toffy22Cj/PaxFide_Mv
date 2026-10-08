# paxfide_mobile

App móvil de PaxFide para el donante y el operador de campo. Diseño de referencia: `front-fase1.md` y ADR-043 (APROBADO, con la §0). Lo implementado está en la §8 del ADR.

## Ejecutar contra el backend local

1. Levanta el backend de `Toffy22Cj/Donaciones` (rama `develop`) con `Documentos/runbook-demo-local.md`. El paso 4b (perfil `demo-seed`) deja cuentas, convocatorias, donaciones y activos de ejemplo; las credenciales quedan en `app/demo-evidencia/credenciales-locales.md`.
2. Arranca la app indicando dónde está la API:

```bash
flutter pub get

# Escritorio o simulador de iOS (el backend en la misma máquina)
flutter run --dart-define=PAXFIDE_API_BASE_URL=http://127.0.0.1:8080/api/v1 \
            --dart-define=PAXFIDE_PUBLIC_BASE_URL=http://localhost:3000

# Emulador de Android (10.0.2.2 es la máquina anfitriona)
flutter run --dart-define=PAXFIDE_API_BASE_URL=http://10.0.2.2:8080/api/v1 \
            --dart-define=PAXFIDE_PUBLIC_BASE_URL=http://localhost:3000

# Teléfono real en la misma red: usa la IP de la máquina del backend
flutter run --dart-define=PAXFIDE_API_BASE_URL=http://192.168.1.50:8080/api/v1
```

- `PAXFIDE_API_BASE_URL` (obligatoria para usar la app): base de la API. Sin ella no sale ninguna petición y el login avisa de que no hay servidor configurado.
- `PAXFIDE_PUBLIC_BASE_URL` (opcional): origen de los enlaces y QR, el de la web. Sin ella el escáner no acepta enlaces y no se generan QR.
- HTTP sin cifrar solo funciona en los builds de `debug` de Android (el backend local); release exige HTTPS.

Cuentas de la semilla (contraseña `TRACEABILITY_DEMO_SEED_PASSWORD` del `demo.env`, por defecto `demo-local-password`):

| Para ver | Cuenta |
|---|---|
| Donante | `donante@demo.paxfide.local` |
| Operador de campo | `empleado1@demo.paxfide.local` |
| Administrador (operador + predicción) | `administrador@demo.paxfide.local` |
| Representante (predicción) | `representante@demo.paxfide.local` |

El pago de una donación lo completa el checkout simulado de la web de demo: la app crea la intención, muestra la dirección del checkout y consulta el estado a mano.

## Solo para ver la interfaz (sin backend)

```bash
flutter run --dart-define=PAXFIDE_FAKE_AUTH=true \
            --dart-define=PAXFIDE_FAKE_ROLES=EMPLOYEE,ADMINISTRATOR \
            --dart-define=PAXFIDE_FAKE_ORGANIZATION_ID=org-dev
```

Cualquier correo con `@` y cualquier contraseña. Sin `PAXFIDE_FAKE_ROLES` entras como donante. Sin `PAXFIDE_API_BASE_URL` las secciones dirán que no hay servidor configurado.

## Verificar

```bash
flutter analyze
flutter test

# Recorrido contra el backend real (con el backend del paso 1 arrancado y una base recién sembrada con demo-seed)
set -a; . <ruta-al-backend>/scripts/demo/demo.env; set +a
PAXFIDE_REAL_API=http://127.0.0.1:8080/api/v1 flutter test test/integration/backend_real_test.dart
```

El recorrido recibe y entrega el activo en tránsito de la semilla: para repetirlo hay que volver a sembrar la base.
