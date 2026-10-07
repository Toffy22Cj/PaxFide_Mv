# paxfide-mobile

App Flutter de PaxFide para el **donante** y el **operador de campo** que escanea QR (ADR-043, APROBADO 2026-10-07).

- Diseño: `front-fase1.md` y `ADR-043-frontend-movil-paxfide-mobile.md` (raíz).
- Auditoría, decisiones delegadas y solicitudes al backend: `Documentos/`.
- Contrato HTTP: `referencia-api-v1.md` del backend (`Toffy22Cj/Donaciones`).

## Ejecutar

Sin valores por defecto: la app no inventa hosts.

```bash
flutter run \
  --dart-define=PAXFIDE_API_BASE_URL=http://10.0.2.2:8080/api/v1 \
  --dart-define=PAXFIDE_PUBLIC_BASE_URL=https://<origen canónico de la web>
```

- `PAXFIDE_API_BASE_URL`: base de la API (`10.0.2.2` es el anfitrión visto desde el emulador de Android; el backend
  local se levanta con `runbook-demo-local.md` del backend).
- `PAXFIDE_PUBLIC_BASE_URL`: origen de los enlaces y QR, el mismo que usa la web. Sin él, el escáner no aprueba ningún
  enlace y no se generan QR (DDM-03, S-02).

## CI local

```bash
scripts/ci-local.sh   # flutter analyze + flutter test; evidencia en Documentos/evidencia-mobile/
```
