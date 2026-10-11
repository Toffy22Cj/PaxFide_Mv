#!/usr/bin/env bash
# Vacía SOLO la base de pruebas. La de la sustentación no se toca. Pide confirmación.
source "$(dirname "$0")/comun.sh"
if curl -sf -o /dev/null http://127.0.0.1:8080/api/v1/public/campaigns \
   && [ "$(cat "$GUARDADO/base-actual" 2>/dev/null)" = paxfide_pruebas ]; then
  error "El backend está usando la base de pruebas. Ciérralo primero con Ctrl+C en su terminal."
fi
echo "Esto borra todo lo que hay en la base de PRUEBAS (la de la sustentación no se toca)."
read -r -p "¿Seguro? Escribe si para continuar: " RESPUESTA
[ "$RESPUESTA" = "si" ] || { echo "Cancelado, no se borró nada."; exit 0; }
docker exec paxfide-demo-mongo mongosh --quiet paxfide_pruebas --eval 'db.dropDatabase()' >/dev/null
echo "Base de pruebas vacía. La próxima vez que hagas ./arrancar.sh pruebas se cargarán de nuevo los datos de la demo."
