#!/usr/bin/env bash
# Crea el APK de prueba para Android, conectado al backend de este computador por wifi, y lo instala si hay un
# celular conectado por USB con la depuración USB activada.
#   ./apk.sh            → usa la IP de este computador en la red wifi
#   ./apk.sh 10.0.2.2   → para el emulador de Android Studio (10.0.2.2 es este computador visto desde el emulador)
# Es un APK de depuración: solo así Android deja hablar con el backend por HTTP (DDM-14).
source "$(dirname "$0")/comun.sh"
IP="${1:-$(hostname -I | awk '{print $1}')}"
[ -n "$IP" ] || error "No encontré la IP de este computador. Escríbela: ./apk.sh 192.168.1.50"

aviso "Creando el APK conectado a http://$IP:8080 (tarda unos minutos la primera vez)..."
cd "$FRONT/paxfide_mobile"
flutter build apk --debug \
  --dart-define=PAXFIDE_API_BASE_URL=http://$IP:8080/api/v1 \
  --dart-define=PAXFIDE_PUBLIC_BASE_URL=http://localhost:3000
APK="$FRONT/paxfide_mobile/build/app/outputs/flutter-apk/app-debug.apk"

if flutter devices 2>/dev/null | grep "• android" >/dev/null; then
  aviso "Instalando en el celular conectado..."
  flutter install --debug && echo "Listo: abre PaxFide en el celular."
else
  aviso "APK listo: $APK"
  echo "No hay ningún celular conectado por USB. Pasa ese archivo al celular y ábrelo para instalarlo."
fi
