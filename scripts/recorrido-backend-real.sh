#!/usr/bin/env bash
# Recorrido de paxfide-mobile contra el backend REAL en local (encargo §6). El backend se levanta antes con
# runbook-demo-local.md de Toffy22Cj/Donaciones (rama develop) y se cargan sus variables:
#   set -a; . <backend>/scripts/demo/demo.env; set +a
# Uso: scripts/recorrido-backend-real.sh [base de la API, por defecto http://127.0.0.1:8080/api/v1]
# Guarda la salida literal en Documentos/evidencia-mobile/. Los tests nunca imprimen secretos.
set -uo pipefail
ROOT=$(git rev-parse --show-toplevel) || exit 2
cd "$ROOT"
if [ -n "$(git status --porcelain)" ]; then
    echo "recorrido: hay cambios sin commit. Abortado." >&2
    exit 3
fi
: "${TRACEABILITY_DEMO_SEED_PASSWORD:?carga demo.env del backend}"
: "${TRACEABILITY_DEMO_WEBHOOK_SECRET:?carga demo.env del backend}"
API=${1:-http://127.0.0.1:8080/api/v1}
COMMIT=$(git rev-parse --short HEAD)
STAMP=$(date -u +%Y-%m-%dT%H-%M-%SZ)
OUT="Documentos/evidencia-mobile/recorrido-backend-real-$COMMIT-$STAMP.txt"
LOG=$(mktemp "${TMPDIR:-/tmp}/recorrido-XXXXXX.log")
PAXFIDE_REAL_API="$API" flutter test test/integration/backend_real_test.dart --reporter expanded >"$LOG" 2>&1
STATUS=$?
{
    echo "# Recorrido contra el backend real — scripts/recorrido-backend-real.sh"
    echo "commit app:     $(git rev-parse HEAD) ($(git rev-parse --abbrev-ref HEAD))"
    echo "backend:        ${PAXFIDE_BACKEND_COMMIT:-no indicado} en $API"
    echo "fecha:          $STAMP"
    echo "salida:         $STATUS"
    echo
    flutter --version 2>&1 | grep -E "^Flutter|Dart"
    echo
    echo "## flutter test (literal)"
    grep -v -E "Woah|superuser|^  /$|📎" "$LOG"
    echo
    echo "## sha256 del log"
    sha256sum "$LOG" | cut -d' ' -f1
} >"$OUT"
echo "recorrido: evidencia en $OUT"
tail -n 1 "$LOG"
exit "$STATUS"
