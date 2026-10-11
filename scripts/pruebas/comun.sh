# Funciones compartidas por los scripts de pruebas. No se ejecuta solo.
set -euo pipefail

AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND="${PAXFIDE_BACKEND_DIR:-$HOME/Donaciones}"
FRONT="$(cd "$AQUI/../.." && pwd)"
COMPOSE=(docker compose -f "$BACKEND/scripts/demo/docker-compose.yml" -f "$AQUI/persistente.yml")
GUARDADO="$HOME/.paxfide-pruebas"

aviso() { printf '\n\033[1;32m==> %s\033[0m\n' "$*"; }
error() { printf '\n\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

comprobar_backend() {
  [ -d "$BACKEND/scripts/demo" ] || error "No encuentro el backend en $BACKEND. Si está en otra carpeta: export PAXFIDE_BACKEND_DIR=/ruta/al/backend"
}

base_de() {
  case "${1:-}" in
    pruebas) echo paxfide_pruebas ;;
    presentacion) echo paxfide_demo ;;
    *) error "Escribe 'pruebas' o 'presentacion'. Ejemplo: $0 pruebas" ;;
  esac
}

encender_contenedores() {
  aviso "Encendiendo la base de datos y la cadena local (Docker)..."
  "${COMPOSE[@]}" up -d
  printf 'Esperando a que la base de datos esté lista'
  for _ in $(seq 1 60); do
    if [ "$(docker inspect -f '{{.State.Health.Status}}' paxfide-demo-mongo 2>/dev/null)" = healthy ]; then
      echo " lista."
      return
    fi
    printf '.'
    sleep 2
  done
  error "La base de datos no arrancó. Revisa que Docker esté encendido."
}

# Número de causas en una base (0 si está vacía o no existe).
causas_en() {
  docker exec paxfide-demo-mongo mongosh --quiet "$1" --eval 'db.convocatorias.countDocuments()' 2>/dev/null | tail -1
}
