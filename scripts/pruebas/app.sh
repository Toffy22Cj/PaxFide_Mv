#!/usr/bin/env bash
# Abre la app móvil (versión de escritorio Linux) conectada al backend local. Ciérrala con q en esta terminal.
source "$(dirname "$0")/comun.sh"
curl -sf http://127.0.0.1:8080/api/v1/public/campaigns >/dev/null \
  || error "El backend no responde. Arráncalo primero con ./arrancar.sh pruebas (o presentacion) en otra terminal."
cd "$FRONT/paxfide_mobile"
exec flutter run -d linux \
  --dart-define=PAXFIDE_API_BASE_URL=http://127.0.0.1:8080/api/v1 \
  --dart-define=PAXFIDE_PUBLIC_BASE_URL=http://localhost:3000
