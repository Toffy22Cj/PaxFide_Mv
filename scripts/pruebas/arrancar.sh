#!/usr/bin/env bash
# Enciende todo y arranca el backend en la base elegida. La terminal queda ocupada por el backend: déjala abierta.
#   ./arrancar.sh pruebas        → base de pruebas (la puedes vaciar cuando quieras con limpiar-pruebas.sh)
#   ./arrancar.sh presentacion   → base de la sustentación (no se vacía nunca desde estos scripts)
# La primera vez en cada base carga los datos de la demo; las siguientes, conserva lo que hayas hecho.
source "$(dirname "$0")/comun.sh"
comprobar_backend
BASE="$(base_de "${1:-}")"

encender_contenedores

# Contrato de la cadena local: se despliega una sola vez y se recuerda su dirección.
mkdir -p "$GUARDADO"
CONTRATO="$(cat "$GUARDADO/contrato" 2>/dev/null || true)"
CODIGO=""
if [ -n "$CONTRATO" ]; then
  CODIGO=$(curl -sf -X POST -H 'Content-Type: application/json' \
    --data "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"eth_getCode\",\"params\":[\"$CONTRATO\",\"latest\"]}" \
    http://localhost:8545 | python3 -c 'import json,sys; print(json.load(sys.stdin).get("result",""))' || true)
fi
if [ -z "$CONTRATO" ] || [ "$CODIGO" = "0x" ] || [ -z "$CODIGO" ]; then
  aviso "Preparando la cadena local (solo la primera vez)..."
  CONTRATO="$(cd "$BACKEND" && scripts/demo/deploy-anchor-registry.sh)"
  echo "$CONTRATO" > "$GUARDADO/contrato"
fi

set -a
# shellcheck disable=SC1091
. "$BACKEND/scripts/demo/demo.env"
set +a
export CRYPTO_ANCHOR_SMART_CONTRACT="$CONTRATO"
export SPRING_DATA_MONGODB_URI="mongodb://localhost:27017/$BASE?replicaSet=rs0"
echo "$BASE" > "$GUARDADO/base-actual"   # para que pagar.sh sepa en qué base buscar
export TRACEABILITY_DEMO_SEED_ENABLED=false
if [ -n "${PAXFIDE_DIA_SUSTENTACION:-}" ]; then
  export TRACEABILITY_DEMO_SEED_DEMO_DAY="$PAXFIDE_DIA_SUSTENTACION"
fi

if [ "$(causas_en "$BASE")" = "0" ]; then
  aviso "La base '$1' está vacía: se cargarán los datos de la demo."
  export SPRING_PROFILES_ACTIVE=dev,demo-seed
else
  aviso "La base '$1' ya tiene datos: se conservan."
  export SPRING_PROFILES_ACTIVE=dev
fi

aviso "Preparando el backend (puede tardar un minuto)..."
(cd "$BACKEND" && mvn -q install -DskipTests)

aviso "Arrancando el backend en la base '$1'. Estará listo cuando veas 'Started TraceabilityApplication'."
echo "Para apagarlo: Ctrl+C en esta terminal y después ./apagar.sh"
cd "$BACKEND"
exec mvn -q -pl app spring-boot:run
