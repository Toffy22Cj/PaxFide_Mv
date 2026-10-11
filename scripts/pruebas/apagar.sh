#!/usr/bin/env bash
# Apaga la base de datos y la cadena local SIN borrar nada. Antes, cierra el backend con Ctrl+C en su terminal.
source "$(dirname "$0")/comun.sh"
comprobar_backend
aviso "Apagando (tus datos se conservan)..."
"${COMPOSE[@]}" down
echo "Listo. Para volver: ./arrancar.sh pruebas (o presentacion)"
