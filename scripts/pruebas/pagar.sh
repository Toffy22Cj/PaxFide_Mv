#!/usr/bin/env bash
# Hace de pasarela de pago de la demo para la última donación que está esperando pago, en la base que esté usando
# el backend (la que elegiste con arrancar.sh).
#   ./pagar.sh           → el pago se aprueba
#   ./pagar.sh fallido   → el pago se rechaza
source "$(dirname "$0")/comun.sh"
comprobar_backend
BASE="$(cat "$GUARDADO/base-actual" 2>/dev/null || true)"
[ -n "$BASE" ] || error "Primero arranca el backend con ./arrancar.sh pruebas (o presentacion)."
set -a
# shellcheck disable=SC1091
. "$BACKEND/scripts/demo/demo.env"
set +a
TIPO="payment.confirmed"; [ "${1:-}" = "fallido" ] && TIPO="payment.failed"
read -r SESION MONTO MONEDA < <(docker exec paxfide-demo-mongo mongosh --quiet "$BASE" --eval \
  'db.donation_intents.find({status:"PENDING", paymentSessionId:{$type:"string"}}).sort({expiresAt:-1}).limit(1).forEach(d=>print(d.paymentSessionId+" "+d.amount+" "+d.currency))' || true)
[ -n "${SESION:-}" ] || error "No hay ninguna donación esperando pago. Primero dona en la app y no cierres la ventana."
BODY="{\"type\":\"$TIPO\",\"paymentSessionId\":\"$SESION\",\"providerEventId\":\"evt-$SESION\",\"amount\":\"$MONTO\",\"currency\":\"$MONEDA\"}"
FIRMA=$(printf '%s' "$BODY" | openssl dgst -sha256 -hmac "$TRACEABILITY_DEMO_WEBHOOK_SECRET" -hex | awk '{print $NF}')
CODIGO=$(curl -s -o /dev/null -w "%{http_code}" -X POST http://127.0.0.1:8080/api/v1/webhooks/payments \
  -H "Content-Type: application/json" -H "X-Simulated-Signature: $FIRMA" -d "$BODY")
[ "$CODIGO" = "200" ] || error "El backend no aceptó el pago (respuesta $CODIGO). ¿Está arrancado?"
if [ "$TIPO" = "payment.confirmed" ]; then
  echo "Pago APROBADO: \$$((MONTO / 100)) $MONEDA. En la app pulsa 'Ver si ya se pagó'."
else
  echo "Pago RECHAZADO: \$$((MONTO / 100)) $MONEDA. En la app pulsa 'Ver si ya se pagó'."
fi
